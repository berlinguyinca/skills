# Analyze-App: PowerPoint Documentation & Skill Recommendations

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enhance `gw:review-app` with two new post-analysis steps: (1) generate a PowerPoint presentation summarizing findings and highlighting changes vs the default branch, saved to `doc/`, and (2) auto-detect which skills (superpowers, gw:, gsd:) would benefit the project, suggest them, and install on approval.

**Architecture:** Both features are new steps appended to the existing 7-step skill. Step 8 generates a `.pptx` presentation using the established python-pptx pattern (write script to `/tmp/`, execute with `uv run`). Step 9 scans the project for skill relevance signals (missing TDD, no E2E, no CI presentation workflow, etc.) and maps them to installable skills, offering to write CLAUDE.md recommendations or install gw-skills. Both steps use the JSON-handoff pattern from `gw:weekly-review` for clean data separation.

**Tech Stack:** python-pptx (via `uv run --with python-pptx`), git diff for change detection, Glob/Grep for skill signal detection

---

## File Map

| File | Action | Responsibility |
|------|--------|---------------|
| `.claude/commands/gw/review-app.md` | Modify (615 lines) | Add `--skip-pptx` / `--skip-recommend` flags, new Steps 8-9 |

Single file modification — all changes are markdown instructions within the skill file.

---

## Task 1: Add CLI Flags for New Steps

**Files:**
- Modify: `.claude/commands/gw/review-app.md:4` (argument-hint)
- Modify: `.claude/commands/gw/review-app.md:22-33` (argument parsing block — will become lines 22-35 after insertion)

- [ ] **Step 1: Read the current file to confirm exact strings**

Run: `head -35 .claude/commands/gw/review-app.md`
Verify the argument-hint line and parsing block match expectations after previous edits.

- [ ] **Step 2: Add `--skip-pptx` and `--skip-recommend` to the argument-hint frontmatter**

In the `argument-hint` line, append `[--skip-pptx] [--skip-recommend]` before the closing quote:

```
argument-hint: "[--skip-cloud] [--skip-gsd] [--skip-testing] [--skip-security] [--skip-seo] [--skip-test-review] [--skip-defaults] [--skip-fix] [--skip-pptx] [--skip-recommend] [--type web|server|cli|mobile|library|saas] [--scope full|recent|recent:N|timeframe:<spec>] [--team auto|ask|N]"
```

- [ ] **Step 3: Add flag parsing for both new flags**

After the `--skip-fix` parsing line, add:

```markdown
- If "--skip-pptx" is present, set SKIP_PPTX=true
- If "--skip-recommend" is present, set SKIP_RECOMMEND=true
```

- [ ] **Step 4: Commit**

```bash
git add .claude/commands/gw/review-app.md
git commit -m "feat(review-app): add --skip-pptx and --skip-recommend CLI flags"
```

---

## Task 2: Add Step 8 — Generate Findings Presentation

This step generates a PowerPoint deck summarizing the analysis findings and highlighting what changed vs the default branch. It follows the established pattern from `gw:merge-it` and `gw:weekly-review`.

**Files:**
- Modify: `.claude/commands/gw/review-app.md` (insert after Step 7, before EOF)

- [ ] **Step 1: Read the end of the file to find insertion point**

Read the last 20 lines to confirm Step 7 ends at the final line (currently ~line 615).

- [ ] **Step 2: Insert Step 8 after Step 7**

Append the following after the Step 7 block (after the final line of the file):

````markdown
---

## Step 8 — Generate Findings Presentation

Skip this step if SKIP_PPTX is true.

### 8a. Gather presentation data

1. Read `.analysis/REPORT.md` — extract Executive Summary, Scorecard, Priority 1-2 items, Compound Wins, Recommended Phases, and (if present) Fixes Applied section.
2. Detect the default branch: `git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@'` — fall back to `main` then `master`.
3. If on a non-default branch, run `git diff --stat {default_branch}...HEAD` to capture what changed compared to the default branch. Parse the diff stat into a list of: file path, lines added, lines removed.
4. If on the default branch (no diff), skip the "Changes vs Default Branch" slide — focus only on findings.

### 8b. Build JSON data file

Write a JSON file to `/tmp/review_app_presentation_data.json` with this schema:

