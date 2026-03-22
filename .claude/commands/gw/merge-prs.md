---
name: merge-prs
description: Discover, review, and integrate all agent_merge-labeled PRs into a single integration branch with AI-assisted conflict resolution
argument-hint: "[--dry-run] [--label <label>] [--skip-tests] [--base <branch>]"
---

## Step 0 — Preamble

Resolve the gw-skills repo path, then read and follow `$GW_REPO/.claude/commands/gw/_shared/preamble.md` for update check and GSD project detection:

```bash
GW_REPO="$(cd "$(readlink ~/.claude/commands/gw)/../../.." 2>/dev/null && pwd)" || GW_REPO="$HOME/.gw-skills"
```

GW_REPO persists for the duration of this skill run — do not re-resolve it in later steps.

NOTE: This skill does NOT use `_shared/branch-first.md` — it manages its own integration branches.

---

## Step 1 — Parse Arguments

You are an orchestrator for integrating multiple agent-created PRs into a single integration branch. You discover PRs by label, analyze their intent, merge them with AI-assisted conflict resolution, and create a master integration PR. Follow these steps precisely.

Parse the arguments: "$ARGUMENTS"

| Flag | Variable | Default | Notes |
|------|----------|---------|-------|
| `--dry-run` | DRY_RUN | false | List PRs without merging |
| `--label <label>` | PR_LABEL | `agent_merge` | Override the label to filter by |
| `--skip-tests` | SKIP_TESTS | false | Skip test runs after each merge |
| `--base <branch>` | BASE_BRANCH | auto-detect | Base branch for integration |

---

## Step 2 — Pre-flight Checks

### 2a: GitHub CLI authentication

```bash
gh auth status 2>/dev/null
```

If not authenticated: "GitHub CLI not authenticated. Run `gh auth login`." and **stop**.

### 2b: Detect base branch

If `BASE_BRANCH` not set via `--base`:

```bash
BASE_BRANCH=$(git remote show origin 2>/dev/null | grep 'HEAD branch' | awk '{print $NF}')
```

Fall back to `main` if detection fails. Verify the branch exists:

```bash
git rev-parse --verify "origin/${BASE_BRANCH}" 2>/dev/null
```

### 2c: Ensure we are on a clean state

```bash
git status --porcelain
```

If dirty: "Working directory has uncommitted changes. Please commit or stash first." and **stop**.

---

## Step 3 — Discover agent_merge PRs

```bash
gh pr list --label "${PR_LABEL}" --state open \
  --json number,title,headRefName,body,createdAt,additions,deletions,files \
  --limit 100
```

If no PRs found: "No open PRs with label '${PR_LABEL}'. Nothing to merge." and **stop**.

Present discovered PRs:

```
Found N PRs with label "${PR_LABEL}":

| # | PR   | Branch                          | Created    | +/-       | Title                                |
|---|------|---------------------------------|------------|-----------|--------------------------------------|
| 1 | #42  | gw/research/20260321-a1b2       | 2026-03-21 | +150/-20  | gw:research — Market analysis        |
| 2 | #43  | gw/review-app/20260321-c3d4     | 2026-03-21 | +80/-15   | gw:review-app — Security fixes       |
| 3 | #44  | gw/compete/20260321-e5f6        | 2026-03-21 | +200/-30  | gw:compete — Feature additions       |
```

If `DRY_RUN` is true: print the table and **stop**.

---

## Step 4 — Analyze PR Intent

For each PR:

### 4a: Read intent file

Fetch `.gw-intent.md` from the PR branch:

```bash
gh pr diff <number> --name-only
```

If `.gw-intent.md` is in the diff, read its contents from the PR branch:

```bash
git fetch origin <pr-branch>
git show origin/<pr-branch>:.gw-intent.md 2>/dev/null
```

### 4b: Extract PR body intent

Parse the PR body for the Purpose and Key Decisions sections.

### 4c: Assess file overlap

For each pair of PRs, compare their changed file lists:

```bash
gh pr diff <number> --name-only
```

Classify overlap:
- **None**: no shared files → low conflict risk
- **Low**: shared files but different sections likely (e.g., README, config)
- **Medium**: shared source files → potential conflicts
- **High**: same source files with significant overlap → likely conflicts

