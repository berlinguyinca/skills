---
name: worktree
description: Manage git worktrees for concurrent feature development — create, status, merge-all, cleanup
argument-hint: "create <name> [--purpose \"description\"] | status | merge-all | cleanup [name] | execute <manifest-path>"
---

## Step 0 — Update check

Resolve the gw-skills repo directory and run its update check script:

```bash
GW_REPO="$(cd "$(readlink ~/.claude/commands/gw)/../../.." 2>/dev/null && pwd)" || GW_REPO="$HOME/.gw-skills"
bash "$GW_REPO/check-update.sh" 2>/dev/null || true
```

If the output contains `UPDATE_AVAILABLE`, tell the user how many commits behind they are and ask: "gw-skills has updates available. Run /gw:update to install them, or continue?" If they want to update, invoke `/gw:update` and stop. Otherwise continue. If the script is missing or fails, skip silently.

---

## Step 0.5 — GSD Project Detection (Model Inheritance)

Skip this step if you are inside a GSD project (`~/.config/opencode/.planning/` exists).

If `.planning/config.json` exists in the current or parent directories:
1. Try to resolve and read its JSON content using Bash/Grep
2. Extract `model_profile` (default: "balanced")
3. If a profile is found, use it for all agent spawns instead of default Claude model
4. Log: "Using GSD model profile: {profile}" in the first output message

This enables gw skills to inherit opencode's model preferences within managed projects.

---

## Parse arguments & route

Parse the arguments: "$ARGUMENTS"

- If the first word is `create`, extract `<name>` and optional `--purpose "description"`
- If the first word is `status`, or no arguments are provided, route to status
- If the first word is `merge-all`, route to merge-all
- If the first word is `cleanup`, extract optional `[name]`
- If the first word is `execute`, extract `<manifest-path>` (required)

### Workflow routing

| Command | Action |
|---------|--------|
| `create <name> [--purpose "desc"]` | Step 1 — Create worktree |
| `status` (or no args) | Step 2 — Status |
| `merge-all` | Step 3 — Merge all |
| `cleanup [name]` | Step 4 — Cleanup |
| `execute <manifest-path>` | Step 5 — Execute manifest |

---

## Step 1 — Create worktree

### 1a: Directory selection

Determine the worktree root directory:

1. If `.worktrees/` already exists in the project root, use it
2. Else if `worktrees/` already exists, use it
3. Else if `CLAUDE.md` exists in the project root, check it for a worktree directory preference
4. If none of the above resolve, ask the user: "Where should worktrees live? [.worktrees] / worktrees / custom path"
5. Default to `.worktrees/` if the user just presses enter

Create the directory if it does not exist:

```bash
mkdir -p <worktree-dir>
```

### 1b: Gitignore verification

Check whether the worktree directory is already git-ignored:

```bash
git check-ignore -q <worktree-dir>
```

If the directory is NOT ignored (exit code != 0):
1. Check if `.gitignore` exists in the project root
2. Append the worktree directory pattern (e.g., `.worktrees/`) to `.gitignore`
3. Stage and commit the change:

```bash
git add .gitignore && git commit -m "chore: add worktree directory to gitignore"
```

4. Tell the user: "Added `<worktree-dir>` to .gitignore and committed."

### 1c: Create worktree

Create the worktree and its tracking branch:

```bash
git worktree add <worktree-dir>/<NAME> -b <NAME>
```

If the branch `<NAME>` already exists:
- Ask the user: "Branch `<NAME>` already exists. Use existing branch [e], pick a different name [d], or cancel [c]?"
- If `[e]`: run `git worktree add <worktree-dir>/<NAME> <NAME>` (without `-b`)
- If `[d]`: ask for a new name and retry
- If `[c]`: stop

### 1d: Project setup

Auto-detect the project type and install dependencies inside the new worktree:

| Detected file | Action |
|---------------|--------|
| `package.json` | Run `npm install` (or `yarn install` / `pnpm install` if lockfile present) |
| `Cargo.toml` | Run `cargo build` |
| `requirements.txt` | Run `pip install -r requirements.txt` |
| `pyproject.toml` | Run `poetry install` or `pip install -e .` (detect poetry via `[tool.poetry]`) |
| `go.mod` | Run `go mod download` |

Run the setup command from inside the worktree directory:

```bash
cd <worktree-dir>/<NAME> && <setup-command>
```

If no known project file is detected, skip with: "No package manager detected — skipping dependency install."

### 1e: Baseline test verification

Run the project's test suite to verify the worktree starts from a clean baseline. Use the same detection priority as merge-it:

1. **package.json** — look for `scripts.test`. Run via `npm test` (or `yarn test` / `pnpm test` if lockfile present)
2. **pyproject.toml** / **pytest** — check for `[tool.pytest]` section or `pytest.ini`. Run via `pytest`
3. **Cargo.toml** — run `cargo test`
4. **go.mod** — run `go test ./...`
5. **Makefile** — check for `test` target. Run via `make test`

If tests pass, report: "Baseline tests pass."

If tests fail:
- Show the failure output
- Ask: "Baseline tests failed in the new worktree. Proceed anyway [p] or investigate [i]?"
- `[p]`: continue to next step
- `[i]`: show test output details and let the user decide next steps

If no test runner is detected: "No test runner detected — skipping baseline verification."

### 1f: Update manifest

Read or create the manifest file at `<worktree-dir>/manifest.json`.

If the file does not exist, initialize it:

```json
{
  "worktrees": []
}
```

Append a new entry to the `worktrees` array:

```json
{
  "name": "<NAME>",
  "branch": "<NAME>",
  "path": "<worktree-dir>/<NAME>",
  "created": "<ISO-8601 timestamp>",
  "purpose": "<description from --purpose or null>",
  "pr_number": null,
  "status": "active"
}
```

Write the updated manifest back to disk.

### 1g: Report

Print a summary:

```
Worktree created:
  Name:    <NAME>
  Branch:  <NAME>
  Path:    <worktree-dir>/<NAME>
  Tests:   <pass/fail/skipped>
  Purpose: <description or "none">

To start working:
  cd <worktree-dir>/<NAME>
```

Stop.

---

## Step 2 — Status

### 2a: Resolve worktree directory and read manifest

Resolve the worktree directory using the same priority as Step 1a (check `.worktrees/` first, then `worktrees/`, then CLAUDE.md). Do NOT prompt the user — if no directory is found, say: "No worktrees managed. Use `/gw:worktree create <name>` to create one." and stop.

Read `<worktree-dir>/manifest.json`. If the manifest file does not exist inside the resolved directory, show the same message and stop.

### 2b: Cross-reference with git

Run `git worktree list` and cross-reference with manifest entries:

- **Orphaned entries:** in manifest but not in `git worktree list` (worktree was manually deleted)
- **Untracked worktrees:** in `git worktree list` but not in manifest (created outside this skill)

Flag both categories in the output.

### 2c: Check PR status

For each worktree in the manifest with status "active":

```bash
gh pr list --head <branch> --json number,state,statusCheckRollup --limit 1
```

Extract:
- PR number and state (open, merged, closed)
- CI status from `statusCheckRollup` (pass, fail, pending, none)

If `gh` is not authenticated or the command fails, show "?" for PR and CI columns.

### 2d: Display table

```
Worktree Status (N managed):

| Name | Branch | Created | PR | CI | Purpose |
|------|--------|---------|----|----|---------|
| auth-refactor | auth-refactor | 2026-03-18 | #42 (open) | pass | Refactor auth flow |
| fix-logging | fix-logging | 2026-03-19 | — | — | Fix log rotation bug |
| new-api | new-api | 2026-03-20 | #45 (merged) | pass | Add v2 API endpoints |

Summary: 2 active, 1 merged, 0 abandoned
```