```json
{
  "project_name": "{project name from Step 1}",
  "app_type": "{APP_TYPE}",
  "date": "{today's date}",
  "stack_summary": "{stack summary from STACK_CONTEXT}",
  "executive_summary": "{text from REPORT.md Executive Summary}",
  "scorecard": [
    { "dimension": "Security", "health": "Good", "critical": 0, "warnings": 2, "top_issue": "..." }
  ],
  "priority_1_items": [
    { "title": "...", "effort": "Quick Win", "dimensions": "Security, Architecture", "fixed": false }
  ],
  "priority_2_items": [
    { "title": "...", "effort": "Medium", "dimensions": "Testing", "fixed": true }
  ],
  "compound_wins": [
    { "title": "...", "improves": ["Security", "Performance"], "action": "..." }
  ],
  "phases": [
    { "name": "Phase 1: Critical Fixes", "effort": "S", "items": ["item1", "item2"] }
  ],
  "fixes_applied": {
    "total": 5,
    "passed": 4,
    "failed": 0,
    "reverted": 1
  },
  "branch_diff": {
    "has_diff": true,
    "default_branch": "main",
    "current_branch": "feat/analysis-fixes",
    "files_changed": 12,
    "insertions": 340,
    "deletions": 85,
    "file_stats": [
      { "file": "src/auth.ts", "added": 45, "removed": 12 }
    ]
  }
}
```

If no fixes were applied, set `fixes_applied` to `null`. If on the default branch, set `branch_diff.has_diff` to `false`. Cap `file_stats` to the top 10 files sorted by total churn (added + removed) to keep the JSON and slide manageable for large repos.

### 8c. Write and execute the Python presentation script

Write a Python script to `/tmp/review_app_presentation.py`. The script reads the JSON data file and generates a `.pptx` presentation.

**Design system** (matches `gw:weekly-review` palette — the canonical gw-skills design system. Note: `gw:merge-it` uses a slightly different palette; it should be aligned in a future update):

```
PRIMARY      = RGBColor(0x2C, 0x3E, 0x50)  # dark blue-gray — titles, headers
SECONDARY    = RGBColor(0x34, 0x49, 0x5E)  # medium blue-gray — body text
ACCENT       = RGBColor(0x34, 0x98, 0xDB)  # bright blue — highlights, KPIs
SUCCESS      = RGBColor(0x27, 0xAE, 0x60)  # green — good health, fixed items
DANGER       = RGBColor(0xE7, 0x4C, 0x3C)  # red — critical items
WARNING      = RGBColor(0xF3, 0x9C, 0x12)  # amber — warnings
MUTED        = RGBColor(0x95, 0xA5, 0xA6)  # gray — captions, labels
BG_WHITE     = RGBColor(0xFF, 0xFF, 0xFF)
BG_LIGHT     = RGBColor(0xF8, 0xF9, 0xFA)
```

- Font: Calibri throughout
- Slide dimensions: 16:9 widescreen (13.333" x 7.5")
- Title: 32pt bold PRIMARY
- Heading: 24pt bold PRIMARY
- Body: 14pt SECONDARY
- KPI Value: 36pt bold ACCENT
- KPI Label: 11pt uppercase MUTED
- Accent bar: 0.06" wide ACCENT strip at left edge of every slide

**Slide structure:**

1. **Title Slide** — Project name, "Application Analysis Report", date, app type badge, stack summary subtitle
2. **Executive Summary Slide** — Executive summary text in a card layout with the overall health verdict
3. **Scorecard Slide** — Table with dimension, health (color-coded: green/amber/red), critical count, warning count, top issue. Use colored rectangles as health indicators.
4. **Critical Issues Slide(s)** — Priority 1 items. Each item: title, effort badge (colored shape), dimensions, [FIXED] badge if applicable. If >5 items, split across multiple slides.
5. **Important Issues Slide** — Priority 2 items in condensed format (title + effort only). Mark [FIXED] items with green checkmark.
6. **Compound Wins Slide** — Each compound win: title, which dimensions improve (as colored badges), action summary.
7. **Changes vs Default Branch Slide** (only if `branch_diff.has_diff` is true) — Branch comparison header (current vs default), file change count, insertions/deletions as colored bars (green for added, red for removed), top 10 changed files as a mini table.
8. **Fix Summary Slide** (only if `fixes_applied` is not null) — Donut-style visual: passed (green), failed (red), reverted (amber). Issue count comparison: "X of Y critical issues resolved".
9. **Recommended Phases Slide** — Phase timeline as horizontal cards: Phase 1 → Phase 2 → Phase 3, each with T-shirt size effort badge and item count.
10. **Closing Slide** — "Full report: `.analysis/REPORT.md`", date, "Generated by gw:review-app"

