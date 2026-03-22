---
name: research
description: Multi-persona research with structured debate, parallel source investigation, and actionable output (report, PPTX, implementation, prototype)
argument-hint: "<question> [--standalone] [--deep] [--team auto|ask|N] [--skip-pptx] [--skip-planning|--skip-gsd] [--no-branch]"
---

## Step 0 — Preamble

Resolve the gw-skills repo path, then read and follow `$GW_REPO/.claude/commands/gw/_shared/preamble.md` for update check and GSD project detection:

```bash
GW_REPO="$(cd "$(readlink ~/.claude/commands/gw)/../../.." 2>/dev/null && pwd)" || GW_REPO="$HOME/.gw-skills"
```

GW_REPO persists for the duration of this skill run — do not re-resolve it in later steps.

---

## Step 0.5 — Branch Isolation

Set `SKILL_NAME="research"`.

Read and follow `$GW_REPO/.claude/commands/gw/_shared/branch-first.md` for branch creation.

---

## Step 1 — Parse Arguments & Route

You are an orchestrator for multi-persona research investigations. You assemble a specialist team, run parallel research with persona-specific sources, conduct structured debate, and produce actionable output. Follow these steps precisely.

Parse the arguments: "$ARGUMENTS"

The **research question** is everything in `$ARGUMENTS` that isn't a recognized flag (quoted or unquoted).

| Flag | Variable | Default | Notes |
|------|----------|---------|-------|
| `--standalone` | FORCE_STANDALONE | false | |
| `--deep` | DEEP_RESEARCH | false | |
| `--team <N\|auto\|ask>` | TEAM_MODE, TEAM_SIZE_OVERRIDE | auto | N (number, clamped 3-10) sets TEAM_SIZE_OVERRIDE |
| `--skip-pptx` | SKIP_PPTX | false | |
| `--skip-planning` / `--skip-gsd` | SKIP_PLANNING | false | |
| `--no-branch` | NO_BRANCH | false | Skip branch isolation (see Step 0.5) |
| `--hire` / `--fire` / `--roster` | — | — | Redirect: "Use `/gw:workforce`…" and **stop** |

If no research question is provided and no workforce management flag is set, ask: "What would you like to research?" and wait.

### Workflow routing

| Condition | Steps executed |
|-----------|----------------|
| Default (full run) | 0 → 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 |
| `--hire/--fire/--roster` | 0 → 1 (redirect to `/gw:workforce`) |
| `--skip-pptx` | Skip PPTX in Step 7 |
| `--skip-planning` | Skip GSD in Step 7 |

**Approval gates** (stop and wait for user confirmation):
- After Step 2 — confirm research context and domain classification
- After Step 3 — confirm team composition before spawning research agents
- After Step 5 — confirm consensus before output action

---

## Step 2 — Context Detection & Domain Classification

### 2a. Detect project context

Check for project signals by globbing in parallel:
- `package.json`, `pyproject.toml`, `requirements.txt`, `go.mod`, `Cargo.toml`, `*.tf`, `Dockerfile`
- `README.md`, `CLAUDE.md`
- `.planning/PROJECT.md` (GSD project)

If **any** project files exist AND `FORCE_STANDALONE` is not set:
- Set MODE=PROJECT_CONTEXTUAL
- Read README.md and CLAUDE.md if they exist (in parallel)
- Build PROJECT_CONTEXT: project name, detected stack, key file paths (keep under 200 words)

If **no** project files exist OR `FORCE_STANDALONE` is set:
- Set MODE=STANDALONE

### 2b. Classify research domain

Analyze the research question keywords to classify RESEARCH_DOMAIN:

| Keywords / Signals | RESEARCH_DOMAIN |
|---|---|
| API, architecture, framework, library, code, algorithm, distributed, microservice, database | **engineering** |
| market, revenue, business model, pricing, TAM, growth, competition, go-to-market | **business** |
| paper, study, literature, hypothesis, methodology, systematic review, meta-analysis | **academic** |
| investment, valuation, DCF, equity, bonds, portfolio, risk-adjusted, financial model | **financial** |
| experiment, physics, chemistry, biology, genome, molecule, quantum, climate, energy | **science** |
| UX, UI, design system, accessibility, user flow, wireframe, prototype, usability | **design** |
| *(no strong signal)* | **general** |

