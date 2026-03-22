---
name: worktree
description: Manage git worktrees for concurrent feature development — create, status, merge-all, cleanup
argument-hint: "create <name> [--purpose \"description\"] | status | merge-all | cleanup [name] | execute <manifest-path>"
---

## Step 0 — Preamble

Resolve the gw-skills repo path, then read and follow `$GW_REPO/.claude/commands/gw/_shared/preamble.md` for update check and GSD project detection:

```bash
GW_REPO="$(cd "$(readlink ~/.claude/commands/gw)/../../.." 2>/dev/null && pwd)" || GW_REPO="$HOME/.gw-skills"
```

GW_REPO persists for the duration of this skill run — do not re-resolve it in later steps.

---

## Parse arguments & route

Parse the arguments: "$ARGUMENTS"

| Subcommand | Extracted args | Notes |
|------------|---------------|-------|
| `create <name>` | NAME, optional `--purpose "description"` | |
| `status` | *(none)* | Also the default when no arguments provided |
| `merge-all` | *(none)* | |
| `cleanup [name]` | optional NAME | |
| `execute <manifest-path>` | MANIFEST_PATH (required) | |

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

Run the project's test suite to verify the worktree starts from a clean baseline. Detect and run the test suite following the priority in `$GW_REPO/.claude/commands/gw/_shared/test-runner.md`.

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
4. **If a PR exists and is open:** invoke `/gw:merge-it` — it will auto-detect the existing PR via its pre-flight checks and resume from the appropriate step
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

Read and follow `$GW_REPO/.claude/commands/gw/_shared/worktree-execute.md` for the full execute subcommand: manifest format specification, dependency-wave execution, agent dispatch logic, per-agent verification steps, execute-specific error handling, and final report format.

---

## Error handling

- **`git worktree add` fails:** check if the branch already exists (`git branch --list <name>`). If so, offer to use the existing branch or pick a different name. If the target directory already exists, offer to remove it first.
- **Corrupt or unparseable manifest:** back up the corrupt file to `manifest.json.bak`, create a fresh manifest, and rebuild entries from `git worktree list` output. Warn the user: "Manifest was corrupt and has been rebuilt from git state. Some metadata (purpose, PR numbers) may be lost."
- **`gh` authentication failure:** detect `gh auth status` failure and tell the user: "GitHub CLI is not authenticated. Run `gh auth login` to enable PR features. Continuing without PR integration."
- **Manually deleted worktrees:** if a manifest entry points to a path that no longer exists, mark it as orphaned. During cleanup, remove orphaned entries from the manifest. During status, flag them clearly.
- **Permission errors on worktree removal:** show the error and suggest checking file locks or running with appropriate permissions. Offer `--force` removal as a fallback.
- **Worktree directory outside project:** if the resolved path is outside the git repository root, warn the user and ask for confirmation before proceeding.
- **Execute-subcommand errors:** see `$GW_REPO/.claude/commands/gw/_shared/worktree-execute.md`.