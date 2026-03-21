---
name: weekly-review
description: Generate executive and technical presentations from GitHub activity
argument-hint: "[<org-or-repo>] [--from YYYY-MM-DD] [--to YYYY-MM-DD] [--author USERNAME] [--add SOURCE] [--remove SOURCE] [--list]"
---

## Step 0 — Preamble

Resolve the gw-skills repo path, then read and follow `$GW_REPO/.claude/commands/gw/_shared/preamble.md` for update check and GSD project detection:

```bash
GW_REPO="$(cd "$(readlink ~/.claude/commands/gw)/../../.." 2>/dev/null && pwd)" || GW_REPO="$HOME/.gw-skills"
```

GW_REPO persists for the duration of this skill run — do not re-resolve it in later steps.

---

Generate two polished PowerPoint presentations from GitHub activity: an **executive deck** (5-6 slides, visual, plain English, no jargon) and a **technical deck** (max 30 slides, detailed, for IT/dev staff). Both decks should look professional enough to present in a meeting — clean layout, data visualizations, consistent design system.

Supports pulling activity from **multiple GitHub orgs and repos** simultaneously via a persistent config file.

## Source configuration

The config file lives at `~/.config/gw-skills/weekly-review.json`. Structure:

```json
{
  "sources": [
    "metabolomics-us",
    "berlinguyinca/personal-project",
    "other-org"
  ]
}
```

Each entry is either an **org name** (queries all repos in that org) or an **org/repo** pair (queries a single repo). The file is managed via `--add`, `--remove`, and `--list` flags, or can be edited manually.

## Step 1 — Parse arguments & handle config management

Parse `$ARGUMENTS`:

| Flag | Variable | Default | Notes |
|------|----------|---------|-------|
| positional `<org-or-repo>` | — | — | Use only this source for this run (does not affect saved config) |
| `--add <SOURCE>` | — | — | Add org or org/repo to saved sources. Create config if needed. Save and **stop** |
| `--remove <SOURCE>` | — | — | Remove org or org/repo from saved sources. Save and **stop** |
| `--list` | — | — | Print saved sources and **stop** |
| `--from <YYYY-MM-DD>` | START_DATE | last Wednesday | If today is Wed–Sun, this week's Wed; if Mon–Tue, last week's Wed |
| `--to <YYYY-MM-DD>` | END_DATE | today | |
| `--author <USERNAME>` | AUTHOR | `@me` | Resolved in Step 2 |

### Resolve sources & classify priority

1. If a positional argument was given, use it as the sole source for this run.
2. Otherwise, read `~/.config/gw-skills/weekly-review.json`. If the file exists and parses as valid JSON with a non-empty `sources` array, use all entries. If the file exists but is malformed JSON, warn the user: "Config file at ~/.config/gw-skills/weekly-review.json is not valid JSON. Fix it or delete it and re-add sources with `--add`." and stop.
3. If neither a positional argument nor a config file with sources exists, ask the user: "No source specified and no saved sources found. Provide an org or repo, or use `--add` to save one for future runs."

For each source, classify it:
- If it contains `/` where the owner part matches the authenticated user's GitHub username → **personal** (side project, lower priority in narrative)
- If it's an org name (no `/`) → **org** (primary, featured prominently)
- If it contains `/` where the owner is NOT the authenticated user → **org** (primary)

Print the computed window for sanity check:
```
Reporting period: YYYY-MM-DD to YYYY-MM-DD
Sources:
  ★ metabolomics-us (org — primary)
  · berlinguyinca/personal-project (personal — side project)
```

## Step 2 — Verify prerequisites

Run these checks in parallel:

1. `gh auth status` — confirm GitHub CLI is authenticated
2. `which uv` — check availability (will fall back to `python3` if missing)
3. `gh api user --jq '.login'` — resolve `@me` to the actual GitHub username
4. `gh api user --jq '.name'` — resolve the user's full display name (e.g. "Gert Wohlgemuth"). If `.name` is null or empty, fall back to the login username.

If `gh auth status` fails, stop and tell the user to run `gh auth login`.

Print: `"Authenticated as FULL_NAME (USERNAME), querying sources for Mon DD–Mon DD..."`

## Step 3 — Fetch GitHub data

All queries use `--json` for field selection and `--limit` for pagination.

**Run queries for ALL sources.** For each source in the resolved sources list, run the appropriate queries (org-wide or single-repo) in parallel across sources. Merge all results together, deduplicating by PR URL.

### 3a. Merged PRs in the reporting window

For each source:

**Org-wide source (no `/`):**
```bash
gh search prs --author=AUTHOR --owner=ORG --merged-at=">=START_DATE" \
  --json title,repository,body,url,closedAt,labels,number --limit 200
```

**Single-repo source (contains `/`):**
```bash
gh pr list --repo ORG/REPO --state merged --search "merged:>=START_DATE" \
  --json title,body,url,mergedAt,labels,additions,deletions,changedFiles --limit 200
```

**Note:** `gh search prs` does NOT support `mergedAt`, `additions`, `deletions`, `changedFiles` fields — use `closedAt` as the merge timestamp proxy and omit stats fields. `gh pr list` supports the full field set.

Filter results to only include PRs merged on or before the `--to` date. Merge results from all sources.

### 3a-ii. Enrich org PRs with full context

The `body` field from PR search contains the full PR description — this is **critical** for the executive narrative. For each **org** merged PR, carefully read the `body` to extract:

- **The problem statement** — what was broken, slow, or missing before this change? Look for "## Problem", "## Summary", "## Why", or the first paragraph.
- **The solution impact** — what's different now for users/operators? Look for "## Summary" bullet points, "## Changes", or descriptions of new capabilities.
- **Quantitative evidence** — test counts, performance numbers, coverage percentages, capacity limits, timeout values. E.g. "34/39 modules above 70%", "100k samples: minutes → milliseconds", "retry up to 3 times with 500ms/1s/2s backoff".
- **New tools or commands introduced** — CLI commands, API endpoints, config flags, TUI interfaces. These are concrete deliverables stakeholders can see.
- **Test plan results** — checked boxes (`[x]`) indicate verified work vs unchecked (`[ ]`) pending validation.