### 4d: Build intent summary

For each PR, produce:

```
PR #<number> — <title>
  Intent: <from .gw-intent.md or PR body>
  Scope: <N files changed — categories: source, test, config, docs>
  Conflict risk: <low/medium/high> with <list of overlapping PRs>
  Dependencies: <from .gw-intent.md or "none detected">
```

---

## Step 5 — Determine Merge Order

### 5a: Build ordered merge plan

Priority rules:
1. PRs with explicit dependencies go after their dependencies
2. PRs with no file overlap with remaining PRs → first (lowest conflict risk)
3. Smaller PRs (fewer total line changes) → first
4. Oldest PRs (by `createdAt`) → first (tiebreaker)

### 5b: Present merge plan

```
Merge plan (N PRs):

  1. PR #43 (gw:review-app) — 95 lines, no overlap — Security fixes
  2. PR #42 (gw:research)   — 170 lines, low overlap — Market analysis
  3. PR #44 (gw:compete)    — 230 lines, medium overlap — Feature additions

Overlap warnings:
  - PR #42 and #44 both touch src/config.ts

Confirm order [y], reorder [r], exclude PRs [x], or cancel [c]?
```

Wait for user input:
- `y` → proceed
- `r` → ask for custom order (PR numbers)
- `x` → ask which PRs to exclude, then re-present plan
- `c` → abort

---

## Step 6 — Create Integration Branch

### 6a: Generate branch name

```bash
SHORT_ID=$(date +%Y%m%d)-$(head -c 4 /dev/urandom | xxd -p | head -c 4)
INTEGRATION_BRANCH="gw/integration/${SHORT_ID}"
```

### 6b: Create worktree or branch

Prefer worktree for isolation:

```bash
# Check if .worktrees/ exists or can be created
if [ -d ".worktrees" ] || mkdir -p .worktrees 2>/dev/null; then
  git worktree add .worktrees/integration -b "${INTEGRATION_BRANCH}" "origin/${BASE_BRANCH}"
  WORK_DIR=".worktrees/integration"
  USING_WORKTREE=true
fi
```

If worktree creation fails, fall back to regular branch:

```bash
git fetch origin "${BASE_BRANCH}"
git checkout -b "${INTEGRATION_BRANCH}" "origin/${BASE_BRANCH}"
WORK_DIR="."
USING_WORKTREE=false
```

Ensure `.worktrees/` is in `.gitignore` if using worktree.

---

## Step 7 — Merge PRs One by One

For each PR in the confirmed order:

### 7a: Fetch and merge

```bash
cd "${WORK_DIR}"
git fetch origin <pr-branch>
git merge origin/<pr-branch> --no-edit -m "Merge PR #<number>: <title>"
```

### 7b: Handle merge conflicts — AI-assisted resolution

If the merge has conflicts:

1. **List conflicting files:**
   ```bash
   git diff --name-only --diff-filter=U
   ```

2. **Read intent from both sides:**
   - Read `.gw-intent.md` from the conflicting PR branch (fetched in Step 4a)
   - Read the current integration state's accumulated intent from previously merged PRs

3. **Analyze each conflicting file:**
   - Read the conflict markers in each file
   - Compare with the intent of both sides:
     - What was each PR trying to accomplish in this file?
     - Are the changes complementary (both adding different things) or contradictory (both modifying the same logic)?

4. **Attempt resolution:**
   - **Complementary changes** (both adding to different sections, both adding different imports, etc.): Keep both additions in logical order
   - **Contradictory changes** (both modifying the same function/line): Use intent files to determine which change aligns with its stated purpose. If one PR's change is a superset of the other, keep the superset. If truly contradictory, prefer the PR that was ordered earlier (lower conflict risk assessment)
   - **Config/dependency conflicts** (both modifying package.json, config files): Merge both dependency additions; for conflicting config values, prefer the more recent PR's values

5. **If resolution succeeds:**
   ```bash
   git add <resolved-files>
   git commit --no-edit -m "Merge PR #<number>: <title>

   Auto-resolved conflicts using intent files:
   - <file1>: kept complementary additions from both PRs
   - <file2>: preferred PR #<N>'s change (aligned with stated intent)"
   ```

