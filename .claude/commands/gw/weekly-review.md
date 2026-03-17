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
2. Otherwise, read `~/.config/gw-skills/weekly-review.json`. If the file exists and `sources` is non-empty, use all entries as sources.
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
- **highlights**: 3-5 most impactful org changes in plain English, focused on user/lab impact
- **features_improvements**: org features and improvements, plain English
- **bug_fixes**: org bug fixes — what was broken, how it's fixed, from user perspective
- **coming_soon**: org open PRs described as upcoming work
- **side_projects**: 1-3 sentence summary of personal repo activity (if any). Keep it very brief, e.g. "Also shipped 4 updates to ai-sync (config sync tool) including multi-environment support."

**Rules:** No jargon, no code references, no file paths, no technical implementation details in the executive deck. Focus entirely on user/lab impact. Think of the audience as a lab director or program manager. Organization work is the main story.

### 4d. Generate technical narrative (org-first)

**Organization PRs get individual slides. Personal PRs are grouped onto one summary slide.**

For each significant org merged PR, produce:
- What changed and why (2-3 sentences)
- Technical impact area (e.g. "Queue Management", "Data Pipeline", "API", "Infrastructure")
- Technical category (Feature/Bug Fix/etc.)
- Additions/deletions stats (if available)

For personal PRs, produce a single grouped summary with repo name, PR count, and 1-line description per PR.

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
    "highlights": ["...", "..."],
    "features_improvements": ["...", "..."],
    "bug_fixes": ["...", "..."],
    "coming_soon": ["...", "..."],
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
        "is_minor": false
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

### Executive deck — `CWD/weekly-review-executive-YYYY-MM-DD.pptx` (max 8 slides)

| # | Slide | Layout | Content |
|---|-------|--------|---------|
| 1 | **Title** | Centered | Large title "Development Update", org name(s) below, date range, subtle accent bar at bottom |
| 2 | **KPI Dashboard** | 4-column card layout | Four metric cards in a row (from `kpi_cards`), each card is a rounded-corner rectangle with large number on top + label below. Below the cards: the `headline` as a subtitle sentence. |
| 3 | **Activity Timeline** | Chart + caption | Matplotlib area chart of commits-by-date (x=dates, y=commit count, filled area in ACCENT with alpha=0.3). Caption below: total commits and repos. If only 1-2 dates have data, use a bar chart instead. |
| 4 | **Highlights** | Bullet list with icons | 3-5 most impactful org changes. Each bullet prefixed with a colored "●" (ACCENT). Large text, generous spacing. This is the slide people read. |
| 5 | **New Features & Improvements** | Two-column layout | Left column: feature bullets (SUCCESS colored dots). Right column: improvement bullets (ACCENT colored dots). **Skip if empty.** |
| 6 | **Bug Fixes & Reliability** | Bullet list | What was fixed, user impact. DANGER colored dots. **Skip if empty.** |
| 7 | **Coming Soon** | Bullet list with WARNING dots | Open PRs described as upcoming org work. **Skip if no org open PRs.** |
| 8 | **Side Projects** | Brief summary | Only if personal repo activity exists. Gray-toned slide. 1-3 sentences about personal repos. A subtle "Also this week..." framing. **Skip if no personal activity.** |

---

### Technical deck — `CWD/weekly-review-technical-YYYY-MM-DD.pptx` (max 30 slides)

| # | Slide | Layout | Content |
|---|-------|--------|---------|
| 1 | **Title** | Full context | Title, author, sources, date range. Clean, informational. |
| 2 | **Stats Dashboard** | 2×3 grid of metric cards + chart | Six stat cards (org PRs, org commits, org repos, personal PRs, total additions, total deletions) arranged in 2 rows of 3. Each card: large value + small label. Below or beside: horizontal bar chart of commits-by-repo (sorted descending, ACCENT colored). |
| 3 | **Activity Timeline** | Stacked area or multi-line chart | Commits-by-date as area chart. If data allows, break down by repo (stacked areas, one color per repo with legend). X-axis = dates, Y-axis = commits. Title: "Commit Activity". |
| 4 | **Impact Areas** | Donut chart + legend | Donut/ring chart of `impact_areas` (center shows total PR count). Legend on the right with area name + count. Title: "Work Distribution by Area". Uses distinct colors from the palette. **Skip if only 1 area.** |
| 5 | **Category Breakdown** | Horizontal bar chart | Horizontal bars for category_counts (Feature, Bug Fix, Improvement, Docs, Maintenance). Color-coded: Feature=ACCENT, Bug Fix=DANGER, Improvement=SUCCESS, Docs=WARNING, Maintenance=MUTED. Each bar labeled with count. Title: "PR Categories". |
| 6 | **Architecture Notes** | Text with diagram-like layout | Architecture narrative as clean text. If changes span repos, show a simple flow: colored boxes for each repo with arrow connections described in text. **Skip if not applicable.** |
| 7–N | **Org PR Detail slides** | Two-panel layout | **One slide per significant (non-minor) org merged PR.** Layout: Top: PR title (HEADING) + repo badge (MUTED small text) + category pill (colored rounded rect). Body left (60%): "What changed" paragraph + "Why" paragraph (in SUCCESS). Body right (40%): stats card showing +additions/-deletions (if available), impact area badge, merged date. Minor org PRs grouped onto a single "Minor Changes" slide with compact bullets. **Cap at 20 individual slides.** |
| N+1 | **Personal Projects** | Compact grouped slide | Gray-toned header "Side Projects". Table or compact list: repo name, PR count, 1-liner per PR. De-emphasized styling (MUTED colors, smaller text). **Skip if no personal PRs.** |
| N+2 | **Open PRs — In Progress** | Card-per-PR layout | Each open org PR as a card: title, repo, status summary. Cards arranged in 2-column grid. **Skip if none.** |
| N+3 | **Code Volume** | Waterfall or grouped bar chart | Additions vs deletions by repo. Green bars up (additions), red bars down (deletions). Net change labeled. Title: "Code Volume by Repository". Only show repos with changes. |
| Last | **Links & References** | Grouped URL list | PR URLs grouped by repo. Repo name as blue header, PR title + URL as muted text below. Compact layout, small font. |

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
