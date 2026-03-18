---
name: merge-it
description: Ship the current changes end-to-end: branch, PR, review, fix, present, merge
argument-hint: "[--skip-presentation] [--skip-review] [--squash|--rebase] [--draft] [--reviewers <user,...>] [--labels <label,...>] [--base <branch>]"
---

## Step 0 — Update check

Resolve the gw-skills repo directory and run its update check script:

```bash
GW_REPO="$(cd "$(readlink ~/.claude/commands/gw)/../../.." 2>/dev/null && pwd)" || GW_REPO="$HOME/.gw-skills"
bash "$GW_REPO/check-update.sh" 2>/dev/null || true
```

If the output contains `UPDATE_AVAILABLE`, tell the user how many commits behind they are and ask: "gw-skills has updates available. Run /gw:update to install them, or continue?" If they want to update, invoke `/gw:update` and stop. Otherwise continue. If the script is missing or fails, skip silently.

---

## Parse arguments

Parse the arguments: "$ARGUMENTS"

- If `--skip-presentation` is present, set SKIP_PPTX=true
- If `--skip-review` is present, set SKIP_REVIEW=true
- If `--squash` is present, set MERGE_STRATEGY="squash"
- If `--rebase` is present, set MERGE_STRATEGY="rebase"
- If neither `--squash` nor `--rebase` is present, set MERGE_STRATEGY="merge" (default)
- If `--draft` is present, set DRAFT_PR=true
- If `--reviewers <list>` is present, set REVIEWERS=<comma-separated list>
- If `--labels <list>` is present, set LABELS=<comma-separated list>
- If `--base <branch>` is present, set BASE_BRANCH=<branch> (overrides auto-detection)

If conflicting flags are given (`--squash` and `--rebase` together), warn the user and ask which they prefer.

## Workflow routing

Based on arguments and detected state, the workflow may skip steps:

| Condition | Steps executed |
|-----------|---------------|
| Default (no flags) | 0 → 1 → 2 → 3 → 4 → 5 → 6 → 7a → 7b → 7c → 8 |
| `--skip-review` | 0 → 1 → 2 → 3 → 7b → 7c → 8 |
| `--skip-presentation` | 0 → 1 → 2 → 3 → 4 → 5 → 6 → 7a → 7c → 8 |
| `--skip-review --skip-presentation` | 0 → 1 → 2 → 3 → 7c → 8 |
| Already on feature branch with PR | 0 → 4 → 5 → 6 → 7a → 7b → 7c → 8 |
| Already on feature branch, no PR | 0 → 2 → 3 → 4 → 5 → 6 → 7a → 7b → 7c → 8 |

---

Ship the current changes end-to-end: branch, PR, review, fix, present, merge.

Follow these steps IN ORDER. Do not skip steps or proceed past approval gates without explicit user confirmation (unless the routing table above indicates a step should be skipped based on flags or detected state).

## Pre-flight checks

Before starting the workflow, verify the environment:

1. Run `gh auth status` to confirm GitHub CLI is authenticated. If it fails, stop and tell the user to run `gh auth login`.
2. Check if there are any staged or unstaged changes (`git status --porcelain`). If the output is empty AND we're on the default branch, tell the user: "No changes detected. Stage or modify files first." and stop.
3. Check if the user is already on a non-default feature branch with commits ahead of the default branch:
   - Run `git log <default-branch>..HEAD --oneline` to see if there are commits
   - If yes, ask the user: "You're already on branch `<current-branch>` with N commits ahead of `<default-branch>`. Continue from here (skip to Step 2), or start fresh?"
   - If they continue, skip Step 1 and proceed to Step 2
4. Check if there's already an open PR for the current branch:
   - Run `gh pr view --json number,url,state 2>/dev/null`
   - If a PR exists and is open, ask the user: "PR #N already exists for this branch (<url>). Resume the review/merge workflow from Step 4?"
   - If they confirm, skip to Step 4

### Step 1: Create a branch