### 2c. Slugify and set up output directory

Slugify the research question:
- Lowercase, replace spaces/special chars with hyphens, truncate to 60 chars
- Example: "What is the best approach to real-time data sync?" → `best-approach-real-time-data-sync`

Set RESEARCH_DIR=`.research/YYYY-MM-DD-{slug}`

Check if RESEARCH_DIR already exists:
- If yes, ask: "Previous research found at `{RESEARCH_DIR}/`. Re-use findings [enter], start fresh [f], or pick a different question [q]?"
  - **[enter]:** Load existing agent outputs and skip to Step 5
  - **[f]:** Delete existing directory and continue fresh
  - **[q]:** Ask for a new question and restart Step 2

If it doesn't exist, create it:
```bash
mkdir -p "{RESEARCH_DIR}/agents" "{RESEARCH_DIR}/debate"
```

### 2d. Present context

Show this summary and wait for confirmation:

```
Research Question: {QUESTION}
Domain: {RESEARCH_DOMAIN}
Mode: {PROJECT_CONTEXTUAL|STANDALONE}
Depth: {lightweight|deep}
Output: {RESEARCH_DIR}/

{If PROJECT_CONTEXTUAL: "Project: {name} ({stack})"}

Proceed [enter], change domain [d], or edit question [e]?
```

**APPROVAL GATE — Stop and wait for user confirmation before proceeding to Step 3.**

---

## Step 3 — Team Assembly

**Team suggestion table for this skill:**

| RESEARCH_DOMAIN | Suggested Team |
|-----------------|---------------|
| engineering | Software Architect, Backend Engineer, Literature Reviewer, Devil's Advocate, Domain Expert |
| business | Business Analyst, Financial Analyst, Product Manager, Devil's Advocate, Domain Expert |
| academic | Literature Reviewer, Methodologist, Statistician, Devil's Advocate, Domain Expert |
| financial | Financial Analyst, Business Analyst, Statistician, Devil's Advocate, Data Scientist |
| science | Physicist, Literature Reviewer, Methodologist, Statistician, Devil's Advocate |
| design | UX Specialist, UI Designer, End User Advocate, Devil's Advocate, Product Manager |
| general | Literature Reviewer, Devil's Advocate, Domain Expert, Software Architect, Business Analyst |

Context line for approval gate: `Research: "{QUESTION}"`

Read and follow `$GW_REPO/.claude/commands/gw/_shared/team-assembly.md` using the table above for team suggestions.

---

## Step 4 — Parallel Research

Launch one background agent per persona in a SINGLE message using the Agent tool with `run_in_background=true` and `subagent_type="general-purpose"`.

Read the source mapping from `$GW_REPO/.claude/commands/gw/_shared/source-mapping-table.md` and use it to construct source-specific search instructions for each persona.

Read the agent prompt template from `$GW_REPO/.claude/commands/gw/_shared/research-agent-prompt.md` and substitute the placeholders for each persona.

---

## Step 5 — Structured Debate

Read and follow the debate round templates from `$GW_REPO/.claude/commands/gw/_shared/debate-rounds.md`.

**APPROVAL GATE — After debate concludes, present consensus summary and wait for user confirmation before proceeding to Step 6.**

---

## Step 6 — Output Action Dialog

Present the research findings summary and ask what to do:

```
Research Complete: "{RESEARCH_QUESTION}"

Team: {N} specialists across {N} sources
Consensus: {brief 1-line summary}
Confidence: {High|Medium|Low}

What would you like to do with the findings?

  1. PowerPoint   — presentation with findings and recommendations
  2. Report       — detailed Markdown report (optional .docx via pandoc)
  3. Implement    — create GSD project from recommendations {only if MODE=PROJECT_CONTEXTUAL}
  4. Prototype    — standalone script/code demonstrating the recommended approach
  5. Custom       — describe what you want

Pick one or more [1,2], or done [d]?
```

If MODE=STANDALONE, hide option 3 (Implement) unless the user explicitly asks for it.

**APPROVAL GATE — Stop and wait for user selection before proceeding to Step 7.**

---

## Step 7 — Execute Output Action

Execute the user's chosen action(s). If multiple were selected, execute them sequentially.

### Option 1: PowerPoint

Skip if SKIP_PPTX is true.

#### 7a-pptx. Build JSON data file

