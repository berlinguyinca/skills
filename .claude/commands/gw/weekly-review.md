---
name: weekly-review
description: Generate executive and technical presentations from GitHub activity
argument-hint: "[<org-or-repo>] [--from YYYY-MM-DD] [--to YYYY-MM-DD] [--author USERNAME] [--add SOURCE] [--remove SOURCE] [--list]"
---

## Step 0 — Update check

Resolve the gw-skills repo directory and run its update check script:

```bash
GW_REPO="$(cd "$(readlink ~/.claude/commands/gw)/../../.." 2>/dev/null && pwd)" || GW_REPO="$HOME/.gw-skills"
bash "$GW_REPO/check-update.sh" 2>/dev/null || true
```

If the output contains `UPDATE_AVAILABLE`, tell the user how many commits behind they are and ask: "gw-skills has updates available. Run /gw:update to install them, or continue?" If they want to update, invoke `/gw:update` and stop. Otherwise continue. If the script is missing or fails, skip silently.

---

Generate two polished PowerPoint presentations from GitHub activity: an **executive deck** (max 8 slides, visual, plain English, no jargon) and a **technical deck** (max 30 slides, detailed, for IT/dev staff). Both decks should look professional enough to present in a meeting — clean layout, data visualizations, consistent design system.

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

- `--add SOURCE` = add an org or org/repo to the saved sources list. Create the config directory and file if they don't exist (`mkdir -p ~/.config/gw-skills`). Read the existing config (or start with `{"sources": []}`), append the new source (skip if already present), write back, confirm, and **stop**.
- `--remove SOURCE` = remove an org or org/repo from the saved sources list. If not found, say so. Write back, confirm, and **stop**.
- `--list` = print the current saved sources and **stop**. If no config file exists, say "No sources configured. Use `/gw:weekly-review --add <org-or-repo>` to add one."
- **First positional argument** (optional) = org name (e.g. `metabolomics-us`) or `org/repo` (e.g. `metabolomics-us/carrot`). If provided, use **only this source** for this run (does not affect saved config).
- `--from YYYY-MM-DD` = start date (inclusive). **Default:** last Wednesday (compute dynamically from today's date).
- `--to YYYY-MM-DD` = end date (inclusive). **Default:** today.
- `--author USERNAME` = GitHub username. **Default:** `@me` (resolved in Step 2).

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

If `gh auth status` fails, stop and tell the user to run `gh auth login`.

Print: `"Authenticated as USERNAME, querying sources for Mon DD–Mon DD..."`

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

Search for `.pptx` files committed or modified during the reporting window. These are presentations generated by other tools (e.g. `/gw:merge-it`, `/gw:analyze-app`) that contain slides, charts, and screenshots worth reusing.

**For each source repo** (run in parallel):

Use a single API call to find `.pptx` files efficiently (avoids N+1 per-commit lookups that hit rate limits):

```bash
gh api "repos/ORG/REPO/commits?since=START_DATET00:00:00Z&until=END_DATET23:59:59Z&per_page=50" \
  --jq '[.[].sha] | join("\n")' | head -10 | while read SHA; do
  gh api "repos/ORG/REPO/commits/$SHA" --jq '.files[]? | select(.filename | endswith(".pptx")) | .filename' 2>/dev/null
done | sort -u
```

**Rate limit guard:** Cap at 10 commits per repo. If `gh api` returns a 403/429, stop scanning that repo and continue with others.

**For single-repo sources**, also check if any `.pptx` files exist at the repo root or in `doc/`:
```bash
gh api "repos/ORG/REPO/contents/" --jq '.[]? | select(.name | endswith(".pptx")) | .name'
gh api "repos/ORG/REPO/contents/doc" --jq '.[]? | select(.name | endswith(".pptx")) | .name' 2>/dev/null
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
    "source_file": "doc/changes-presentation-feat-xyz.pptx",
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
- When building the executive "What We Shipped" slide: if any harvested assets contain before/after comparisons or dashboard screenshots, add a bonus "Demo" slide right after with the best 2-3 harvested images arranged in a grid with tiny captions.
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

### 4c. Generate executive narrative (org-first)

**Organization work dominates the narrative.** Personal repos get a brief mention at most.

Transform developer PR titles into plain-English, user-facing language. Produce:

- **headline**: A single-sentence summary of the week's most impactful achievement (e.g. "Pipeline reliability upgrade eliminates manual intervention for stuck samples")
- **kpi_cards**: 4 key metrics as label+value pairs for a dashboard row (e.g. `[{"label": "PRs Shipped", "value": "15"}, {"label": "Bugs Fixed", "value": "3"}, {"label": "Repos Active", "value": "4"}, {"label": "Test Coverage", "value": "34/39 modules"}]`)
- **highlights**: 3-5 items, each a JSON object:
  ```json
  {
    "short_label": "Auto-recovery for stuck samples",  // MAX 8 WORDS — chart label
    "impact_score": 5,                                   // 1-5, 5=highest
    "category": "Feature",                               // Feature|Bug Fix|Improvement
    "user_impact": "Lab users no longer need to manually restart stuck samples — the system detects and recovers them automatically within 30 minutes."  // 1-2 SENTENCES, plain English, explains why this matters to a non-technical stakeholder
  }
  ```
- **bug_fixes**: list of `{"short_label": "...", "user_explanation": "..."}`. `short_label` MAX 8 WORDS (chart label). `user_explanation` is 1 sentence explaining what was broken and how it affects users, in plain English.
- **coming_soon**: org open PRs as JSON objects `{"short_label": "...", "scope": "small|medium|large", "repo": "...", "user_impact": "..."}`. `short_label` MAX 6 WORDS. `user_impact` is 1 sentence explaining why this matters.
- **side_projects**: 2-3 sentences about personal repo activity. e.g. "Shipped 4 updates to ai-sync, a tool for synchronizing AI coding assistant configurations across machines. Key improvement: pull no longer overwrites local changes."

**Rules:** No jargon, no code references, no file paths. Chart labels are SHORT (6-8 words). But every chart has accompanying plain-English explanatory text (1-2 sentences) that tells stakeholders why it matters. Think of the audience as a lab director who wants to understand impact, not implementation.

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
    "headline": "...",
    "kpi_cards": [{"label": "...", "value": "..."}],
    "highlights": [{"short_label": "...", "impact_score": 5, "category": "Feature", "user_impact": "1-2 sentence explanation of why this matters to users"}],
    "bug_fixes": [{"short_label": "...", "user_explanation": "What was broken and how it affects users"}],
    "coming_soon": [{"short_label": "...", "scope": "medium", "repo": "...", "user_impact": "Why this matters"}],
    "side_projects": "..."
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
        "source_file": "doc/changes-presentation-feat-xyz.pptx",
        "slide_title": "...",
        "images": ["/tmp/harvested_repo_s3_i1.png"],
        "text_preview": "...",
        "asset_type": "chart|screenshot|diagram|comparison",
        "related_pr_url": "..."
      }
    ]
  }
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

**The executive deck tells a story to non-technical stakeholders.** Each slide pairs a visual (chart, dashboard, diagram) with brief explanatory text that answers "why does this matter?" Charts alone are too cryptic for a lab director — they need 1-2 sentences of context per visual.

**Balance rule: ~50% visual, ~50% concise text.** Charts grab attention, text provides meaning.

- Every chart slide includes 2-3 sentences explaining what the audience is looking at and why it's important.
- Bullets: max 5 per slide, max 20 words each. Plain English, user-impact focused.
- KPI cards use BIG numbers (40pt+) with tiny labels.
- Use matplotlib for data visualization. Charts should be clear enough to understand in 3 seconds.

**The technical deck is more chart-heavy** (~70% visual) since the audience understands the data.

---

### Executive deck — `CWD/weekly-review-executive-YYYY-MM-DD.pptx` (max 10 slides)

| # | Slide | Content |
|---|-------|---------|
| 1 | **Title** | "Development Update" large title. Org name(s) + date range as subtitle. Clean, minimal. |
| 2 | **Dashboard** | **Visual dashboard — the overview slide.** Top row: 4 KPI cards (rounded rects, BIG number 40pt + tiny label 11pt). Middle: area chart of commits-by-date spanning full width (~10" wide). Bottom: `headline` as 16pt italic caption — this one sentence frames the entire week's narrative. |
| 3 | **What We Shipped** | **Left 55%: horizontal bar chart** of highlights (short_label on y-axis, impact_score on x-axis, colored by category). **Right 40%: 3-5 plain-English bullets** explaining the top items and their user/lab impact. Each bullet is 1 sentence, max 20 words, answering "what does this mean for users?" Title: "Key Deliverables". |
| 4 | **Highlights Detail** | **Top 3 highlights expanded.** For each: a short title (bold, 16pt) + 1-2 sentences explaining the user-facing benefit in plain English (14pt). Use numbered items or small accent-colored cards. No jargon. Think: "Lab users now get their results 2x faster because the system automatically handles stuck samples instead of waiting for manual fixes." This is the slide people actually read and discuss. |
| 5 | **Bug Fixes & Reliability** | **Left: small bar or icon chart** showing bug fix count and categories. **Right: 2-4 plain-English bullets** explaining what was broken and how it's now fixed, from the user's perspective. E.g. "Processing servers were running out of disk space — this is now cleaned up automatically." **Skip if no bug fixes.** |
| 6 | **Where We Worked** | **Two charts side by side.** Left (50%): donut chart of `impact_areas` with total in center. Right (50%): donut chart of `category_counts` with total in center. Title: "Work Distribution". Below each chart: 1-sentence caption explaining the distribution. |
| 7 | **What's Next** | **Top half: Gantt-like horizontal bar chart** where each open PR is a row, bar width = scope, colored by repo. **Bottom half: 2-3 bullet descriptions** of the most important upcoming items and their expected impact. Title: "Coming Soon". **Skip if no open PRs.** |
| 8 | **Side Projects** | Only if personal activity exists. Brief section in MUTED: 2-3 sentences about personal repo activity. **Skip if no personal activity.** |

---

### Technical deck — `CWD/weekly-review-technical-YYYY-MM-DD.pptx` (max 25 slides)

| # | Slide | Content |
|---|-------|---------|
| 1 | **Title** | Title, author, sources, date range. |
| 2 | **Stats Dashboard** | **Full-slide visual dashboard.** Top row: 6 metric cards (2×3 grid) — big numbers, tiny labels. Bottom half: horizontal bar chart of commits-by-repo (sorted desc, ACCENT colored, bar labels). This is the "at a glance" slide. |
| 3 | **Commit Heatmap** | **Full-slide matplotlib chart.** Area chart of commits-by-date. Large, fills ~80% of slide. Clean axes, grid, date labels on x-axis. Title: "Commit Activity". |
| 4 | **Work Distribution** | **Two charts side-by-side, each ~45% of slide width.** Left: donut chart of `impact_areas` (ring, center = total PRs). Right: horizontal color-coded bar chart of `category_counts`. Title: "Where & What". |
| 5 | **Code Volume** | **Full-slide grouped bar chart.** For each repo: green bar (additions) up, red bar (deletions) beside it. Net change as annotation above each group. Title: "Code Volume". |
| 6 | **Architecture** | **Visual repo-relationship diagram** built with matplotlib. Each repo as a colored circle/node (size = commit count). Lines between repos if PRs reference both. Annotations with short description of cross-repo patterns. Fallback: if only 1 repo, just show a single labeled circle with key stats around it. **Skip if trivial.** |
| 7–N | **PR Detail slides** | **One slide per significant non-minor org PR. MAX 3 lines of text per slide.** Layout: Title (22pt, 1 line). One-sentence "what changed" (14pt, max 15 words). One-sentence "why" (14pt italic SUCCESS, max 15 words). Right side: colored category badge + impact area badge + merge date. If additions/deletions available: +/- badge. **If `screenshot_worthy` is true**: add a large gray dashed-border placeholder rectangle (60% of slide, centered) with text "Screenshot: {screenshot_hint}" in MUTED 14pt — this signals the presenter to paste an actual screenshot before presenting. **Cap at 15 slides.** |
| N+1 | **Minor & Personal** | **Combined into one compact slide.** Two sections: "Minor Changes" (small table: title, repo, category — max 5 rows). "Side Projects" (small table: title, repo, one-liner — max 5 rows). Tables use MUTED styling. **Skip if neither exists.** |
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

### 5c. Execute the script

```bash
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
Executive deck: /absolute/path/to/weekly-review-executive-YYYY-MM-DD.pptx
Technical deck: /absolute/path/to/weekly-review-technical-YYYY-MM-DD.pptx
```

Plus a brief content summary:
```
Covered N org PRs (F features, B bug fixes, I improvements) + P personal PRs across R repositories.
```

## Error handling

- **`gh` command failures:** Show the error message and ask the user how to proceed.
- **Python script failure:** Show the error, attempt to fix the script, retry once. If still failing, offer HTML fallback.
- **Missing `python-pptx`:** The `uv run --with` approach handles this. If both `uv` and `pip` fail, fall back to generating HTML presentation files.
- **Rate limiting from GitHub API:** Wait 5 seconds, retry once. If still rate-limited, report the issue and suggest narrowing the date range or specifying a single repo.