- Determine a descriptive branch name from the staged/unstaged changes (e.g., `fix/path-rewriter-escaping` or `feat/auto-update`)
- Run: `git checkout -b <branch-name>`
- Stage and commit all relevant changes with a clear commit message
- If the commit fails (e.g., pre-commit hook rejects it), show the error and ask how to proceed — do NOT force past hooks

### Step 2: Push the branch

- Run: `git push -u origin <branch-name>`

### Step 3: Create a PR

- Determine the base branch:
  1. If BASE_BRANCH was set via `--base`, use it
  2. Otherwise, detect the default branch using `git remote show origin | grep 'HEAD branch' | awk '{print $NF}'`
  3. If that fails, fall back to checking if `main` or `master` exists locally: `git rev-parse --verify main 2>/dev/null || git rev-parse --verify master 2>/dev/null`
  4. If all detection fails, ask the user which branch to target
- Build the `gh pr create` command:
  - Always include: `--base <base-branch>` and a body with summary + test plan
  - If DRAFT_PR is true, add `--draft`
  - If REVIEWERS is set, add `--reviewer <user>` for each reviewer
  - If LABELS is set, add `--label <label>` for each label
- Run the assembled `gh pr create` command
- Show the user the PR URL
- If DRAFT_PR is true, remind the user: "Created as draft PR. Mark as ready with `gh pr ready <number>` when appropriate."

### Step 4: Review the PR

If SKIP_REVIEW is true, skip Steps 4, 5, 6, and 7a entirely — proceed directly to Step 7b (or Step 7c if SKIP_PPTX is also true).

- Run: `gh pr diff <pr-number>`
- Perform a thorough code review covering:
  - Correctness and edge cases
  - Security concerns (injection, XSS, secrets, OWASP top 10)
  - Performance and efficiency
  - Code clarity and maintainability
  - Test coverage gaps
  - Cross-platform issues (if applicable)
- Present findings in this format:

  ```
  ## Code Review — PR #<number>

  | # | Severity | Category | File(s) | Finding |
  |---|----------|----------|---------|---------|
  | 1 | CRITICAL | Security | path/to/file.ts:42 | Brief description |
  | 2 | WARNING  | Performance | src/index.ts:88 | Brief description |
  | 3 | SUGGESTION | Clarity | lib/utils.ts:15 | Brief description |

  **Summary:** N critical, N warnings, N suggestions
  ```

- Below the table, provide a detailed explanation for each finding (numbered to match)
- If there are zero findings, say "No issues found — the code looks good." and skip Steps 5-7a

### Step 5: Generate a fix plan

- For each review finding, propose a concrete fix with file paths and approach
- Group fixes by file
- Estimate scope (one-liner vs multi-file change)
- Present the full plan to the user in a clear table or list

### Step 6: APPROVAL GATE — Stop and wait

**IMPORTANT: You MUST stop here and ask the user to approve the plan.**

Present the plan summary and ask:
> "Here's the plan to address the review findings. Approve all, select specific items, or reject?"

- If the user approves all: proceed to step 7
- If the user selects specific items: only implement those
- If the user rejects: skip to step 7b (presentation) or step 8 (merge) based on user preference
- Do NOT proceed without explicit approval

### Step 7: Execute fixes and generate presentation

#### 7a: Execute the approved fixes
- Implement each approved fix
- Detect and run the project's test suite using this priority order:
  1. **package.json** — look for `scripts.test`, `scripts.test:unit`, or `scripts.test:ci`. Run via `npm test` (or `yarn test` / `pnpm test` if a `yarn.lock` or `pnpm-lock.yaml` is present)
  2. **Makefile** — check for `test`, `check`, or `verify` targets. Run via `make test`
  3. **pyproject.toml** — check for `[tool.pytest]` section. Run via `pytest`
  4. **Cargo.toml** — run `cargo test`
  5. **go.mod** — run `go test ./...`
  6. If no test runner is detected, tell the user: "No test runner detected — skipping tests."
- If tests fail, show the output and ask: "Tests failed. Fix and retry, continue anyway, or abort?"
- Commit fixes with a clear message referencing the review
- Push the updated branch: `git push`

#### 7b: Generate a PowerPoint presentation

If SKIP_PPTX is true, skip this step entirely.