**Script execution:**

```bash
mkdir -p doc
uv run --with python-pptx python /tmp/review_app_presentation.py
```

Fallback: `python3 -m pip install python-pptx && python3 /tmp/review_app_presentation.py`

If both fail, tell the user: "PowerPoint generation failed — python-pptx is required. Install it with `pip install python-pptx` or use `--skip-pptx` to skip presentation generation." Do not generate an HTML fallback.

**Output path:** `doc/analysis-report-{YYYY-MM-DD}.pptx` (consistent with `gw:merge-it` which uses `doc/` for generated presentations)

### 8d. Present result

Tell the user: "Presentation saved to `doc/analysis-report-{date}.pptx`"

If the project is a git repo with uncommitted changes to the presentation file, ask: "Commit the presentation to the branch? [y/n]"

If yes:
```bash
git add doc/analysis-report-*.pptx
git commit -m "docs: add analysis findings presentation"
```
````

- [ ] **Step 3: Verify the insertion is well-formed**

Read the file from Step 7 through the new Step 8 to verify markdown renders correctly and no step numbering gaps exist.

- [ ] **Step 4: Commit**

```bash
git add .claude/commands/gw/review-app.md
git commit -m "feat(review-app): add Step 8 — generate findings PowerPoint presentation"
```

---

## Task 3: Add Step 9 — Skill Recommendations & Auto-Install

This step analyzes the project and suggests which skills (superpowers, gw:, gsd:) would benefit it. It can auto-install skills the project needs.

**Files:**
- Modify: `.claude/commands/gw/review-app.md` (append after Step 8)

- [ ] **Step 1: Read the end of the file to confirm insertion point**

Verify Step 8 ends correctly and find the exact line to append after.

- [ ] **Step 2: Append Step 9 after Step 8**

````markdown
---

## Step 9 — Skill Recommendations & Auto-Install

Skip this step if SKIP_RECOMMEND is true.

### 9a. Detect skill relevance signals

Scan the project for signals that map to specific skills. Run these checks in parallel:

| Signal | Detection | Recommended Skill | Category |
|--------|-----------|-------------------|----------|
| No test-before-code git patterns | Git log analysis (same as coding-defaults enforcer) | `superpowers:test-driven-development` | Process |
| No E2E/Playwright tests | Missing playwright.config, no @playwright/test dep | `superpowers:test-driven-development` | Process |
| Complex multi-step task ahead (from Priority 1 items) | 3+ Priority 1 items with effort > Quick Win | `superpowers:writing-plans` | Process |
| Multiple independent subsystems | 3+ specialist dimensions flagged CRITICAL | `superpowers:dispatching-parallel-agents` | Process |
| Bug or failure patterns detected | Test failures, error patterns in logs | `superpowers:systematic-debugging` | Process |
| No PR review workflow | Missing `.github/CODEOWNERS`, no PR templates | `superpowers:requesting-code-review` | Process |
| Active feature branches | 2+ non-default branches | `superpowers:using-git-worktrees` | Process |
| No presentation/docs workflow | No `doc/` directory with `.pptx` files, no merge-it usage | `gw:merge-it` | Workflow |
| No periodic review | No weekly review config at `~/.config/gw-skills/weekly-review.json` | `gw:weekly-review` | Workflow |
| SaaS signals detected (from Step 1) | APP_TYPE = saas or SaaS signals present | `gw:saas-idea` | Workflow |
| No project planning | Missing `.planning/` directory | `gsd:new-project` | Planning |
| Existing GSD project with stale phases | `.planning/` exists but no recent phase activity | `gsd:progress` | Planning |
| No CI/CD pipeline | Missing `.github/workflows/`, `Jenkinsfile`, `.gitlab-ci.yml` | `superpowers:verification-before-completion` | Process |

### 9b. Check what's already available

1. Check which gw-skills are installed: `ls ~/.claude/commands/gw/ 2>/dev/null`
2. Check which GSD skills are installed: `ls ~/.claude/commands/gsd/ 2>/dev/null`
3. Check if superpowers are available: glob for `~/.claude/plugins/cache/claude-plugins-official/superpowers/` or check if any `superpowers:*` skills appear in the skill list. Superpowers are globally available when installed — they don't need per-project setup.
4. Read the project's `CLAUDE.md` if it exists — check if any skill references are already documented there