Store these extracted details in a `context` field per PR for use in Step 4. This context is what transforms vague chart labels into compelling executive narratives. Without it, the executive deck is generic — with it, you can write things like "Processing nodes now auto-recover stuck samples within 30 minutes (previously required manual restart, affecting ~5% of daily throughput)."

**For org-wide sources**, the `body` field is already included in `gh search prs`. For single-repo sources, it's in `gh pr list`. No additional API calls needed — just read and extract from what's already fetched.

### 3b. Open PRs (currently open, authored by user)

For each source:

**Org-wide source:**
```bash
gh search prs --author=AUTHOR --owner=ORG --state=open \
  --json title,repository,body,url,createdAt,labels,number --limit 100
```

**Single-repo source:**
```bash
gh pr list --repo ORG/REPO --state open --author AUTHOR \
  --json title,body,url,createdAt,labels,additions,deletions,changedFiles --limit 100
```

Merge results from all sources.

### 3c. Commits per repo (supplementary, default branch only)

For each org-wide source:
```bash
gh search commits --author=AUTHOR --owner=ORG --author-date=">=START_DATE" \
  --json repository,sha --limit 500
```

For each single-repo source:
```bash
gh search commits --author=AUTHOR --repo=ORG/REPO --author-date=">=START_DATE" \
  --json repository,sha --limit 500
```

Filter to commits on or before `--to` date. Merge and deduplicate by SHA. Count unique repos and total commits.

### 3d. Empty check

If zero merged PRs AND zero commits across ALL sources: print `"No GitHub activity found for AUTHOR across configured sources between START_DATE and END_DATE."` and stop gracefully.

Print summary:
```
Found N merged PRs, M open PRs, C commits across R repositories.
Sources queried: metabolomics-us, berlinguyinca/skills
```

### 3e. Harvest presentation assets from repos

Search for `.pptx` files committed or modified during the reporting window. These are presentations generated by other tools (e.g. `/gw:merge-it`, `/gw:review-app`) that contain slides, charts, and screenshots worth reusing.

**For each source repo** (run in parallel):

Use a single API call to find `.pptx` files efficiently (avoids N+1 per-commit lookups that hit rate limits):

```bash
gh api "repos/ORG/REPO/commits?since=START_DATET00:00:00Z&until=END_DATET23:59:59Z&per_page=50" \
  --jq '[.[].sha] | join("\n")' | head -10 | while read SHA; do
  gh api "repos/ORG/REPO/commits/$SHA" --jq '.files[]? | select(.filename | endswith(".pptx")) | .filename' 2>/dev/null
done | sort -u
```

**Rate limit guard:** Cap at 10 commits per repo. If `gh api` returns a 403/429, stop scanning that repo and continue with others.

**For single-repo sources**, also check if any `.pptx` files exist at the repo root or in `docs/gw/`:
```bash
gh api "repos/ORG/REPO/contents/" --jq '.[]? | select(.name | endswith(".pptx")) | .name'
gh api "repos/ORG/REPO/contents/docs/gw" --jq '.[]? | select(.name | endswith(".pptx")) | .name' 2>/dev/null
```

**For each discovered `.pptx` file:**

1. Download it to `/tmp/`:
   ```bash
   gh api "repos/ORG/REPO/contents/PATH" --jq '.download_url' | xargs curl -sL -o /tmp/FILENAME
   ```

2. Extract useful assets using Python (`python-pptx`):
   - Read the PPTX and iterate through slides
   - For each slide, extract embedded images (charts, screenshots, diagrams) by iterating `slide.shapes` and checking for `shape.image` — save each as `/tmp/harvested_REPO_slideN_imgM.png`
   - Also extract slide titles and any text content to help decide relevance
   - Record metadata: `{"source_repo": "...", "source_file": "...", "slide_index": N, "slide_title": "...", "images": ["/tmp/harvested_*.png"], "text_preview": "first 50 words..."}`

3. Filter for relevance:
   - Keep images that are charts (bar charts, pie charts, timelines, dashboards) — these are high-value visuals
   - Keep screenshots of tools, UIs, CLI output — these replace placeholder rectangles
   - Discard generic title slides, blank backgrounds, tiny icons

Store all harvested assets in the JSON as:
```json
"harvested_assets": [
  {
    "source_repo": "org/repo",
    "source_file": "docs/gw/changes-presentation-feat-xyz.pptx",
    "slide_title": "What Changed — Before vs After",
    "images": ["/tmp/harvested_repo_s3_i1.png"],
    "text_preview": "Pipeline throughput improved by 3x...",
    "asset_type": "chart|screenshot|diagram|comparison",
    "related_pr_url": "https://github.com/..."
  }
]
```

**Integration rules for the generated deck:**
- When building PR detail slides: if a harvested asset's `related_pr_url` matches the PR being rendered (or `source_file` contains the branch name from the PR), embed the harvested image on that slide instead of (or alongside) the screenshot placeholder. Size it to fill 50-60% of the slide.
- When building executive theme slides: if any harvested assets contain before/after comparisons relevant to a theme, use the asset image as the visual anchor instead of a rendered shape. If assets include dashboard screenshots, consider adding a bonus slide (max 1) after the theme slides.
- When building the technical deck: create a "Visuals from PRs" slide if 3+ assets were harvested — arrange in a 2x2 or 3x2 grid with repo + slide title as caption under each image.
- If no `.pptx` files are found, skip this step silently — no error, no message.

## Step 4 — Categorize & synthesize content

Do this directly — do NOT spawn sub-agents. This is Claude's core analysis step.

### 4a. Classify source priority

Tag every PR and commit with its source priority:
- `"org"` — from organization repos (the real work, featured prominently)
- `"personal"` — from the user's own repos (side projects, mentioned briefly)

### 4b. Categorize each PR

Use a tiered classification:
1. **GitHub labels first:** `bug` → Bug Fix, `enhancement`/`feature` → Feature, `documentation` → Docs, `dependencies` → Maintenance
2. **Title keywords fallback:** `fix`/`bug`/`error`/`patch` → Bug Fix, `add`/`new`/`feat`/`create` → Feature, `improve`/`update`/`refactor`/`optimize` → Improvement, `doc`/`readme` → Docs, `bump`/`dep`/`upgrade` → Maintenance
3. **Remainder** → Other

### 4c. Generate executive narrative (org-first, theme-based)