6. **If resolution is uncertain** (cannot confidently determine correct resolution):
   ```bash
   git merge --abort
   ```
   Ask user: **"Merge conflict in PR #\<number\> — cannot auto-resolve confidently."**
   - `[s]` Skip this PR, continue with remaining
   - `[m]` Show conflict details — user provides resolution guidance
   - `[a]` Abort entire integration

   If `[m]`: show the conflicting hunks, both intents, and ask the user which resolution to apply. Apply their guidance, then continue.

### 7c: Run tests (unless --skip-tests)

If `SKIP_TESTS` is false:

Detect and run the test suite following `$GW_REPO/.claude/commands/gw/_shared/test-runner.md`.

If tests fail:
- Identify likely cause: which PR's files correlate with the failing tests
- Ask user:
  - `[r]` Revert this PR: `git revert -m 1 HEAD` — undo the merge, skip this PR
  - `[i]` Investigate: show test output, let user decide
  - `[c]` Continue anyway (risky — noted in final report)
  - `[a]` Abort entire integration

### 7d: Log progress

After each successful merge:

```
[N/total] Merged PR #<number> (<title>)
  Files: +<additions>/-<deletions>
  Conflicts: <none | auto-resolved N files>
  Tests: <pass | fail | skipped>
```

---

## Step 8 — Create Master Integration PR

### 8a: Push integration branch

```bash
cd "${WORK_DIR}"
git push -u origin "${INTEGRATION_BRANCH}"
```

### 8b: Build comprehensive PR body

Compile a summary of all merged PRs:

```markdown
## Integration Summary

**Branch:** <INTEGRATION_BRANCH>
**Base:** <BASE_BRANCH>
**PRs integrated:** N/M
**Date:** <ISO-8601>

### Merged PRs

| # | PR | Branch | Skill | Conflicts | Tests | Status |
|---|-----|--------|-------|-----------|-------|--------|
| 1 | #43 | gw/review-app/... | review-app | none | pass | merged |
| 2 | #42 | gw/research/... | research | 1 auto-resolved | pass | merged |
| 3 | #44 | gw/compete/... | compete | none | pass | merged |

### Skipped PRs
<list any skipped PRs with reasons, or "None">

### Conflict Resolution Log
<details of any auto-resolved conflicts: which files, what strategy, which intent was preferred>

### Test Results
- Tests after final merge: <pass/fail count>
- Test failures introduced: <none or details>

### Individual PR Intents
<For each merged PR, include a condensed version of its .gw-intent.md Purpose section>

---
*Generated by `/gw:merge-prs`*
```

### 8c: Create the PR

```bash
gh pr create \
  --base "${BASE_BRANCH}" \
  --title "Integration: ${MERGED_COUNT} agent PRs merged (${SHORT_ID})" \
  --body "<compiled body from 8b>"
```

Do NOT add the `agent_merge` label to the integration PR — it is not an agent PR itself.

Capture the integration PR URL.

---

## Step 9 — Cleanup

### 9a: Offer to close individual PRs

Ask: "Close the N individual agent_merge PRs now that they're included in the integration PR? [y/n]"

If yes, for each merged PR:
```bash
gh pr close <number> --comment "Included in integration PR #<integration-pr-number>. Branch: ${INTEGRATION_BRANCH}"
```

Leave skipped PRs open — they were not integrated.

### 9b: Clean up worktree

If `USING_WORKTREE` is true:
```bash
cd <original-directory>
git worktree remove .worktrees/integration 2>/dev/null
git worktree prune
```

### 9c: Return to original branch

```bash
git checkout "${BASE_BRANCH}"
```

---

## Step 10 — Final Report

```
Integration complete:
  Integration PR: #<number> (<url>)
  PRs merged:     N/M
  PRs skipped:    K <reasons if any>
  Conflicts:      C auto-resolved, D manual/skipped
  Tests:          <final status>

Next steps:
  - Review the integration PR: <url>
  - Run CI on the integration branch
  - Merge via /gw:merge-it or: gh pr merge <number>
```

---

## Session Summary

| Output | Location |
|--------|----------|
| Integration PR | GitHub PR #\<number\> |
| Integration branch | `${INTEGRATION_BRANCH}` |
| Closed PRs | #\<list\> (if user chose to close) |

Skipped outputs: <list any skipped steps with reasons>
