# Architecture Research

**Domain:** Claude Code skill — GitHub data pipeline to PowerPoint generation
**Researched:** 2026-03-10
**Confidence:** HIGH

## Standard Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                        SKILL ENTRY POINT                             │
│  ~/.claude/skills/mos-progress/SKILL.md                              │
│  (User types /mos:progress or /progress — Claude orchestrates)       │
└────────────────────────────────┬────────────────────────────────────┘
                                 │ Claude reads SKILL.md, runs steps
                                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│                       LAYER 1: DATA FETCHING                         │
├─────────────────────────────────────────────────────────────────────┤
│  ┌──────────────────────┐    ┌──────────────────────────────────┐   │
│  │  gh pr list          │    │  gh api /repos/:owner/:repo/     │   │
│  │  --search "author:X" │    │  commits?author=X&since=T&until=U│   │
│  │  --state merged      │    │                                  │   │
│  │  (all org repos)     │    │  (direct commit data per repo)   │   │
│  └──────────┬───────────┘    └───────────────┬──────────────────┘   │
│             │                                │                       │
│             └──────────────┬─────────────────┘                       │
│                            ▼                                         │
│              Raw JSON via stdout (gh → Claude's context)             │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    LAYER 2: DATA NORMALIZATION                        │
├─────────────────────────────────────────────────────────────────────┤
│  Claude (LLM reasoning) normalizes:                                  │
│  - Deduplicate commits already in PRs                                │
│  - Apply time-window filter (prev Wed → Tue noon)                    │
│  - Categorize: bug fix / new feature / new tool                      │
│  - Extract: repo, title, description, dates, PR status               │
│                                                                      │
│  Output: structured intermediate data (JSON in context or tmp file)  │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    LAYER 3: PRESENTATION GENERATION                  │
├─────────────────────────────────────────────────────────────────────┤
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │  scripts/generate_pptx.py                                      │  │
│  │  (bundled in skill directory, executed not loaded into context) │  │
│  │                                                                 │  │
│  │  Receives: JSON data via stdin or temp file                     │  │
│  │  Uses:     python-pptx                                          │  │
│  │  Produces: ~/output/progress-YYYY-MM-DD.pptx                   │  │
│  └───────────────────────────────────────────────────────────────┘  │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         OUTPUT                                       │
│  File saved locally: ~/output/progress-YYYY-MM-DD.pptx              │
│  Claude confirms path and summarizes what was included               │
└─────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Implementation |
|-----------|---------------|----------------|
| `SKILL.md` | Orchestration instructions for Claude; defines steps, data contract, script invocation | YAML frontmatter + markdown instructions |
| `scripts/generate_pptx.py` | Accepts normalized data, builds all slides, saves `.pptx` | python-pptx, bundled in skill dir |
| `gh` CLI | Raw GitHub data fetching (PRs, commits) for the `metabolomics-us` org | Invoked via Bash tool, output captured |
| Claude (LLM) | Time-window calculation, deduplication, categorization, summary text | Inline reasoning during skill execution |
| Temp data file (optional) | Passes normalized data from Claude's context into the Python script | JSON file in `/tmp/` |

## Recommended Project Structure

```
~/.claude/skills/mos-progress/
├── SKILL.md                   # Entry point — orchestration instructions
└── scripts/
    └── generate_pptx.py       # Slide builder — receives data, outputs .pptx
```

That's it. The skill is intentionally minimal. Claude's native reasoning handles categorization logic; python-pptx handles rendering. No intermediate modules, no config files, no separate data models — the JSON contract between Claude and the script is defined in SKILL.md.

### Structure Rationale

- **SKILL.md at root:** Claude Code's required entry point; all instructions live here
- **scripts/ directory:** Bundled Python scripts are executed, not loaded into context — efficient and reliable; Claude does not need to see the implementation, only the interface
- **No src/ or lib/ nesting:** This is a single-command tool, not an app; flat structure reduces navigation overhead for Claude

## Architectural Patterns

### Pattern 1: LLM-as-Orchestrator, Script-as-Renderer

**What:** Claude (the LLM) handles all judgment-requiring work — filtering, categorization, summary generation. A deterministic Python script handles all rendering work. The two communicate via a JSON handoff.

**When to use:** Any skill where classification/interpretation benefits from language understanding but output format is rigidly structured. The split prevents two failure modes: LLM hallucinating slide structure, and Python trying to categorize text.

**Trade-offs:** Clean separation of concerns. The Python script is fully testable in isolation. Claude's categorizations are visible in context before the script runs (auditability). Slight overhead from JSON handoff, but negligible for this data volume.

**Example handoff contract (defined in SKILL.md):**
```json
{
  "period": {"start": "2026-03-04", "end": "2026-03-10"},
  "summary": "Shipped 3 features, closed 2 bugs across 4 repos.",
  "stats": {
    "total_prs": 5,
    "total_commits": 18,
    "repos_touched": ["mzmine", "metaboverse", "ms-utils"]
  },
  "categories": {
    "bug_fix": [...],
    "new_feature": [...],
    "new_tool": [...]
  },
  "timeline": [
    {"date": "2026-03-04", "type": "new_feature", "repo": "mzmine", "title": "..."}
  ],
  "prs": [
    {"title": "...", "repo": "...", "status": "merged", "description": "...", "merged_at": "..."}
  ]
}
```

### Pattern 2: Dynamic Context Injection for Time Window

**What:** Use SKILL.md's `!`command`` syntax to inject the current date before Claude sees the instructions. This lets Claude calculate the correct Wednesday-to-Tuesday window without hardcoding dates.

**When to use:** Any skill that needs current time awareness at invocation.

**Trade-offs:** Zero additional round-trips. Evaluated once at invocation, before Claude receives the prompt. Slightly harder to debug (the rendered output isn't shown to the user), but reliable.

**Example in SKILL.md:**
```yaml
---
name: mos-progress
description: Generates a weekly GitHub progress PowerPoint for the metabolomics-us org.
disable-model-invocation: true
allowed-tools: Bash(gh *), Bash(python *)
---

Current date: !`date +%Y-%m-%d`

Calculate the reporting window: previous Wednesday through Tuesday 12:00 noon.
...
```

### Pattern 3: Bundled Script Execution (Not Code Generation)

**What:** The `generate_pptx.py` script ships inside the skill directory. Claude runs it with `Bash(python ~/.claude/skills/mos-progress/scripts/generate_pptx.py /tmp/mos_data.json)`. Claude never reads the script source — it only captures stdout/stderr.

**When to use:** Any deterministic, repeatable output-generation step. Writing to a file, running a formatter, executing a validation check.

**Trade-offs:** Script is more reliable than LLM-generated code (written once, tested, stable). Script consumes zero context tokens. `${CLAUDE_SKILL_DIR}` substitution in SKILL.md ensures the path is always correct regardless of where the skill is installed.

## Data Flow

### Primary Execution Flow

```
User: /mos:progress
        │
        ▼
SKILL.md loaded into Claude's context
!`date` command evaluated → current date injected
        │
        ▼
Claude computes date window (prev Wed → Tue noon)
        │
        ▼
Claude runs: gh pr list --search "author:@me" --state merged
             --repo metabolomics-us/* [for each repo]
             -L 100 --json title,url,body,mergedAt,baseRepository,commits
        │
        ▼ (raw JSON in context)
Claude runs: gh api /search/commits?q=author:USERNAME+org:metabolomics-us
             (for direct commits not tied to a merged PR)
        │
        ▼ (additional raw JSON in context)
Claude normalizes + categorizes in-context
        │
        ▼
Claude writes /tmp/mos_data.json with agreed JSON schema
        │
        ▼
Claude runs: python ${CLAUDE_SKILL_DIR}/scripts/generate_pptx.py /tmp/mos_data.json
        │
        ▼ (script writes ~/output/progress-YYYY-MM-DD.pptx)
Claude reports: "Saved to ~/output/progress-2026-03-10.pptx"
        │
        ▼
Done
```

### Key Data Flows

1. **GitHub → Context:** `gh` CLI outputs JSON to stdout. Claude's Bash tool captures it directly into the active context window. No intermediate files needed for raw data.

2. **Context → Disk:** Claude writes the normalized, categorized JSON to `/tmp/mos_data.json`. This is the single interface boundary between Claude's reasoning and the Python renderer.

3. **Disk → .pptx:** `generate_pptx.py` reads the JSON file, builds the presentation object hierarchy (Presentation → Slides → Shapes/Charts/Tables), and calls `prs.save(output_path)`.

## Scaling Considerations

This is a single-user personal tool. Scaling is irrelevant. The relevant "load" concern is GitHub API rate limits and context window size.

| Concern | Reality for this project | Approach |
|---------|--------------------------|----------|
| GitHub API rate limits | ~5 repos, 7-day window — well within authenticated limits | Use `gh` CLI (authenticated via `gh auth login`); no workarounds needed |
| Context window size | Raw PR/commit JSON could be large for very active orgs | Use `--json` field selection in `gh` commands to fetch only needed fields; paginate if needed |
| python-pptx memory | Irrelevant at this data volume | No action needed |
| Execution time | Multiple `gh` API calls add latency (~5-15s total) | Acceptable for a manual weekly command |

## Anti-Patterns

### Anti-Pattern 1: Generating Python Code Instead of Running a Bundled Script

**What people do:** Write SKILL.md instructions that tell Claude to "write a Python script that creates the PowerPoint." Claude generates the script in-context and runs it.

**Why it's wrong:** Generated code is non-deterministic across runs. Slide layout, styling, and chart parameters will vary. The generated code consumes significant context tokens. Debugging requires inspecting generated code in context.

**Do this instead:** Write `generate_pptx.py` once, bundle it in `scripts/`, reference it in SKILL.md as a command to execute. Claude runs the stable, tested script every time.

### Anti-Pattern 2: Fetching All Repos Then All PRs for Each

**What people do:** First call `gh api /orgs/metabolomics-us/repos`, then loop and call `gh pr list` per repo, resulting in 10-20 separate API calls.

**Why it's wrong:** Slow, verbose, and risks context bloat from accumulated JSON responses. Each response dumps into context.

**Do this instead:** Use GitHub's search API: `gh api /search/commits?q=author:USERNAME+org:metabolomics-us` and `gh pr list --search "author:@me org:metabolomics-us"`. Two calls instead of N+1.

### Anti-Pattern 3: Storing Intermediate Data in Claude's Context as "Variables"

**What people do:** Ask Claude to "remember the PR data" and refer to it later in the same instruction sequence, relying on context continuity.

**Why it's wrong:** Context can be summarized or compacted by Claude Code, especially in long sessions. The data may be partially truncated.

**Do this instead:** Write the normalized JSON to `/tmp/mos_data.json` immediately after normalization. The file is the handoff. The Python script reads from disk, not from something Claude "remembers."

### Anti-Pattern 4: Putting All Logic in SKILL.md

**What people do:** Write SKILL.md with detailed instructions for slide layout, exact chart sizing, color values, table column widths.

**Why it's wrong:** SKILL.md should be under 500 lines. Presentation layout is deterministic logic that belongs in Python, not in natural language instructions to an LLM.

**Do this instead:** SKILL.md describes the data contract (what JSON to produce) and the command to run. `generate_pptx.py` owns all presentation structure decisions.

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| GitHub API | Via `gh` CLI authenticated session | Requires `gh auth login` to be run once; `gh` handles token refresh; uses HTTPS REST and Search APIs |
| python-pptx | Python library, invoked by bundled script | Must be installed in the Python environment Claude uses: `pip install python-pptx`; no auth required |
| Local filesystem | Direct write to `~/output/` | Directory must exist or script must create it with `mkdir -p` |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| Claude ↔ gh CLI | Bash tool, stdout captured to context | Claude uses `--json fields` flag to limit response size; always specify fields |
| Claude ↔ generate_pptx.py | `/tmp/mos_data.json` written by Claude, read by script | JSON schema must be defined in SKILL.md so Claude knows what structure to produce |
| generate_pptx.py ↔ filesystem | Direct file write via python-pptx `prs.save()` | Output path passed as CLI argument; script prints absolute path on success |

### Build Order (Dependencies Between Components)

The natural build order follows the data flow, with each component testable in isolation:

1. **`generate_pptx.py` first** — Write and test the script with a hardcoded sample JSON fixture. Verify all slides render correctly before any GitHub integration. This is the highest-risk component (library unfamiliarity, chart/table API complexity).

2. **JSON schema second** — Once the script works against a fixture, formalize the JSON contract in SKILL.md. The schema is the interface between the two halves.

3. **`SKILL.md` data fetching section third** — Write and test the `gh` CLI commands in isolation (run them in the terminal directly). Verify they return the expected fields for the `metabolomics-us` org.

4. **`SKILL.md` normalization instructions fourth** — Add the categorization, deduplication, and time-window logic to SKILL.md. Test by running `/mos:progress` and inspecting the `/tmp/mos_data.json` output before the script runs.

5. **End-to-end integration last** — Run the full skill and verify the generated `.pptx` matches expectations. At this point both halves are already tested; integration issues will be at the boundary (JSON schema mismatches).

## Sources

- Claude Code Skills documentation (official): https://code.claude.com/docs/en/skills
- Skill authoring best practices (official): https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices
- python-pptx documentation: https://python-pptx.readthedocs.io/
- GitHub CLI pr list manual: https://cli.github.com/manual/gh_pr_list
- GitHub Search API (commits): https://docs.github.com/en/rest/search/search#search-commits

---
*Architecture research for: Claude Code skill — GitHub activity → PowerPoint (mos:progress)*
*Researched: 2026-03-10*