If orphaned or untracked worktrees were detected, append:

```
Warnings:
  - Orphaned (in manifest but missing on disk): <names>
  - Untracked (on disk but not in manifest): <paths>

Use `/gw:worktree cleanup` to reconcile.
```

Stop.

---

## Step 3 — Merge all

### 3a: Resolve worktree directory, read manifest, and present list

Resolve the worktree directory using the same priority as Step 1a (check `.worktrees/` first, then `worktrees/`, then CLAUDE.md). If no directory or manifest is found, say: "No worktrees managed." and stop.

Read the manifest. Filter to entries with status "active".

If no active worktrees exist, say: "No active worktrees to merge." and stop.

Present the ordered list:

```
Active worktrees to merge:

  1. auth-refactor — Refactor auth flow (created 2026-03-18)
  2. fix-logging — Fix log rotation bug (created 2026-03-19)

Merge order: 1 → 2

Confirm this order [y], reorder [r], or cancel [c]?
```

- `[y]`: proceed with the listed order
- `[r]`: ask the user for a new order (comma-separated numbers, e.g., `2,1`)
- `[c]`: stop

### 3b: Merge each worktree

For each worktree in the confirmed order:

1. `cd` into the worktree directory
2. Check if a PR already exists for the branch:

```bash
gh pr list --head <branch> --json number,state --limit 1
```

3. **If no PR exists:** invoke the full `/gw:merge-it` flow (starting from Step 1 of merge-it)
4. **If a PR exists and is open:** invoke `/gw:merge-it` flow starting from Step 4 (review/merge the existing PR)
5. **If a PR exists and is already merged:** update the manifest entry status to "merged" and skip

After each successful merge:
- Update the manifest entry: set `status` to "merged" and `pr_number` to the PR number
- Report: "Merged <name> via PR #<number>"

If a merge fails:
- Present the error
- Ask: "Skip this worktree [s], retry [r], or abort remaining [a]?"
- `[s]`: skip and continue to the next worktree
- `[r]`: retry the current worktree
- `[a]`: stop processing remaining worktrees

### 3c: Summary

After processing all worktrees:

```
Merge-all complete:
  Merged:    N
  Skipped:   N
  Remaining: N (still active)
```

If all worktrees were merged, suggest: "All worktrees merged. Run `/gw:worktree cleanup` to remove them."

Stop.

---

## Step 4 — Cleanup

### 4a: Resolve worktree directory and determine scope

Resolve the worktree directory using the same priority as Step 1a (check `.worktrees/` first, then `worktrees/`, then CLAUDE.md). If no directory or manifest is found, say: "No worktrees managed." and stop.

- If a specific `[name]` was provided, target only that worktree
- If no name was provided, target all worktrees with status "merged"
- If no merged worktrees exist, ask: "No merged worktrees to clean up. Remove an active worktree by name? List: <active names>"

### 4b: Confirm with user

For each worktree targeted for removal, show:

```
Will remove:
  - auth-refactor (merged via PR #42)
  - new-api (merged via PR #45)

Proceed? [y/n]
```

If any targeted worktree has status "active" (not merged), add a warning:

```
WARNING: <name> has not been merged yet. Removing it will discard unmerged work.
Are you sure? [y/n]
```

### 4c: Remove worktrees

For each confirmed worktree:

```bash
git worktree remove <worktree-dir>/<name>
```

If the removal fails due to uncommitted changes:
- Show the error
- Ask: "Force remove <name>? This will discard uncommitted changes. [y/n]"
- If confirmed: `git worktree remove --force <worktree-dir>/<name>`

### 4d: Prune

After all removals, run:

```bash
git worktree prune
```

This cleans up any stale worktree metadata.

### 4e: Report

```
Cleanup complete:
  Removed: <list of removed names>
  Remaining: N worktrees still active
```