Write `/tmp/research_presentation_data.json` with all data extracted from CONSENSUS.md, agent research files, and debate files. Include:
- Research question, domain, date, team composition
- Executive summary
- All consensus findings with confidence levels
- Contested findings with positions
- Recommendations by tier
- Key uncertainties
- Source count and retrieval stats

#### 7a-pptx. Write and execute Python script

Write `/tmp/research_presentation.py` — reads the JSON data file and generates a `.pptx` presentation.

Read the design system from `$GW_REPO/.claude/commands/gw/_shared/pptx-design.md`.

**Slide structure:**

| # | Slide | Content |
|---|-------|---------|
| 1 | Title | Research question, domain badge, date, team size |
| 2 | Executive Summary | Answer to the question, key stats as KPI cards (N specialists, N sources, N findings, confidence level) |
| 3 | Methodology | Team composition table with persona names and search_skills, research depth |
| 4 | Consensus Findings | Green cards for high-confidence findings, amber for moderate, with evidence summaries |
| 5 | Contested Findings | Side-by-side Position A vs Position B cards with persona names |
| 6 | Key Uncertainties | What remains unknown, organized by impact level |
| 7 | Recommendations | Tiered recommendation cards: Tier 1 (green), Tier 2 (amber), Tier 3 (gray) with rationale |
| 8 | Devil's Advocate | What was challenged, what survived, what didn't — builds credibility |
| 9 | Closing | "Full report: `{RESEARCH_DIR}/CONSENSUS.md`", date, "Generated by gw:research" |

**Execution:**
```bash
mkdir -p docs/gw
uv run --with python-pptx python /tmp/research_presentation.py
```

Fallback: `python3 -m pip install python-pptx && python3 /tmp/research_presentation.py`

If both fail: "PowerPoint generation failed — python-pptx is required. Install it with `pip install python-pptx` or use `--skip-pptx` to skip presentation generation." Do not generate an HTML fallback.

**Output:** `docs/gw/research-{slug}-YYYY-MM-DD.pptx`

Tell the user where the file was saved.

### Option 2: Report

Read the report structure from `$GW_REPO/.claude/commands/gw/_shared/report-template.md`.

### Option 3: Implement

Read and follow `$GW_REPO/.claude/commands/gw/_shared/implement-templates.md` for CLAUDE.md/SPEC.md generation, copy logic, workflow routing, and GSD integration.

### Option 4: Prototype

Parse CONSENSUS.md to identify independent Tier 1 recommendations that can be prototyped.

1. Read `CONSENSUS.md` from `{RESEARCH_DIR}/`
2. Identify Tier 1 recommendations (highest priority findings)
3. For each Tier 1 recommendation:
   - Set `name` to a slugified version of the recommendation title
   - Set `description` from the recommendation text
   - Extract `acceptance_tests` from the recommendation's success criteria or expected outcome
   - Set `spec_file` to `{RESEARCH_DIR}/CONSENSUS.md`
   - Determine `dependencies` between recommendations (if recommendation B builds on recommendation A, B depends on A). If no ordering is implied, all are independent.
4. Set `project` to `research-<slug>` (using the research question slug)
5. Set `tech_stack` from project context (if PROJECT_CONTEXTUAL) or from the recommendations
6. Write manifest to `{RESEARCH_DIR}/build-manifest.json`
7. Commit: `git add {RESEARCH_DIR}/build-manifest.json && git commit -m "feat: generate prototype build manifest from research"`

Ask:

```
Build manifest generated with <N> prototype features (<W> waves):
  Wave 1: <names>
  ...

Build prototype features in parallel worktrees with TDD? [y] / Single prototype agent (original behavior) [s] / Generate manifest only [m]
```

- `[y]`: invoke `/gw:worktree execute {RESEARCH_DIR}/build-manifest.json`
- `[s]`: fall back to original single-agent behavior:
  - Launch a single foreground agent (`subagent_type="general-purpose"`) with CONSENSUS.md findings
  - Agent writes working code to `{RESEARCH_DIR}/prototype/`
  - Keep it minimal — proof of concept, not production code
  - Tell the user what was created and how to run it
- `[m]`: tell user: "Manifest saved. Run `/gw:worktree execute {RESEARCH_DIR}/build-manifest.json` when ready."

### Option 5: Custom

Ask: "Describe what you'd like to create from the research findings:" and execute the user's request using the research artifacts as context.