**Organization work dominates the narrative.** Personal repos get a brief mention at most.

**Use the PR body context extracted in Step 3a-ii to build a top-down, theme-based narrative** — not a list of PRs. The executive deck must make someone glance at it and think "this team ships real value."

#### Theme Synthesis

Read all merged PR data and identify **2-3 natural themes** — clusters of related work that tell a coherent story together. Themes emerge from the data; they are NOT predetermined categories like "Bug Fix" or "Feature."

**Examples of good themes:**
- "Turnaround Time Overhaul" (groups: scheduler priority PR, auto-recovery PR, batch optimization PR)
- "Reliability & Stability" (groups: deadlock fix, temp file cleanup, build fix)
- "Operator Tooling" (groups: dry-run mode, CLI commands, monitoring endpoints)

**Examples of bad themes (too generic):**
- "Features" / "Bug Fixes" / "Improvements" — these are categories, not themes
- "Backend Work" / "Various Updates" — too vague to tell a story

Always produce exactly 2 themes. Add a 3rd only when the data clearly supports 3 distinct stories. Never exceed 3.

#### Headline Generation

Write one bold sentence capturing the week's most impactful story. Use specific numbers from PR bodies when available. This is the sentence people remember.

- BAD: "Several improvements to the processing pipeline"
- GOOD: "Sample processing got dramatically faster — auto-recovery, smarter scheduling, and a 1000x query speedup"

#### Produce the following JSON structure:

- **metadata**: Object with `date_range` (string, e.g. "2026-03-11 – 2026-03-17"), `org` (primary org name), `repos` (array of repo names queried). Derived from the source configuration in Step 1.
- **headline**: Object containing:
  - `text`: One bold sentence (see above).
  - `subtitle`: One supporting sentence with additional context.
  - `kpis`: Exactly 3 outcome-oriented KPI cards. Each is `{"value": "...", "label": "...", "color": "accent|success|danger|warning"}`.
    - KPI values are OUTCOMES with real numbers from PR evidence: "30 min" (auto-recovery time), "1000x" (speedup), "3" (bugs eliminated).
    - NOT activity counts: "12 PRs", "7 features", "45 commits" are meaningless to a lab director.
    - Always 3 cards. If only 2 strong quantitative outcomes exist, the 3rd can be qualitative (e.g., value: "Fixed", label: "macOS Dev Builds").
    - Color mapping: `"accent"` = #3498DB, `"success"` = #27AE60, `"danger"` = #E74C3C, `"warning"` = #F39C12.
- **themes**: Array of 2-3 theme objects, each containing:
  ```json
  {
    "title": "Turnaround Time Overhaul",
    "subtitle": "Faster results for lab users, less manual work for operators",
    "evidence": [
      {
        "claim": "Stuck samples auto-recover in 30 minutes",
        "detail": "Previously required manual operator intervention, stalling results for hours"
      }
    ],
    "visual_anchor": {
      "type": "before_after",
      "before": {"value": "Hours", "detail": "Manual recovery"},
      "after": {"value": "30 min", "detail": "Auto-recovery, priority queue"}
    }
  }
  ```
  - Each theme has 2-3 evidence items. Each evidence item has a bold `claim` (max 10 words) and a gray `detail` (max 25 words) with specific numbers from PR bodies.
  - `visual_anchor` type selection:
    - `"before_after"`: Use when there's a measurable improvement. Fields: `before: {value, detail}`, `after: {value, detail}`.
    - `"metric_callout"`: Use when one big number tells the story. Fields: `value`, `label`.
    - `"count_cards"`: Use when the theme is about breadth. Fields: `cards: [{value, label}, ...]`.
    - `"evidence_list"` (fallback): Use when no quantitative anchor fits. Fields: `items: ["string", ...]`.
- **impact_focus**: Object describing the week's dominant impact category. Analyze all merged PRs and pick the single most representative category:
  - **Productivity** — new tools, CLI commands, automation, dev workflows
  - **Quality of Service** — performance improvements, faster processing, better throughput
  - **Quality of Life** — UX improvements, easier operations, reduced manual work
  - **Features** — new capabilities, new modules, new endpoints
  - **Bug Fixes** — fixing broken behavior, resolving errors
  - **Stability** — reliability, recovery, resilience, error handling
  ```json
  "impact_focus": {
    "category": "Stability",
    "summary": "Self-healing pipeline, capacity guards, and temp file cleanup"
  }
  ```
  The `summary` is a short phrase (max 10 words) listing the 2-3 biggest contributions in that category.
- **whats_next**: Array of max 4 items from open PRs, each: `{"title": "...", "detail": "...", "status": "testing|planned"}`. Title is max 8 words. Detail is max 10 words. Status is lowercase.
- **side_projects**: 1-2 sentences about personal repo activity, or empty string if none. This field is included in the JSON but is not rendered as its own slide. If non-empty, append it as a footnote line at the bottom of the What's Next slide in 11pt MUTED.

**Rules:** No jargon, no code references, no file paths. Every claim must cite specific evidence from PR descriptions. Generic statements like "improved reliability" are not acceptable.

### 4d. Generate technical narrative (org-first)

**Organization PRs get individual slides. Personal PRs are grouped onto one compact table.**

For each significant org merged PR, produce:
- **what_changed**: MAX 15 WORDS. One sentence. (e.g. "Added retry with backoff to materialized view refresh, auto-recreates when missing")
- **why**: MAX 15 WORDS. One sentence. (e.g. "Concurrent test runs caused deadlocks, Python logging silently failed")
- Technical impact area (e.g. "Queue Management", "Data Pipeline", "API", "Infrastructure")
- Technical category (Feature/Bug Fix/etc.)
- Additions/deletions stats (if available)
- **screenshot_worthy**: boolean — true if the PR introduces a visible tool, UI, CLI output, report, dashboard, or API endpoint that could be demonstrated with a screenshot. Indicators: new CLI commands, TUI interfaces, HTML reports, REST endpoints, table/chart output, web UI changes.

For personal PRs, produce a single grouped summary with repo name, PR count, and 1-line (max 8 words) description per PR.

Also produce:
- **Overview stats** (split by org vs personal):
  - org_merged_prs, org_commits, org_repos
  - personal_merged_prs, personal_commits, personal_repos
  - total_additions, total_deletions