Update the manifest to remove cleaned-up entries. If no entries remain, delete the manifest file:

```bash
rm <worktree-dir>/manifest.json
```

If the worktree directory is now empty, remove it as well:

```bash
rmdir <worktree-dir> 2>/dev/null || true
```

Stop.

---

## Step 5 — Execute manifest

### 5a: Parse and validate

1. Read the manifest JSON file at `<manifest-path>`
2. If the file does not exist or is not valid JSON, print the error and stop
3. Validate required fields:
   - `project` (string) must be present
   - `features` (array) must be present and non-empty
   - Each feature must have `name` (string), `description` (string), and `acceptance_tests` (array of strings)
4. For each feature with a `spec_file`:
   - Verify the file exists. If it has a `#section` anchor, verify the heading exists in the file.
   - If the file does not exist, warn: "spec_file '<path>' not found for feature '<name>' — agent will work from description only."
5. For each feature with `test_scaffolds`:
   - Verify each file exists
   - If a file does not exist, warn: "test scaffold '<path>' not found for feature '<name>' — agent will write tests from acceptance criteria."

### 5b: Build dependency graph

Sort features into execution waves:

1. Collect all feature names
2. For each feature, validate that all entries in `dependencies` refer to other feature names in the manifest. If a dependency is not found, print: "Feature '<name>' depends on '<dep>' which is not in the manifest." and stop.
3. Build waves:
   - **Wave 1:** Features with no dependencies (or empty `dependencies` array)
   - **Wave N:** Features whose dependencies are ALL in waves 1 through N-1
4. If circular dependencies are detected, report the cycle and stop
5. Present the execution plan:

```
Execution plan for "<project>" (<N> features, <W> waves):

Wave 1 (parallel):
  - <name> — <description>
  - <name> — <description>

Wave 2 (parallel, after Wave 1 merges):
  - <name> — <description>

...

Proceed? [y/n]
```

If the user declines, stop.

### 5c: Execute waves

For each wave in order:

**Create worktrees:**

For each feature in the wave, create a worktree using the existing Step 1 (create) logic:

- Worktree path: `<worktree-dir>/<project>/<feature-name>`
- Branch: `<project>/<feature-name>`
- Purpose: the feature description

Update the worktree manifest (`.worktrees/manifest.json`) with each new entry.

**Dispatch agents:**

For each feature in the wave, dispatch an agent using the `Agent` tool:

- Set `isolation: "worktree"`
- Set `run_in_background: true`
- Set `description` to: "Build <feature-name>"

Construct the agent prompt:

```
You are implementing the feature "<name>" in an isolated git worktree.

## Feature
Name: <name>
Description: <description>

## Tech Stack
<tech_stack as formatted key-value pairs, or "Not specified" if absent>

## Specification
<Content of spec_file read and inlined here, or "No spec file provided — work from the description and acceptance tests." if absent>

## Test Scaffolds
<If test_scaffolds exist: "The following test files contain failing tests. Run them first to confirm they fail, then implement the minimal code to make them pass:" followed by the file paths>
<If no test_scaffolds: "No pre-written tests. Write failing tests first based on the acceptance tests below, then implement the minimal code to make them pass.">

## Acceptance Tests
<Each acceptance test as a numbered list>

## Instructions

1. Use `superpowers:test-driven-development` for all implementation work
2. If test scaffolds exist, run them first to confirm they fail
3. If no test scaffolds, write failing tests first from the acceptance tests
4. Implement the minimal code to make each test pass
5. Make atomic commits per test/implementation cycle
6. Use commit messages: feat(<name>): <what was implemented>
7. After all tests pass, run the full project test suite to check for regressions
8. Do NOT modify files outside your feature scope (<files_hint if provided>)

## Report

When done, report:
- **Status:** DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
- Tests passing count
- Files changed
- Any concerns or blockers
```