### After any output action

Ask: "Another output format, or done? [1-5/d]"
- If the user picks another format, execute it
- If done, proceed to Step 8

---

## Step 8 — Persistence & Cleanup

### 8a. File listing

Show what was created:

```
Research artifacts:
  {RESEARCH_DIR}/
    agents/
      literature-reviewer.md
      devils-advocate.md
      domain-expert.md
      ...
    debate/
      round1/{persona}.md (x{N})
      round2/{persona}.md (x{N})
    CONSENSUS.md
    CLAUDE.md           {if generated}
    SPEC.md             {if generated}
    REPORT.md           {if generated}
    REPORT.docx         {if generated}
    prototype/          {if generated}
  docs/gw/
    research-{slug}-YYYY-MM-DD.pptx  {if generated}
  ./CLAUDE.md                          (copied to project root, if applicable)
  ./SPEC.md                            (copied to project root, if applicable)
```

### 8b. Optional git commit

If the project is a git repo, ask: "Commit research artifacts? [y/n]"

If yes:
```bash
git add "{RESEARCH_DIR}/"
git add docs/gw/research-*.pptx 2>/dev/null || true
git commit -m "docs: add research — {truncated question (50 chars)}

Question: {full question}
Domain: {RESEARCH_DOMAIN}
Team: {N} specialists, {N} sources
Confidence: {High|Medium|Low}"
```

### 8c. Tip

End with a contextual tip:

```
Tip: Re-run with --deep for expanded source coverage, or use a different output format.
     Your research is saved at {RESEARCH_DIR}/ and will be detected on future runs.
```

---

## Step 8.5 — Persona Contribution

Skip this step if `CREATED_PERSONAS` is empty.

Present the created personas:

```
New persona(s) created during this run:
  - {Name1} (workforce/{slug1}.md)
  - {Name2} (workforce/{slug2}.md)

Contribute to gw-skills defaults? This creates a PR to share with all users.
  Contribute [y], skip [n]?
```

If the user selects `[y]`:

1. Save the current directory and branch
2. `cd $GW_REPO`
3. Check for uncommitted changes — if the working tree is dirty, ask: "gw-skills repo has uncommitted changes. Stash them? [y/n]" If yes, `git stash`. If no, abort contribution.
4. Create a branch:
   - Single persona: `persona/{slug}`
   - Multiple personas: `persona/batch-YYYY-MM-DD`
5. For each persona in `CREATED_PERSONAS`:
   - Copy `workforce/{slug}.md` → `workforce/_defaults/{slug}.md`
6. Stage and commit:
   ```bash
   git add workforce/_defaults/
   git commit -m "feat(workforce): add {Name} persona

   Background: {background}
   Created inline during gw:research run."
   ```
   (For multiple personas, list all names in the commit message.)
7. Push: `git push -u origin {branch}`
8. Create PR:
   ```bash
   gh pr create --title "Add {Name} persona to defaults" --body "$(cat <<'EOF'
   ## New Persona: {Name}

   **Background:** {background}
   **Skills used by:** gw:compete, gw:research, gw:review-app, gw:saas-idea
   **Created:** Inline during gw:research run on {date}

   Generated with [Claude Code](https://claude.com/claude-code)
   EOF
   )"
   ```
9. If stashed in step 3, `git stash pop`
10. Return to the original directory and branch
11. Print the PR URL

---

## Step 8.5 — Intent Commit & Auto-PR

Read and follow `$GW_REPO/.claude/commands/gw/_shared/intent-commit.md` to write and commit the `.gw-intent.md` file.

Then read and follow `$GW_REPO/.claude/commands/gw/_shared/auto-pr.md` to create a PR with the `agent_merge` label.

---

Read and follow `$GW_REPO/.claude/commands/gw/_shared/session-summary.md`.

---

## Error Handling

All errors follow the same principle: retry once, then degrade gracefully and continue. Specific cases: failed WebSearch/WebFetch marks source unavailable; failed agent noted as `[FAILED]` with retry offer (max 2); missing python-pptx suggests install or `--skip-pptx`; missing pandoc skips .docx; missing GSD recommends superpowers:writing-plans; missing workforce dir created with `mkdir -p`; existing research dir offers re-use/fresh/change; no question prompts for one. Never force-push or use destructive git operations without asking.