Filter out skills that are already installed or referenced in CLAUDE.md.

### 9c. Present recommendations

Display a recommendations table, grouped by category:

```
Recommended Skills for {project_name}:

Process Skills:
  1. [INSTALL] superpowers:test-driven-development
     Why: No TDD patterns detected, 3 test files have ceremonial assertions
  2. [AVAILABLE] superpowers:writing-plans
     Why: 5 Priority 1 items need coordinated implementation
  3. [INSTALL] superpowers:systematic-debugging
     Why: Test failures detected in 2 modules

Workflow Skills:
  4. [INSTALL] gw:merge-it
     Why: No presentation workflow — changes go undocumented
  5. [AVAILABLE] gw:weekly-review
     Why: Already installed, recommend configuring for this repo

Planning Skills:
  6. [INSTALL] gsd:new-project
     Why: No project planning structure detected

[INSTALL] = not yet referenced in project | [AVAILABLE] = installed but not used

Install all recommended [a], select by number [1,3,6], skip [s]?
```

- **[INSTALL]** means the skill exists in the user's environment but isn't referenced in the project's CLAUDE.md
- **[AVAILABLE]** means it's already referenced or the user already uses it

### 9d. Install selected skills

For skills the user approves:

**For superpowers skills:** These are already available globally. "Installing" means adding a reference to the project's `CLAUDE.md` so they're top-of-mind. Append to `CLAUDE.md` (create if it doesn't exist):

```markdown
## Recommended Skills

The following skills were identified by `gw:review-app` as beneficial for this project:

- `superpowers:test-driven-development` — Use TDD for all new features and bug fixes
- `superpowers:writing-plans` — Plan multi-step tasks before coding
- `superpowers:systematic-debugging` — Use scientific debugging for failures
```

**For gw: skills:** gw-skills is necessarily already installed (the user is running `gw:review-app`). Just add the recommended skill references to CLAUDE.md so they're discoverable for the project.

**For gsd: skills:** Check if GSD is installed (`~/.claude/commands/gsd/` exists).
- If yes: skills are already available, just add to CLAUDE.md recommendations.
- If not: tell the user: "GSD workflow tools are available at the GSD repository. Run `/gsd:help` for installation instructions."

### 9e. Configure thinking mode

If the project has complex architectural issues (3+ CRITICAL findings across different dimensions), suggest enabling extended thinking:

```
This project has complex cross-cutting issues. For best results when implementing fixes:
- Use extended thinking mode if available (model-dependent)
- Pair with superpowers:brainstorming before major architectural changes
- Use superpowers:writing-plans for multi-phase implementations
```

### 9f. Summary

Print a final summary:

```
Skills configured for {project_name}:
  - {N} skills recommended
  - {N} references added to CLAUDE.md
  - {N} already available (no action needed)

Next steps:
  - Run /gw:merge-it when ready to ship changes
  - Run /gsd:new-project to create a structured implementation plan
  - Use superpowers:test-driven-development for all new code
```
````

- [ ] **Step 3: Verify the full file renders correctly**

Read the complete file end-to-end. Verify:
- Step numbering: 0, 1, 1.5, 2, 3, 4, 5, 6, 7, 8, 9 (sequential, no gaps)
- All markdown tables render correctly
- No broken code blocks
- All step references are consistent (e.g., "continue to Step 6" in the fix phase still points correctly)

- [ ] **Step 4: Commit**

```bash
git add .claude/commands/gw/review-app.md
git commit -m "feat(review-app): add Step 9 — skill recommendations and auto-install"
```

---

## Task 4: Final Verification

- [ ] **Step 1: Read the complete modified file**

Read `.claude/commands/gw/review-app.md` from start to finish. Verify:
- Frontmatter argument-hint includes all 10 skip flags
- Argument parsing lists all 10 flag checks
- Steps are numbered: 0 → 1 → 1.5 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9
- All cross-references (e.g., "continue to Step 6" in Step 5c) are correct
- No duplicate content between new steps and existing specialist prompts
- File is well-formed markdown throughout

- [ ] **Step 2: Count lines and verify reasonable size**

Run: `wc -l .claude/commands/gw/review-app.md`
Expected: ~800-870 lines (615 current + ~200-250 for two new steps)

- [ ] **Step 3: Final commit (if any cleanup was needed)**

```bash
git add .claude/commands/gw/review-app.md
git commit -m "fix(review-app): final cleanup and cross-reference verification"
```
