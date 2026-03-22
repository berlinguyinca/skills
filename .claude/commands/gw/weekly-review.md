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

- **The problem statement** — what was broken, slow, or missing before this change?
- **The solution impact** — what's different now for users/operators?
- **Quantitative evidence** — test counts, performance numbers, coverage percentages, capacity limits, timeout values.
- **New tools or commands introduced** — CLI commands, API endpoints, config flags, TUI interfaces.
- **Test plan results** — checked boxes (`[x]`) indicate verified work vs unchecked (`[ ]`) pending validation.

Store these extracted details in a `context` field per PR for use in Step 4.

**For org-wide sources**, the `body` field is already included in `gh search prs`. For single-repo sources, it's in `gh pr list`. No additional API calls needed.

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

```bash
gh api "repos/ORG/REPO/commits?since=START_DATET00:00:00Z&until=END_DATET23:59:59Z&per_page=50" \
  --jq '[.[].sha] | join("\n")' | head -10 | while read SHA; do
  gh api "repos/ORG/REPO/commits/$SHA" --jq '.files[]? | select(.filename | endswith(".pptx")) | .filename' 2>/dev/null
done | sort -u
```

**Rate limit guard:** Cap at 10 commits per repo. If `gh api` returns a 403/429, stop scanning that repo and continue with others.

**For single-repo sources**, also check repo root and `docs/gw/`:
```bash
gh api "repos/ORG/REPO/contents/" --jq '.[]? | select(.name | endswith(".pptx")) | .name'
gh api "repos/ORG/REPO/contents/docs/gw" --jq '.[]? | select(.name | endswith(".pptx")) | .name' 2>/dev/null
```

**For each discovered `.pptx` file:**

1. Download to `/tmp/`:
   ```bash
   gh api "repos/ORG/REPO/contents/PATH" --jq '.download_url' | xargs curl -sL -o /tmp/FILENAME
   ```

2. Extract assets using Python (`python-pptx`): iterate slides, extract embedded images via `shape.image` → save as `/tmp/harvested_REPO_slideN_imgM.png`. Extract slide titles and text. Record metadata: `{"source_repo", "source_file", "slide_index", "slide_title", "images", "text_preview"}`.

3. Filter for relevance: keep charts, screenshots of tools/UIs/CLI output. Discard generic title slides, blank backgrounds, tiny icons.

Store harvested assets in the JSON per schema in `$GW_REPO/.claude/commands/gw/_shared/weekly-json-schema.md`.

**Integration rules for the generated deck:**
- If a harvested asset's `related_pr_url` matches a PR slide: embed harvested image instead of screenshot placeholder (50-60% of slide).
- If harvested assets contain before/after comparisons relevant to an executive theme: use as visual anchor.
- If 3+ assets harvested: create "Visuals from PRs" slide in technical deck with 2×2 or 3×2 grid, repo + slide title as caption.
- If no `.pptx` files found: skip silently.

## Step 4 — Categorize & synthesize content

Do this directly — do NOT spawn sub-agents. This is Claude's core analysis step.

### 4a. Classify source priority

