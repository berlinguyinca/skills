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

Generate two PowerPoint presentations from GitHub activity: an executive deck (max 5 slides, plain English, no jargon) and a technical deck (max 30 slides, detailed, for IT staff).

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

### Resolve sources

1. If a positional argument was given, use it as the sole source for this run.
2. Otherwise, read `~/.config/gw-skills/weekly-review.json`. If the file exists and `sources` is non-empty, use all entries as sources.
3. If neither a positional argument nor a config file with sources exists, ask the user: "No source specified and no saved sources found. Provide an org or repo, or use `--add` to save one for future runs."

For each source, classify it: if it contains `/`, it's a **single-repo** source; otherwise it's an **org-wide** source.

Print the computed window for sanity check:
```
Reporting period: YYYY-MM-DD to YYYY-MM-DD
Sources:
  - metabolomics-us (org-wide)
  - berlinguyinca/personal-project (single repo)
```

## Step 2 — Verify prerequisites

Run these checks in parallel:

1. `gh auth status` — confirm GitHub CLI is authenticated
2. `which uv` — check availability (will fall back to `python3` if missing)
3. `gh api user --jq '.login'` — resolve `@me` to the actual GitHub username

If `gh auth status` fails, stop and tell the user to run `gh auth login`.

Print: `"Authenticated as USERNAME, querying ORG for Mon DD–Mon DD..."`

## Step 3 — Fetch GitHub data

All queries use `--json` for field selection and `--limit` for pagination.

**Run queries for ALL sources.** For each source in the resolved sources list, run the appropriate queries (org-wide or single-repo) in parallel across sources. Merge all results together, deduplicating by PR URL.

### 3a. Merged PRs in the reporting window

For each source:

**Org-wide source (no `/`):**
```bash
gh search prs --author=AUTHOR --owner=ORG --merged=">=$START_DATE" \
  --json title,repository,body,url,mergedAt,labels,additions,deletions,changedFiles --limit 200
```

**Single-repo source (contains `/`):**
```bash
gh pr list --repo ORG/REPO --state merged --search "merged:>=$START_DATE" \
  --json title,body,url,mergedAt,labels,additions,deletions,changedFiles --limit 200
```

Filter results to only include PRs merged on or before the `--to` date. Merge results from all sources.

### 3b. Open PRs (currently open, authored by user)

For each source:

**Org-wide source:**
```bash
gh search prs --author=AUTHOR --owner=ORG --state=open \
  --json title,repository,body,url,createdAt,labels,additions,deletions,changedFiles --limit 100
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
gh search commits --author=AUTHOR --owner=ORG --author-date=">=$START_DATE" \
  --json repository,sha --limit 500
```

For each single-repo source:
```bash
gh search commits --author=AUTHOR --repo=ORG/REPO --author-date=">=$START_DATE" \
  --json repository,sha --limit 500
```

Filter to commits on or before `--to` date. Merge and deduplicate by SHA. Count unique repos and total commits.

### 3d. Empty check

If zero merged PRs AND zero commits across ALL sources: print `"No GitHub activity found for AUTHOR across configured sources between START_DATE and END_DATE."` and stop gracefully.

Print summary:
```
Found N merged PRs, M open PRs, C commits across R repositories.
Sources queried: metabolomics-us, berlinguyinca/personal-project
```

## Step 4 — Categorize & synthesize content

Do this directly — do NOT spawn sub-agents. This is Claude's core analysis step.

### 4a. Categorize each PR

Use a tiered classification:
1. **GitHub labels first:** `bug` → Bug Fix, `enhancement`/`feature` → Feature, `documentation` → Docs, `dependencies` → Maintenance
2. **Title keywords fallback:** `fix`/`bug`/`error`/`patch` → Bug Fix, `add`/`new`/`feat`/`create` → Feature, `improve`/`update`/`refactor`/`optimize` → Improvement, `doc`/`readme` → Docs, `bump`/`dep`/`upgrade` → Maintenance
3. **Remainder** → Other

### 4b. Generate executive narrative

Transform developer PR titles into plain-English, user-facing language. Produce:

- **highlights**: 3-5 most impactful changes, described in terms of how they help the lab or end users
- **features_improvements**: new capabilities or improvements in plain English
- **bug_fixes**: what was broken and how it's now fixed, from a user perspective
- **coming_soon**: open PRs described as work in progress

**Rules:** No jargon, no code references, no file paths, no technical implementation details. Focus entirely on user/lab impact. Think of the audience as a lab director or program manager.

### 4c. Generate technical narrative

For each significant merged PR, produce:
- What changed and why
- Files/areas affected
- Technical category
- Additions/deletions stats

Also produce:
- **Overview stats:** total PRs, commits, repos touched, total lines added/deleted
- **Architecture notes:** if changes span multiple repos, describe the cross-repo patterns
- **Open PR technical status:** what's in progress and its technical state

## Step 5 — Write JSON handoff & generate presentations