Create a `.pptx` file using Python and the `python-pptx` library.

Write and execute a Python script that builds the presentation with these requirements:

**Theme:**
- Light background: white (`#FFFFFF`) or very light gray (`#F5F5F5`)
- Primary text: dark gray (`#333333`)
- Accent color: soft blue (`#4A90D9`)
- Secondary accent: light green (`#27AE60`) for improvements
- Font: Calibri or Arial throughout
- Slide dimensions: widescreen 16:9

**Slide structure:**

1. **Title slide** — Project name, "What Changed & Why", date, branch name
2. **Overview slide** — Bullet summary of all changes in plain English (no code jargon). Use a subtitle like "Here's what we improved"
3. **For each significant change**, create a slide with:
   - A plain-English title (e.g., "We made the app faster" not "Optimized O(n²) loop")
   - Before/After comparison — use a simple two-column layout or visual metaphor
   - A "Why this matters" callout box explaining the user-facing benefit
   - Add a simple visual where helpful:
     - Use colored shapes (rectangles, arrows, circles) to illustrate flow changes
     - Use simple bar charts or comparison graphics for performance improvements
     - Use checkmark/X icons (✓/✗) for fixed vs broken states
     - Use arrow diagrams for architectural changes
4. **Impact summary slide** — A visual scorecard:
   - Number of issues found vs fixed
   - Categories addressed (security, performance, clarity, etc.)
   - Use colored boxes or a simple chart
5. **Closing slide** — "Ready for production" with the PR link and merge status

Create the `doc/` directory in the project root if it doesn't exist. Save the file as `doc/changes-presentation-<branch-name>.pptx`.

Execute the script:

```bash
uv run --with python-pptx python /tmp/merge_it_presentation.py
```

If `uv` is not available, fall back to: `python3 -m pip install python-pptx && python3 /tmp/merge_it_presentation.py`

Tell the user where the file was saved.

#### 7c: Check CI status

Before merging, check the status of PR checks:

- Run: `gh pr checks <pr-number>`
- If all checks pass, proceed to Step 8
- If checks are still running, tell the user: "CI checks are still running. Wait for them to complete, or proceed to merge anyway?" Show the check names and their current status.
- If any checks have failed, show the failures and ask: "Some CI checks failed. View details, proceed anyway, or abort?"

### Step 8: Merge into default branch

- Ask the user for final confirmation: "Ready to merge PR #<number> into <default-branch> via <MERGE_STRATEGY>?"
- If confirmed, attempt: `gh pr merge <pr-number> --MERGE_STRATEGY --delete-branch` (where MERGE_STRATEGY is `--merge`, `--squash`, or `--rebase`)
- If the merge fails (exit code != 0, e.g. branch protection rules, required checks not yet passing), automatically retry with auto-merge: `gh pr merge <pr-number> --auto --MERGE_STRATEGY --delete-branch`
  - If auto-merge succeeds, tell the user: "PR can't be merged yet (branch protection). Enabled auto-merge with <strategy> strategy — it will merge automatically once all checks pass."
  - If auto-merge also fails, show the error and ask the user how to proceed
- If the initial merge succeeds, show the merge result and final status
- After successful merge (or auto-merge enablement), switch back to the base branch: `git checkout <base-branch> && git pull`
- Print a summary:
  ```
  Done! PR #<number> merged into <base-branch> via <strategy>.
  Branch <branch-name> has been deleted.
  Presentation saved to: doc/changes-presentation-<branch-name>.pptx (if generated)
  ```
- If not confirmed, leave the PR open and inform the user

### Error handling

- If any step fails, show the error clearly and ask the user how to proceed
- Never force-push or use destructive git operations without asking
- If `python-pptx` is unavailable and both `uv` and `pip` fail, fall back to creating an HTML presentation file instead
- If `gh` commands fail with authentication errors, suggest `gh auth login`
- If `git push` fails with permission errors, show the remote URL and suggest checking access
- If PR creation fails because a PR already exists for the branch, show the existing PR URL and offer to continue with it
- If the branch name already exists on the remote, ask the user to choose a different name or confirm overwriting