Tag every PR and commit: `"org"` (organization repos, featured prominently) or `"personal"` (user's own repos, mentioned briefly).

### 4b. Categorize each PR

Use a tiered classification:
1. **GitHub labels first:** `bug` → Bug Fix, `enhancement`/`feature` → Feature, `documentation` → Docs, `dependencies` → Maintenance
2. **Title keywords fallback:** `fix`/`bug`/`error`/`patch` → Bug Fix, `add`/`new`/`feat`/`create` → Feature, `improve`/`update`/`refactor`/`optimize` → Improvement, `doc`/`readme` → Docs, `bump`/`dep`/`upgrade` → Maintenance
3. **Remainder** → Other

### 4c. Generate executive narrative (org-first, theme-based)

**Organization work dominates the narrative.** Personal repos get a brief mention at most.

**Use the PR body context extracted in Step 3a-ii to build a top-down, theme-based narrative** — not a list of PRs.

#### Theme Synthesis

Read all merged PR data and identify **2-3 natural themes** — clusters of related work that tell a coherent story together. Themes emerge from the data; they are NOT predetermined categories.

Always produce exactly 2 themes. Add a 3rd only when the data clearly supports 3 distinct stories. Never exceed 3.

#### Headline Generation

Write one bold sentence capturing the week's most impactful story. Use specific numbers from PR bodies when available.

- BAD: "Several improvements to the processing pipeline"
- GOOD: "Sample processing got dramatically faster — auto-recovery, smarter scheduling, and a 1000x query speedup"

#### Produce the JSON structure specified in:

Read and follow `$GW_REPO/.claude/commands/gw/_shared/weekly-json-schema.md` for the full JSON data structure.

Key content rules:
- **KPI values are OUTCOMES with real numbers** — NOT activity counts ("12 PRs", "7 features" are meaningless to a lab director)
- Always 3 KPI cards. If only 2 strong quantitative outcomes exist, the 3rd can be qualitative.
- Each theme: 2-3 evidence items, each with bold `claim` (max 10 words) and gray `detail` (max 25 words) with specific numbers.
- `whats_next`: max 4 items from open PRs, title max 8 words, detail max 10 words.
- `side_projects`: 1-2 sentences about personal repo activity, or empty string.
- **No jargon, no code references, no file paths.** Every claim must cite specific evidence from PR descriptions.

### 4d. Generate technical narrative (org-first)

**Organization PRs get individual slides. Personal PRs are grouped onto one compact table.**

For each significant org merged PR, produce:
- **what_changed**: MAX 15 WORDS. One sentence.
- **why**: MAX 15 WORDS. One sentence.
- Technical impact area (e.g. "Queue Management", "Data Pipeline", "API", "Infrastructure")
- Technical category (Feature/Bug Fix/etc.)
- Additions/deletions stats (if available)
- **screenshot_worthy**: boolean — true if the PR introduces a visible tool, UI, CLI output, report, dashboard, or API endpoint.

For personal PRs, produce a single grouped summary with repo name, PR count, and 1-line (max 8 words) description per PR.

Also produce:
- **Overview stats** split by org vs personal
- **commits_by_repo**, **commits_by_date**, **category_counts**, **impact_areas**
- **Architecture notes:** cross-repo patterns within the org
- **Open PR technical status:** org open PRs only
- **Deep-dive data for highlights:** For each highlight from Step 4e (max 3): `title`, `problem` (2-3 sentences), `approach` (2-3 sentences), `result` (2-3 sentences), `visual_anchor`, `screenshot_hint`

### 4e. Spotlight prompt loop

After Step 4d analysis completes, pause and ask:

> "Before I generate the slides — is there any work from this week you're especially proud of and want to spotlight? Describe it briefly and I'll feature it prominently."

**Interaction loop:**

1. User describes something → Claude matches it to one or more merged PRs from the fetched data
2. Claude confirms: "Got it — I'll spotlight [matched PR title]. Anything else?"
3. Loop continues until user says "no", "done", "stop", or similar
4. If user says "skip" or "none" on the first ask, proceed with no highlights

Store highlights array per schema. If no highlights were provided, set `highlights` to `[]` and proceed. After collecting highlights, finalize the Step 4d deep-dive data before proceeding to Step 4f.

### 4f. "What I Learned" prompt

After spotlights, ask:

> "One more thing — what's something you learned this week? A technique, tool insight, debugging lesson, or interesting discovery. I'll create a visual for it."

**Interaction:**

1. User describes a learning → Claude distills it into a learning object
2. Claude confirms: "Got it — I'll visualize that. Anything else you learned?"
3. Loop continues until user says "no", "done", or similar (max 3 learnings)
4. If user says "skip" or "none" on the first ask, proceed with no learnings

Store as a `learnings` array per schema. If empty, set to `[]`.

## Step 5 — Write JSON handoff & generate presentations

### 5a. Write structured JSON

Read and follow `$GW_REPO/.claude/commands/gw/_shared/weekly-json-schema.md` for the complete JSON structure.

Write all content from Step 4 to `/tmp/weekly_review_data.json`.

### 5b. Write Python script

Read and follow `$GW_REPO/.claude/commands/gw/_shared/weekly-pptx-slides.md` for:
- Executive deck slide specifications (5-9 slides)
- Technical deck slide specifications (max 25 slides)
- Visual anchor rendering patterns
- Python script generation pattern and defensive rules

Write the complete Python script to `/tmp/weekly_review_gen.py` that reads the JSON and generates both `.pptx` files.

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

Read and follow `$GW_REPO/.claude/commands/gw/_shared/session-summary.md`.

---

## Error handling

- **`gh` command failures:** Show the error message and ask the user how to proceed.
- **Python script failure:** Show the error, attempt to fix the script, retry once. If still failing, offer HTML fallback.
- **Missing `python-pptx`:** The `uv run --with` approach handles this. If both `uv` and `pip` fail, fall back to generating HTML presentation files.
- **Rate limiting from GitHub API:** Wait 5 seconds, retry once. If still rate-limited, report the issue and suggest narrowing the date range or specifying a single repo.