### 5a. Write structured JSON

Write all content from Step 4 to `/tmp/weekly_review_data.json` with this structure:

```json
{
  "sources": ["metabolomics-us", "berlinguyinca/personal-project"],
  "author": "...",
  "start_date": "YYYY-MM-DD",
  "end_date": "YYYY-MM-DD",
  "executive": {
    "highlights": ["...", "..."],
    "features_improvements": ["...", "..."],
    "bug_fixes": ["...", "..."],
    "coming_soon": ["...", "..."]
  },
  "technical": {
    "stats": {
      "total_merged_prs": 0,
      "total_open_prs": 0,
      "total_commits": 0,
      "repos_touched": 0,
      "total_additions": 0,
      "total_deletions": 0
    },
    "commits_by_repo": {"repo_name": count, ...},
    "architecture_notes": "...",
    "prs": [
      {
        "title": "...",
        "repo": "...",
        "url": "...",
        "category": "Feature|Bug Fix|Improvement|Docs|Maintenance|Other",
        "what_changed": "...",
        "why": "...",
        "additions": 0,
        "deletions": 0,
        "merged_at": "...",
        "is_minor": false
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
    "category_counts": {"Feature": 0, "Bug Fix": 0, ...},
    "additions_by_repo": {"repo_name": 0, ...},
    "deletions_by_repo": {"repo_name": 0, ...}
  }
}
```

### 5b. Write Python script

Write a Python script to `/tmp/weekly_review_gen.py` that reads the JSON and generates both `.pptx` files.

**Theme (apply to both decks):**
- Background: white (`#FFFFFF`)
- Primary text: dark gray (`#333333`)
- Accent: soft blue (`#4A90D9`)
- Secondary accent: green (`#27AE60`)
- Font: Calibri throughout
- Slide dimensions: 16:9 widescreen (13.333" × 7.5")

**Defensive rules for the Python script:**
- Truncate titles to 80 characters max
- Truncate bullet text to 120 characters max
- Cap table rows at 10 per slide
- Use matplotlib with `Agg` backend (non-interactive) for all charts
- Access charts via `graphic_frame.chart` (not the return value of `add_chart()`)
- Save chart images to temp files and embed as images in slides
- Handle empty sections gracefully — skip slides that would have no content

**Executive deck** — save to `CWD/weekly-review-executive-YYYY-MM-DD.pptx` (max 5 slides):

| # | Slide | Content |
|---|-------|---------|
| 1 | Title | "Development Update", org name, date range subtitle |
| 2 | Highlights | 3-5 most impactful changes in plain English with blue accent bullets |
| 3 | New Features & Improvements | Bullet list of user-facing benefits. **Skip if empty.** |
| 4 | Bug Fixes & Reliability | What was fixed, how it helps users. **Skip if empty.** |
| 5 | Coming Soon | Open PRs described as upcoming work. **Skip if none.** |

**Technical deck** — save to `CWD/weekly-review-technical-YYYY-MM-DD.pptx` (max 30 slides):

| # | Slide | Content |
|---|-------|---------|
| 1 | Title | Full context: org, author, date range |
| 2 | Overview & Stats | Stats table (merged PRs, open PRs, commits, repos, lines +/-) + commits-by-repo bar chart as embedded image |
| 3 | Architecture Notes | Cross-repo patterns and observations. **Skip if not applicable.** |
| 4–N | Per-PR detail slides | One slide per significant (non-minor) merged PR: title, what changed, why, additions/deletions badge. Minor PRs grouped onto a single summary slide. Cap at ~20 individual PR slides. |
| N+1 | Open PRs | Table: title, repo, technical status. **Skip if none.** |
| N+2 | Activity Breakdown | Category pie chart + additions/deletions by repo bar chart, both as embedded images |
| Last | Links & References | PR URLs grouped by repo |

**Important Python implementation details:**
- Import `json`, `os`, `sys` at the top
- Use `from pptx import Presentation` and related imports from `python-pptx`
- Use `matplotlib`; set `matplotlib.use('Agg')` BEFORE importing `pyplot`
- For charts: save matplotlib figures to `/tmp/*.png`, then add as images to slides using `slide.shapes.add_picture()`
- Use `Inches`, `Pt`, `Emu` from `pptx.util` and `RGBColor` from `pptx.dml.color`
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
Covered N merged PRs (F features, B bug fixes, I improvements) and M open PRs across R repositories.
```

## Error handling

- **`gh` command failures:** Show the error message and ask the user how to proceed.
- **Python script failure:** Show the error, attempt to fix the script, retry once. If still failing, offer HTML fallback.
- **Missing `python-pptx`:** The `uv run --with` approach handles this. If both `uv` and `pip` fail, fall back to generating HTML presentation files.
- **Rate limiting from GitHub API:** Wait 5 seconds, retry once. If still rate-limited, report the issue and suggest narrowing the date range or specifying a single repo.