Dispatch all agents in the wave in parallel (multiple Agent tool calls in one message, all with `run_in_background: true`).

**Wait and handle results:**

Wait for all agents in the wave to complete. For each result:

- **DONE:** Feature is ready for merge. Log: "Feature '<name>' complete."
- **DONE_WITH_CONCERNS:** Surface concerns to user. Ask: "Feature '<name>' completed with concerns: <concerns>. Include in merge [y] or investigate [i]?"
  - `[y]`: include in merge
  - `[i]`: pause execution, let user investigate. After user confirms, continue.
- **NEEDS_CONTEXT:** Surface the agent's question to the user. After user responds, re-dispatch the agent with the additional context appended to the prompt. If user cannot answer, treat as BLOCKED.
- **BLOCKED:** Feature is skipped. Log: "Feature '<name>' BLOCKED: <reason>". Ask: "Skip and continue [s] or abort remaining waves [a]?"
  - `[s]`: mark as skipped, continue
  - `[a]`: stop processing this and all remaining waves

**Merge wave:**

After all features in the wave are resolved (done, skipped, or investigated):

1. For features that completed (DONE or DONE_WITH_CONCERNS accepted), the worktree already has commits on its branch
2. Run the merge-all logic (Step 3) for the worktrees in this wave — each feature gets its own PR
3. After all PRs in the wave are merged, proceed to the next wave

**Clean up wave:**

After wave merge completes, run cleanup (Step 4) for the merged worktrees to free disk space.

### 5d: Report

After all waves complete:

```
Execution complete for "<project>":

Wave 1:
  - <name>: DONE (<N> tests, PR #<N>)
  - <name>: DONE (<N> tests, PR #<N>)

Wave 2:
  - <name>: DONE_WITH_CONCERNS (<N> tests, PR #<N>)
    Concern: <concern text>
  - <name>: SKIPPED
    Reason: <blocker text>

Total: <N>/<N> features merged, <N> tests passing
Skipped: <N> (<names>)
```

If any features were skipped and later-wave features depended on them, note the cascade:

```
Cascade: <dep-name> was also skipped because it depends on <blocked-name>
```

Stop.

---

## Error handling

- **`git worktree add` fails:** check if the branch already exists (`git branch --list <name>`). If so, offer to use the existing branch or pick a different name. If the target directory already exists, offer to remove it first.
- **Corrupt or unparseable manifest:** back up the corrupt file to `manifest.json.bak`, create a fresh manifest, and rebuild entries from `git worktree list` output. Warn the user: "Manifest was corrupt and has been rebuilt from git state. Some metadata (purpose, PR numbers) may be lost."
- **`gh` authentication failure:** detect `gh auth status` failure and tell the user: "GitHub CLI is not authenticated. Run `gh auth login` to enable PR features. Continuing without PR integration."
- **Manually deleted worktrees:** if a manifest entry points to a path that no longer exists, mark it as orphaned. During cleanup, remove orphaned entries from the manifest. During status, flag them clearly.
- **Permission errors on worktree removal:** show the error and suggest checking file locks or running with appropriate permissions. Offer `--force` removal as a fallback.
- **Worktree directory outside project:** if the resolved path is outside the git repository root, warn the user and ask for confirmation before proceeding.
- **Manifest validation fails:** Report which fields are missing or invalid. Do not create any worktrees.
- **Circular dependencies in manifest:** Report the cycle (e.g., "A depends on B, B depends on A"). Do not create any worktrees.
- **Agent BLOCKED in a wave:** Feature is skipped. If later-wave features depend on it, cascade-skip them too and report the chain.
- **All features in a wave blocked:** Skip the wave, proceed to the next. Cascade-skip dependent features.
- **Merge conflict during wave merge-all:** Existing merge-all behavior applies (stop, ask skip/retry/abort). If aborted, remaining waves are not executed.
- **User aborts mid-execution:** Clean up all worktrees created during this execution. Report what was completed.