- **commits_by_repo**: `{"repo_name": count, ...}` — all repos
- **commits_by_date**: `{"YYYY-MM-DD": count, ...}` — for timeline chart (derive from commit SHAs if dates not available, or estimate from PR merge dates)
- **category_counts**: `{"Feature": N, "Bug Fix": N, ...}` — org PRs only
- **impact_areas**: `{"Queue Management": N, "Data Pipeline": N, ...}` — org PRs grouped by functional area
- **Architecture notes:** cross-repo patterns within the org
- **Open PR technical status:** org open PRs only, with technical state
- **Deep-dive data for highlights:** For each highlight from Step 4e (max 3), produce a deep-dive object:
  - `title`: Short descriptive title (max 6 words)
  - `problem`: 2-3 sentences describing what was broken/missing/slow before this work
  - `approach`: 2-3 sentences describing the technical approach and key design decisions
  - `result`: 2-3 sentences describing the outcome and measurable impact
  - `visual_anchor`: Same visual anchor system as executive themes (prefer `before_after` or `metric_callout`)
  - `screenshot_hint`: Description of what to screenshot for this highlight (derived from matched PRs' `screenshot_hint` fields, or a general description)

### 4e. Spotlight prompt loop

After Step 4d analysis completes, pause and ask:

> "Before I generate the slides — is there any work from this week you're especially proud of and want to spotlight? Describe it briefly and I'll feature it prominently."

**Interaction loop:**

1. User describes something → Claude matches it to one or more merged PRs from the fetched data
2. Claude confirms: "Got it — I'll spotlight [matched PR title]. Anything else?"
3. Loop continues until user says "no", "done", "stop", or similar
4. If user says "skip" or "none" on the first ask, proceed with no highlights

**Store highlights as an array:**

```json
[
  {
    "description": "user's own words",
    "matched_prs": ["url1", "url2"],
    "pr_titles": ["title1", "title2"]
  }
]
```

If no highlights were provided, set `highlights` to an empty array and proceed normally. After collecting highlights, finalize the Step 4d deep-dive data before proceeding to Step 4f.

### 4f. "What I Learned" prompt

After spotlights, ask:

> "One more thing — what's something you learned this week? A technique, tool insight, debugging lesson, or interesting discovery. I'll create a visual for it."

**Interaction:**

1. User describes a learning → Claude distills it into a learning object
2. Claude confirms: "Got it — I'll visualize that. Anything else you learned?"
3. Loop continues until user says "no", "done", or similar (max 3 learnings)
4. If user says "skip" or "none" on the first ask, proceed with no learnings

**For each learning, produce:**

- `title`: Short title (max 6 words)
- `insight`: 1-2 sentence description of the learning
- `visual_type`: One of:
  - `"analogy"` — before/after or comparison (use when the learning involves a contrast or improvement)
  - `"diagram"` — flow or process (use when the learning involves steps or a pipeline)
  - `"quote_card"` — emphasized text with styled background (use when the learning is a principle or insight)
  - `"chart"` — data-based visualization (use when the learning involves numbers)
- `visual_data`: Type-specific data for the renderer:
  - `analogy`: `{"before": {"label": "...", "value": "..."}, "after": {"label": "...", "value": "..."}}`
  - `diagram`: `{"steps": ["Step 1", "Step 2", "Step 3"]}`
  - `quote_card`: `{"quote": "The key insight in one sentence", "attribution": "Context"}`
  - `chart`: `{"labels": ["A", "B"], "values": [10, 90], "chart_type": "bar"}`

Store as a `learnings` array. If empty, set to `[]`.

## Step 5 — Write JSON handoff & generate presentations

### 5a. Write structured JSON

Write all content from Step 4 to `/tmp/weekly_review_data.json` with this structure:

```json
{
  "sources": ["metabolomics-us", "berlinguyinca/skills"],
  "org_sources": ["metabolomics-us"],
  "personal_sources": ["berlinguyinca/skills"],
  "author": "...",
  "start_date": "YYYY-MM-DD",
  "end_date": "YYYY-MM-DD",
  "executive": {
    "metadata": {
      "date_range": "2026-03-11 – 2026-03-17",
      "org": "metabolomics-us",
      "repos": ["repo1", "repo2"]
    },
    "headline": {
      "text": "Sample processing got dramatically faster",
      "subtitle": "Auto-recovery, smarter scheduling, and a 1000x query speedup",
      "kpis": [
        {"value": "30 min", "label": "Auto-Recovery", "color": "accent"},
        {"value": "1000x", "label": "Queue Speedup", "color": "accent"},
        {"value": "3", "label": "Bugs Eliminated", "color": "success"}
      ]
    },
    "themes": [
      {
        "title": "Turnaround Time Overhaul",
        "subtitle": "Faster results for lab users, less manual work for operators",
        "evidence": [
          {
            "claim": "Stuck samples auto-recover in 30 minutes",
            "detail": "Previously required manual operator intervention"
          }
        ],
        "visual_anchor": {
          "type": "before_after",
          "before": {"value": "Hours", "detail": "Manual recovery, FIFO queue"},
          "after": {"value": "30 min", "detail": "Auto-recovery, priority queue"}
        }
      }
    ],
    "whats_next": [
      {
        "title": "Interactive node dashboard",
        "detail": "Terminal UI for processing nodes",
        "status": "testing"
      }
    ],
    "side_projects": ""
  },
  "technical": {
    "stats": {
      "org_merged_prs": 0,
      "org_commits": 0,
      "org_repos": 0,
      "personal_merged_prs": 0,
      "personal_commits": 0,
      "personal_repos": 0,
      "total_additions": 0,
      "total_deletions": 0
    },
    "commits_by_repo": {"repo_name": 0},
    "commits_by_date": {"YYYY-MM-DD": 0},
    "category_counts": {"Feature": 0, "Bug Fix": 0},
    "impact_areas": {"Queue Management": 0, "Data Pipeline": 0},
    "architecture_notes": "...",
    "org_prs": [
      {
        "title": "...",
        "repo": "...",
        "url": "...",
        "category": "Feature|Bug Fix|Improvement|Docs|Maintenance|Other",
        "impact_area": "...",
        "what_changed": "...",
        "why": "...",
        "additions": 0,
        "deletions": 0,
        "merged_at": "...",
        "is_minor": false,
        "screenshot_worthy": false,
        "screenshot_hint": "Description of what screenshot would show, e.g. 'CLI table output of node-status command'"
      }
    ],
    "personal_prs": [
      {
        "title": "...",
        "repo": "...",
        "url": "...",
        "category": "...",
        "one_liner": "..."
      }
    ],
    "open_prs": [
      {
        "title": "...",
        "repo": "...",
        "url": "...",
        "technical_status": "..."
      }
    ],
    "harvested_assets": [
      {
        "source_repo": "org/repo",
        "source_file": "docs/gw/changes-presentation-feat-xyz.pptx",
        "slide_title": "...",
        "images": ["/tmp/harvested_repo_s3_i1.png"],
        "text_preview": "...",
        "asset_type": "chart|screenshot|diagram|comparison",
        "related_pr_url": "..."
      }
    ]
  },
  "highlights": [
    {
      "user_description": "The scheduling recovery system — really proud of how it handles all edge cases",
      "matched_pr_urls": ["https://github.com/..."],
      "matched_pr_titles": ["feat: scheduling recovery..."],
      "deep_dive": {
        "title": "Scheduling Recovery System",
        "problem": "Samples stuck in SCHEDULING state were lost forever when SQS sends failed",
        "approach": "Added Phase 1.5 detection with configurable 30-minute timeout and capacity-aware rescheduling",
        "result": "Stuck samples now auto-recover without operator intervention, with structured cycle metrics for visibility",
        "visual_anchor": {"type": "before_after", "before": {"value": "...", "detail": "..."}, "after": {"value": "...", "detail": "..."}},
        "screenshot_hint": "CLI table showing sync cycle metrics with recovery counts"
      }
    }
  ],
  "learnings": [
    {
      "title": "Bulk queries beat N+1",
      "insight": "Replacing per-sample DB lookups with a single bulk query improved performance 1000x for 100k samples",
      "visual_type": "analogy",
      "visual_data": {
        "before": {"label": "N+1 Queries", "value": "Minutes"},
        "after": {"label": "Bulk Query", "value": "Milliseconds"}
      }
    }
  ]
}
```

### 5b. Write Python script

Write a Python script to `/tmp/weekly_review_gen.py` that reads the JSON and generates both `.pptx` files.

**Design system (apply to both decks):**

```
Colors:
  PRIMARY      = #2C3E50  (dark blue-gray — titles, emphasis)
  SECONDARY    = #34495E  (medium blue-gray — subtitles)
  ACCENT       = #3498DB  (bright blue — charts, highlights, KPI values)
  SUCCESS      = #27AE60  (green — additions, positive metrics)
  DANGER       = #E74C3C  (red — deletions, bug counts)
  WARNING      = #F39C12  (amber — coming soon, caution)
  MUTED        = #95A5A6  (gray — secondary text, minor items)
  BG_WHITE     = #FFFFFF  (slide background)
  BG_LIGHT     = #F8F9FA  (card/panel backgrounds)
  CARD_BORDER  = #E0E0E0  (subtle borders)

Typography:
  Title:     Calibri 32pt bold, PRIMARY
  Subtitle:  Calibri 18pt, SECONDARY
  Heading:   Calibri 24pt bold, PRIMARY
  Body:      Calibri 14pt, SECONDARY
  Caption:   Calibri 11pt, MUTED
  KPI Value: Calibri 36pt bold, ACCENT
  KPI Label: Calibri 12pt, MUTED

Layout:
  Slide dimensions: 16:9 widescreen (13.333" × 7.5")
  Margins: 0.7" left/right, 0.5" top/bottom
  Accent bar: 0.06" wide strip at left edge of every slide, color ACCENT
```

**Defensive rules for the Python script:**
- Truncate titles to 80 characters max
- Truncate bullet text to 150 characters max
- Cap table rows at 10 per slide
- Use matplotlib with `Agg` backend (non-interactive) for all charts
- Save chart images to temp files and embed as images in slides using `slide.shapes.add_picture()`
- **Skip degenerate charts:** Before rendering any chart, check if it would be meaningless:
  - Donut/pie chart with only 1 category → skip, show as a single KPI card instead
  - Bar chart where all bars have the same value → skip, mention the uniform value as text
  - Area/line chart with only 1 data point → skip, show as a single stat
  - Area/line chart where all values are identical (flat line) → skip, show as text "N commits/day (steady)"
  - Any chart with 0 total data → skip entirely
  - Bar chart with only 1 bar → skip, show as a KPI card
  - Replace skipped charts with a clean text card or merge the data into an adjacent slide
- Handle empty sections gracefully — skip slides that would have no content
- Every slide gets the left accent bar (thin colored rectangle at x=0, full height)
- Use `RGBColor` for all colors, `Pt` for font sizes, `Inches` for positioning
- Set `paragraph.space_after = Pt(6)` for breathing room between bullets

**Matplotlib chart style (apply globally):**
```python
plt.rcParams.update({
    'font.family': 'sans-serif',
    'font.size': 11,
    'axes.spines.top': False,
    'axes.spines.right': False,
    'axes.edgecolor': '#E0E0E0',
    'axes.labelcolor': '#34495E',
    'xtick.color': '#95A5A6',
    'ytick.color': '#95A5A6',
    'figure.facecolor': 'white',
    'axes.facecolor': 'white',
    'grid.color': '#F0F0F0',
    'grid.linestyle': '-',
    'grid.linewidth': 0.5,
})
```

---

### DESIGN PRINCIPLE: VISUAL + CONTEXT

**The executive deck tells a story to non-technical stakeholders.** Each slide has a clear visual element — KPI cards, evidence-and-anchor layouts, or status rows — paired with concise explanatory text that answers "why does this matter?"

**Balance rule: every slide has one job.** The headline slide sets the week's story with 3 outcome KPIs. Theme slides pair evidence bullets with a visual anchor. The What's Next slide is scannable rows. No charts for the sake of charts — only visuals that add insight.

**The technical deck is more chart-heavy** (~70% visual) since the audience understands the data.

---

### Executive deck — `CWD/docs/gw/weekly-review-executive-YYYY-MM-DD.pptx` (5-9 slides)

| # | Slide | Content |
|---|-------|---------|
| 1 | **Title** | "Development Update" large title. Author's full name (from `author_name`) in 20pt SECONDARY below the title. Org name(s) + date range as subtitle below that. **Impact line:** "This week's focus: {category} — {summary}" in 16pt italic MUTED, positioned at bottom third of slide (y=5.5"). Light background (#F8F9FA). Clean, minimal. |
| 2 | **Headline & KPIs** | Light gray background (#F8F9FA). The `headline.text` as 28pt bold text at top. `headline.subtitle` as 16pt gray text below. 3 KPI cards at bottom — white rounded rectangles with subtle border (#E0E0E0), large number (36pt bold, color from `kpis[].color` token mapped to hex), small uppercase label (11pt, MUTED) below. Color token mapping: `"accent"` → #3498DB, `"success"` → #27AE60, `"danger"` → #E74C3C, `"warning"` → #F39C12. |
| 3-4 | **Theme Slides** (2, or 3 if data supports it) | White background. Theme `title` as 24pt bold at top, `subtitle` as 14pt gray below. **Left column (60%):** 2-3 evidence bullets, each with a 3px blue (#3498DB) left border. Bold `claim` (14pt, PRIMARY) + gray `detail` (12pt, MUTED) below. **Right column (40%):** Visual anchor, rendered by type: **`before_after`**: Two stacked rounded rectangles — red top (#FDF2F2 bg, #E74C3C text) with "Before" label + value + detail, arrow "↓" between, green bottom (#F0FAF4 bg, #27AE60 text) with "After" label + value + detail. **`metric_callout`**: Single large centered number (48pt bold, ACCENT) with label (14pt, MUTED). **`count_cards`**: 2-3 small stat boxes side by side, each with bold number + small label. **`evidence_list`**: Compact bulleted list of items in SECONDARY 12pt. |
| 5-7 | **Spotlight slides** (0-3) | **One per highlight.** Title: "Spotlight: [title]" (24pt bold PRIMARY). **Left 55%:** problem text (2 sentences, 14pt SECONDARY) + spacer + result text (2 sentences, 14pt bold SUCCESS) + user's description in quotes (12pt italic MUTED). **Right 45%:** large screenshot placeholder (dashed border rectangle filling right side, "Screenshot: [hint]" in MUTED 14pt centered). Simple narrative layout — no PROBLEM/APPROACH/RESULT labels. Cap at 3 slides. **Skip if no highlights.** |
| | **What I Learned** | White background. Title "What I Learned" (24pt bold PRIMARY). 1-3 learning cards arranged horizontally as rounded rectangles. Each card: matplotlib-generated visual in top half (analogy comparison, flow diagram, styled quote card, or chart), title (14pt bold PRIMARY) and insight text (12pt SECONDARY) in bottom half. Card sizing: 1 card = full width, 2 = side-by-side, 3 = three across. **Skip if no learnings.** |
| Last | **What's Next** | White background. Title "What's Next" (24pt bold). Max 4 rows, each on a light gray (#F8F9FA) row background with rounded corners. Each row: status pill (small rounded rectangle — TESTING = #F39C12, PLANNED = #3498DB, white text, 9pt bold) + title (14pt bold, PRIMARY) + detail (12pt, MUTED). |

---

### Technical deck — `CWD/docs/gw/weekly-review-technical-YYYY-MM-DD.pptx` (max 25 slides)

| # | Slide | Content |
|---|-------|---------|
| 1 | **Title** | Title, author, sources, date range. |
| 2 | **Stats Dashboard** | **Full-slide visual dashboard.** Top row: 6 metric cards (2×3 grid) — big numbers, tiny labels. Bottom half: horizontal bar chart of commits-by-repo (sorted desc, ACCENT colored, bar labels). This is the "at a glance" slide. |
| 3 | **Commit Heatmap** | **Full-slide matplotlib chart.** Area chart of commits-by-date. Large, fills ~80% of slide. Clean axes, grid, date labels on x-axis. Title: "Commit Activity". |
| 4 | **Work Distribution** | **Two charts side-by-side, each ~45% of slide width.** Left: donut chart of `impact_areas` (ring, center = total PRs). Right: horizontal color-coded bar chart of `category_counts`. Title: "Where & What". |
| 5 | **Code Volume** | **Full-slide grouped bar chart.** For each repo: green bar (additions) up, red bar (deletions) beside it. Net change as annotation above each group. Title: "Code Volume". |
| 6 | **Architecture** | **Visual repo-relationship diagram** built with matplotlib. Each repo as a colored circle/node (size = commit count). Lines between repos if PRs reference both. Annotations with short description of cross-repo patterns. Fallback: if only 1 repo, just show a single labeled circle with key stats around it. **Skip if trivial.** |
| 7–N | **PR Detail slides** | **One slide per significant non-minor org PR. MAX 3 lines of text per slide.** Layout: Title (22pt, 1 line). One-sentence "what changed" (14pt, max 15 words). One-sentence "why" (14pt italic SUCCESS, max 15 words). Right side: colored category badge + impact area badge + merge date. If additions/deletions available: +/- badge. **If `screenshot_worthy` is true**: add a large gray dashed-border placeholder rectangle (60% of slide, centered) with text "Screenshot: {screenshot_hint}" in MUTED 14pt — this signals the presenter to paste an actual screenshot before presenting. **Cap at 15 slides.** |
| N+1… | **Deep Dive: [title] — Problem & Approach** | **Slide 1 of each highlight (max 3 highlights).** Title: "Deep Dive: [title]" (22pt bold PRIMARY). Left 60%: "PROBLEM" label (9pt DANGER) + text (12pt SECONDARY), then "APPROACH" label (9pt ACCENT) + text (12pt SECONDARY). Right 40%: visual anchor (same rendering as executive theme slides). **Skip if no highlights.** |
| | **Deep Dive: [title] — Changes** | **Slide 2 of each highlight.** Title: "What Changed" (22pt bold PRIMARY), subtitle: "[title]" (14pt MUTED). List all matched PRs for this highlight with their `what_changed` one-liner (14pt SECONDARY) and repo badge. 1-2 PRs: show with more detail. 3+ PRs: compact table. Screenshot placeholder if any matched PR is `screenshot_worthy`. |
| | **Deep Dive: [title] — Results** | **Slide 3 of each highlight.** Title: "Results & Impact" (22pt bold PRIMARY). "RESULT" label (9pt SUCCESS) + result text (14pt SECONDARY). Visual anchor (large, centered). Key metrics or test evidence from PR bodies. Screenshot placeholder at bottom right. |
| | **Minor & Personal** | **Combined into one compact slide.** Two sections: "Minor Changes" (small table: title, repo, category — max 5 rows). "Side Projects" (small table: title, repo, one-liner — max 5 rows). Tables use MUTED styling. **Skip if neither exists.** |
| N+2 | **Open PRs** | **Visual pipeline.** Matplotlib horizontal bar chart where each open PR is a bar, width = rough scope, colored by repo. Bar labels = short PR title (max 6 words). Title: "In Progress". **Skip if none.** |
| Last | **Links** | Compact URL reference. Repo name as small blue header, PR links as 9pt MUTED text. Minimal space — this is a reference slide, not for presenting. |

---

**Important Python implementation details:**
- Import `json`, `os`, `sys`, `tempfile` at the top
- Use `from pptx import Presentation` and related imports from `python-pptx`
- Use `from pptx.util import Inches, Pt, Emu` and `from pptx.dml.color import RGBColor`
- Use `from pptx.enum.text import PP_ALIGN` and `from pptx.enum.shapes import MSO_SHAPE`
- Use `matplotlib`; set `matplotlib.use('Agg')` BEFORE importing `pyplot`
- For charts: save matplotlib figures to `/tmp/*.png` at 200 DPI, then embed as images
- For the left accent bar: `slide.shapes.add_shape(MSO_SHAPE.RECTANGLE, 0, 0, Inches(0.06), Inches(7.5))` with ACCENT fill and no border
- For KPI cards: use `add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, ...)` with BG_LIGHT fill
- For category pills: small rounded rectangles with category-appropriate fill color
- Accept output directory as `sys.argv[1]` (default to current directory)
- Print the absolute paths of both generated files on success

**Executive deck renderer — new slide types:**

The executive section of the Python renderer must generate these slides from the `executive` key in the JSON:

**Slide 1 (Title):** "Development Update" as 32pt bold PRIMARY. Author's full name (from `data["author_name"]`) as 20pt SECONDARY below title. Org names + date range as 18pt SECONDARY below that. Impact line: `"This week's focus: {category} — {summary}"` from `executive.impact_focus`, rendered as 16pt italic MUTED at y=5.5". Use BG_LIGHT fill for slide background.

**Slide 2 (Headline + KPIs):**
- Background: BG_LIGHT (#F8F9FA) — add a full-slide rounded rectangle with BG_LIGHT fill behind everything
- Headline text: 28pt bold PRIMARY, positioned at (0.7", 0.5"), width 11", word wrap
- Subtitle: 16pt MUTED, below headline
- 3 KPI cards at bottom: white rounded rectangles with CARD_BORDER (#E0E0E0) border, centered horizontally
  - Card width: 3.5", height: 1.4", gap: 0.5" between cards
  - Value: 36pt bold, color from token mapping (accent→ACCENT, success→SUCCESS, danger→DANGER, warning→WARNING)
  - Label: 11pt uppercase MUTED, centered below value

**Slides 3-4 (Theme slides):**
- Background: white
- Title: 24pt bold PRIMARY at (0.7", 0.4")
- Subtitle: 14pt MUTED at (0.7", 0.85")
- Left column (60%, from x=0.7" to x=7.8"):
  - Evidence bullets starting at y=1.5", each bullet block is ~1.2" tall
  - Each bullet: blue accent bar shape (0.04" wide, ~0.8" tall, ACCENT fill) at left edge
  - Claim text: 14pt bold PRIMARY, indented 0.15" right of accent bar
  - Detail text: 12pt MUTED, same indent, below claim
- Right column (40%, from x=8.2" to x=12.6"):
  - Visual anchor rendering by type:
  - `before_after`: Two stacked rounded rectangles
    - "Before" box: fill RGBColor(0xFD, 0xF2, 0xF2), y starts at 1.5". Label "BEFORE" in 9pt DANGER uppercase, value in 22pt bold DANGER, detail in 11pt MUTED. Height: 1.6"
    - Arrow "↓" text between boxes in 18pt MUTED, centered
    - "After" box: fill RGBColor(0xF0, 0xFA, 0xF4). Same layout as before but SUCCESS colors. Height: 1.6"
  - `metric_callout`: Single centered block. Value in 48pt bold ACCENT, label in 14pt MUTED below.
  - `count_cards`: 2-3 small rounded rectangles side by side, each with bold number (24pt ACCENT) and label (10pt MUTED).
  - `evidence_list`: Bulleted text list, each item 12pt SECONDARY with bullet character "•".

**Slide 5 (What's Next):**
- Title "What's Next" at (0.7", 0.4"), 24pt bold PRIMARY
- Each item is a row with light gray (#F8F9FA) rounded rectangle background
  - Row height: 0.8", gap: 0.3" between rows, starting at y=1.3"
  - Status pill: small rounded rectangle (width: 1.1", height: 0.35"), centered vertically in row
    - "testing" → WARNING fill, white 9pt bold text "TESTING"
    - "planned" → ACCENT fill, white 9pt bold text "PLANNED"
  - Title: 14pt bold PRIMARY, positioned right of pill
  - Detail: 12pt MUTED, right-aligned or after title

**Slides 5-7 (Spotlight slides):**

For each entry in the top-level `highlights` array (max 3), generate one Spotlight slide in the executive deck, inserted after theme slides and before What's Next:

- Background: white, with left accent bar
- Title: "Spotlight: [title]" at (0.7", 0.4"), 24pt bold PRIMARY
- Left column (55%, x=0.7" to x=7"):
  - Problem text: 14pt SECONDARY, starting at y=1.3", word-wrapped, max 3 sentences
  - Result text: 14pt bold SUCCESS, starting at y=3.5", max 3 sentences
  - User's description in quotes: 12pt italic MUTED, starting at y=5.5"
- Right column (45%, x=7.3" to x=12.6"):
  - Large screenshot placeholder: dashed-border rectangle from y=1.3" to y=6.5"
  - Text inside: "Screenshot: [screenshot_hint or title]" in MUTED 14pt, centered vertically
- If `highlights` is empty or missing, skip Spotlight slides entirely.

**What I Learned slide:**

For each entry in the top-level `learnings` array (max 3), generate a learning card on a single shared slide:

- Background: white, accent bar
- Title: "What I Learned" at (0.7", 0.4"), 24pt bold PRIMARY
- Learning cards starting at y=1.3", arranged horizontally:
  - Card sizing: 1 card = 11.9" wide, 2 cards = 5.7" each with 0.3" gap, 3 cards = 3.7" each with 0.3" gap
  - Each card: rounded rectangle with BG_LIGHT fill, height 5.5"
  - Top half (~3"): matplotlib-generated visual embedded as image, based on `visual_type`:
    - `"analogy"`: Two horizontal bars — red "before" bar (shorter) and green "after" bar (longer), with labels and values
    - `"diagram"`: Horizontal flow with boxes connected by arrows, each box containing a step label
    - `"quote_card"`: Large opening quote mark ("\u201C") in ACCENT 72pt, quote text in 16pt bold PRIMARY, attribution in 11pt MUTED below
    - `"chart"`: Simple bar or line chart from `visual_data.labels` and `visual_data.values`
  - Bottom half (~2.5"): title (14pt bold PRIMARY, centered) + insight text (12pt SECONDARY, centered, word-wrapped)
- If `learnings` is empty or missing, skip this slide entirely.

**Removed from executive renderer:**
- The `make_hbar_highlights()` chart call and "Key Deliverables" slide
- The "Impact Details" expanded text slide
- The "Issues Resolved" slide (bug fixes are now folded into themes)
- The `make_donut_chart()` call and "Focus Areas" slide
- The "In Testing & Coming Soon" paragraph-style slide
- The "Side Projects" slide
- The `extract_status_tag()` helper (no longer needed for executive deck)
- The hardcoded `exec_summary` paragraph

**Kept for executive renderer:**
- `new_slide()`, `add_accent_bar()`, `add_text_box()`, `add_paragraph()`, `set_run()`, `add_rounded_card()`, `trunc()` helpers
- `SLIDE_W`, `SLIDE_H`, `FONT`, and all color constants
- The title slide (Slide 1) — just update background to BG_LIGHT

**Technical deck renderer — Deep Dive slides (3 per highlight):**

For each entry in the top-level `highlights` array (max 3), generate **3 slides** in the technical deck, inserted after the PR Detail slides and before Minor & Personal:

**Slide 1 — Problem & Approach:**
- Background: white, accent bar
- Title: "Deep Dive: [title]" at (0.7", 0.4"), 22pt bold PRIMARY
- Left 60% (x=0.7" to x=7.8"):
  - "PROBLEM" label: 9pt uppercase bold DANGER at y=1.3", text: 12pt SECONDARY below (~1.5" block)
  - "APPROACH" label: 9pt uppercase bold ACCENT, text: 12pt SECONDARY below (~1.5" block)
- Right 40% (x=8.2" to x=12.6"): Visual anchor (same rendering as executive theme slides)

**Slide 2 — What Changed:**
- Background: white, accent bar
- Title: "What Changed" at (0.7", 0.4"), 22pt bold PRIMARY
- Subtitle: "[title]" at (0.7", 0.85"), 14pt MUTED
- List all matched PRs for this highlight starting at y=1.5":
  - Each PR: repo badge (small rounded rectangle, ACCENT fill, 9pt white) + `what_changed` text (14pt SECONDARY) + `why` text (12pt MUTED italic)
  - If 1-2 PRs: show with more detail (2 lines each)
  - If 3+ PRs: compact single-line format
- Screenshot placeholder at bottom (y=4.5" to y=6.8") if any matched PR has `screenshot_worthy: true`. Text: "Screenshot: [screenshot_hint]"

**Slide 3 — Results & Impact:**
- Background: white, accent bar
- Title: "Results & Impact" at (0.7", 0.4"), 22pt bold PRIMARY
- Subtitle: "[title]" at (0.7", 0.85"), 14pt MUTED
- "RESULT" label: 9pt uppercase bold SUCCESS at y=1.3", text: 14pt SECONDARY below (3 sentences max)
- Visual anchor: rendered large and centered at (3", 3.5"), width 7"
- Screenshot placeholder at bottom-right (x=8", y=5", w=4.6", h=2") if screenshot_hint available

If `highlights` is empty or missing, skip Deep Dive slides entirely.

### 5c. Execute the script

```bash
mkdir -p docs/gw
uv run --with python-pptx,matplotlib python /tmp/weekly_review_gen.py "OUTPUT_DIR"
```

If `uv` is not available, fall back to:
```bash
python3 -m pip install python-pptx matplotlib && python3 /tmp/weekly_review_gen.py "OUTPUT_DIR"
```

If the Python script fails: show the error output, examine the script for issues, fix, and retry once. If it fails again, show the error and offer to generate HTML fallback instead.

## Step 6 — Report results

Print the absolute paths of both generated files:
```
Executive deck: /absolute/path/to/docs/gw/weekly-review-executive-YYYY-MM-DD.pptx
Technical deck: /absolute/path/to/docs/gw/weekly-review-technical-YYYY-MM-DD.pptx
```

Plus a brief content summary:
```
Covered N org PRs (F features, B bug fixes, I improvements) + P personal PRs across R repositories.
```

## Final — Session Summary

Print a summary of all files created during this session:

```
Session complete. Generated files:
  [new]   docs/gw/weekly-review-executive-YYYY-MM-DD.pptx
  [new]   docs/gw/weekly-review-technical-YYYY-MM-DD.pptx
  [skip]  <description of skipped output> (--skip-flag)
  ...

Total: N files created, N skipped
```

List each file that was created with `[new]` and each output that was skipped (due to --skip flags) with `[skip]`.

---

## Error handling

- **`gh` command failures:** Show the error message and ask the user how to proceed.
- **Python script failure:** Show the error, attempt to fix the script, retry once. If still failing, offer HTML fallback.
- **Missing `python-pptx`:** The `uv run --with` approach handles this. If both `uv` and `pip` fail, fall back to generating HTML presentation files.
- **Rate limiting from GitHub API:** Wait 5 seconds, retry once. If still rate-limited, report the issue and suggest narrowing the date range or specifying a single repo.
