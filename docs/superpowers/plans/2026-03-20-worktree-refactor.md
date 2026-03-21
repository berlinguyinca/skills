# Worktree Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `gw:worktree` skill for concurrent feature development via git worktrees, make `gw:merge-it` worktree-aware, and update skill references.

**Architecture:** A new `gw:worktree` skill manages the full worktree lifecycle (create, status, merge-all, cleanup) with a `.worktrees/manifest.json` for state tracking. `gw:merge-it` gains worktree detection (Step 0.7) and manifest updates. Three skills get text-only reference updates.

**Tech Stack:** Git worktrees, GitHub CLI (`gh`), JSON manifest

**Spec:** `docs/superpowers/specs/2026-03-20-worktree-refactor-design.md`

---

## File Structure

| Action | File | Responsibility |
|--------|------|---------------|
| Create | `.claude/commands/gw/worktree.md` | New skill — worktree lifecycle management |
| Modify | `.claude/commands/gw/merge-it.md` | Add worktree detection, manifest updates, `--all` flag |
| Modify | `.claude/commands/gw/saas-idea.md` | Replace 4 `superpowers:using-git-worktrees` references |
| Modify | `.claude/commands/gw/research.md` | Replace 1 `superpowers:using-git-worktrees` reference |
| Modify | `.claude/commands/gw/review-app.md` | Replace 1 `superpowers:using-git-worktrees` reference |
| Modify | `README.md` | Add `gw:worktree` listing and concurrent workflow section |

---

### Task 1: Create `gw:worktree` Skill

**Files:**
- Create: `.claude/commands/gw/worktree.md`

This is the core new skill. It follows the same conventions as other gw skills: YAML frontmatter, Step 0 update check, Step 0.5 GSD detection, argument parsing, workflow routing.

- [ ] **Step 1: Create the skill file with frontmatter and boilerplate**

Write `.claude/commands/gw/worktree.md` with:

```markdown
---
name: worktree
description: Manage git worktrees for concurrent feature development — create, status, merge-all, cleanup
argument-hint: "create <name> [--purpose \"description\"] | status | merge-all | cleanup [name]"
---
```

Then add Step 0 (update check) — copy the exact pattern from `merge-it.md:7-16`:

```markdown
## Step 0 — Update check

Resolve the gw-skills repo directory and run its update check script:

\`\`\`bash
GW_REPO="$(cd "$(readlink ~/.claude/commands/gw)/../../.." 2>/dev/null && pwd)" || GW_REPO="$HOME/.gw-skills"
bash "$GW_REPO/check-update.sh" 2>/dev/null || true
\`\`\`

If the output contains `UPDATE_AVAILABLE`, tell the user how many commits behind they are and ask: "gw-skills has updates available. Run /gw:update to install them, or continue?" If they want to update, invoke `/gw:update` and stop. Otherwise continue. If the script is missing or fails, skip silently.
```

Then add Step 0.5 (GSD detection) — copy the exact pattern from `merge-it.md:20-31`:

```markdown
## Step 0.5 — GSD Project Detection (Model Inheritance)

Skip this step if you are inside a GSD project (`~/.config/opencode/.planning/` exists).

If `.planning/config.json` exists in the current or parent directories:
1. Try to resolve and read its JSON content using Bash/Grep
2. Extract `model_profile` (default: "balanced")
3. If a profile is found, use it for all agent spawns instead of default Claude model
4. Log: "Using GSD model profile: {profile}" in the first output message

This enables gw skills to inherit opencode's model preferences within managed projects.
```

- [ ] **Step 2: Add argument parsing and workflow routing**

After Step 0.5, add:

```markdown
---

## Parse arguments

Parse the arguments: "$ARGUMENTS"

- If first positional argument is `create`, set SUBCOMMAND="create"
  - Second positional argument is NAME (required)
  - If `--purpose "description"` is present, set PURPOSE
- If first positional argument is `status`, set SUBCOMMAND="status"
- If first positional argument is `merge-all`, set SUBCOMMAND="merge-all"
- If first positional argument is `cleanup`, set SUBCOMMAND="cleanup"
  - Optional second positional argument is NAME (specific worktree to clean)
- If no arguments, set SUBCOMMAND="status" (default)

## Workflow routing

| Subcommand | Steps executed |
|------------|----------------|
| `create`   | 0 → 0.5 → 1 (create) |
| `status`   | 0 → 0.5 → 2 (status) |
| `merge-all`| 0 → 0.5 → 3 (merge-all) |
| `cleanup`  | 0 → 0.5 → 4 (cleanup) |
```

- [ ] **Step 3: Add Step 1 — Create subcommand**

```markdown
---

## Step 1 — Create worktree

### 1a: Directory selection

Check for an existing worktree directory in this priority order:

1. Check if `.worktrees/` exists: `ls -d .worktrees 2>/dev/null`
2. Check if `worktrees/` exists: `ls -d worktrees 2>/dev/null`
3. If both exist, use `.worktrees/`
4. Check CLAUDE.md for preference: `grep -i "worktree.*director" CLAUDE.md 2>/dev/null`
5. If no directory exists and no CLAUDE.md preference, ask the user:

> No worktree directory found. Where should I create worktrees?
> 1. `.worktrees/` (project-local, hidden) — recommended
> 2. `~/.config/superpowers/worktrees/<project-name>/` (global location)

Use the selected directory for all subsequent operations. Default to `.worktrees/` if the user doesn't have a preference.

### 1b: Gitignore verification

For project-local directories only (`.worktrees/` or `worktrees/`):

```bash
git check-ignore -q .worktrees 2>/dev/null
```

If NOT ignored (exit code != 0):
1. Add `.worktrees/` (or `worktrees/`) to `.gitignore`
2. Commit: `git add .gitignore && git commit -m "chore: add worktree directory to gitignore"`

### 1c: Create the worktree

```bash
git worktree add .worktrees/<NAME> -b <NAME>
```

If the branch already exists, ask: "Branch `<NAME>` already exists. Use existing branch [e], choose a different name [d], or abort [a]?"

### 1d: Project setup

Auto-detect and run project setup in the new worktree:

```bash
cd .worktrees/<NAME>
```

Run the first matching setup:
- If `package.json` exists: `npm install` (or `yarn install` if `yarn.lock` exists, or `pnpm install` if `pnpm-lock.yaml` exists)
- If `Cargo.toml` exists: `cargo build`
- If `requirements.txt` exists: `pip install -r requirements.txt`
- If `pyproject.toml` exists: `poetry install` (or `pip install -e .` if no poetry.lock)
- If `go.mod` exists: `go mod download`
- If none match, skip with: "No package manager detected — skipping dependency install."

### 1e: Baseline verification

Run the project's test suite using the same detection priority as `gw:merge-it` Step 7a:
1. `package.json` → `npm test`
2. `pyproject.toml` / pytest → `pytest`
3. `Cargo.toml` → `cargo test`
4. `go.mod` → `go test ./...`
5. `Makefile` with test target → `make test`
6. No test runner → "No test runner detected — skipping baseline verification."

If tests fail, show the output and ask: "Baseline tests failed. Proceed anyway [p] or investigate [i]?"

### 1f: Update manifest

Read or create `.worktrees/manifest.json`. Add an entry:

```json
{
  "name": "<NAME>",
  "branch": "<NAME>",
  "path": ".worktrees/<NAME>",
  "created": "<ISO-8601 timestamp>",
  "purpose": "<PURPOSE or 'No purpose specified'>",
  "pr_number": null,
  "status": "active"
}
```

### 1g: Report

Print:

```
Worktree created: .worktrees/<NAME>
Branch: <NAME>
Tests: <N> passing, <N> failures (or "skipped")
Purpose: <PURPOSE>

cd .worktrees/<NAME> to start working.
```
```

- [ ] **Step 4: Add Step 2 — Status subcommand**

```markdown
---

## Step 2 — Status

### 2a: Read manifest

Read `.worktrees/manifest.json`. If it doesn't exist, print: "No worktrees managed. Run `/gw:worktree create <name>` to create one." and stop.

### 2b: Cross-reference with git

Run `git worktree list` and compare with manifest entries:
- If a manifest entry's path no longer appears in `git worktree list`, mark it as orphaned and note in output
- If `git worktree list` shows worktrees not in the manifest, note them as "untracked"

### 2c: Check PR status

For each active worktree, check for an open PR:

```bash
gh pr list --head <branch> --json number,state,statusCheckRollup --limit 1
```

Extract PR number, state, and CI status (passing/failing/pending).

### 2d: Display table

```
Worktree Status:

| Name | Branch | Created | PR | CI | Purpose |
|------|--------|---------|----|----|---------|
| auth-system | auth-system | 2026-03-20 | #42 | passing | Implement OAuth2 login |
| billing | billing | 2026-03-20 | — | — | Stripe billing integration |

Active: 2 | Merged: 0 | Total: 2
```

If there are orphaned or untracked worktrees, show them separately with a note.
```

- [ ] **Step 5: Add Step 3 — Merge-all subcommand**

```markdown
---

## Step 3 — Merge all worktrees

### 3a: Read and present

Read manifest, filter to entries with `status: "active"`. If none, print: "No active worktrees to merge." and stop.

Present the list:

```
Active worktrees to merge:

1. auth-system — PR #42 (passing) — Implement OAuth2 login
2. billing — no PR — Stripe billing integration

Merge in this order? [y] / Reorder [r] / Cancel [c]
```

If the user selects [r], ask for the new order (e.g., "2, 1").

### 3b: Merge each worktree

For each worktree in order:

1. `cd` into the worktree directory
2. Check if a PR exists for this branch: `gh pr list --head <branch> --json number --limit 1`
3. **If no PR exists:** Invoke the full `gw:merge-it` workflow (Steps 1-8) from within the worktree. Since the branch already exists (Step 1 will be skipped due to worktree detection — see Task 2), this effectively runs: push → create PR → review → fix → present → merge.
4. **If PR exists but not merged:** Invoke `gw:merge-it` from Step 4 onward (review → fix → present → merge).
5. After successful merge, update the manifest entry: set `status: "merged"`, record `pr_number`.
6. **If merge fails** (conflicts, CI failure, user aborts):
   - Print the error clearly
   - Ask: "Skip this worktree and continue with next [s], retry after manual fix [r], or abort merge-all [a]?"
   - If [s]: mark as skipped in the summary, continue
   - If [r]: wait for user to confirm fix is done, then retry from step 2
   - If [a]: stop and report progress so far

### 3c: Summary

After processing all worktrees, print:

```
Merge-all complete:
- Merged: N (list names)
- Skipped: N (list names with reason)
- Remaining: N (list names)

Run `/gw:worktree cleanup` to remove merged worktrees.
```
```

- [ ] **Step 6: Add Step 4 — Cleanup subcommand**

```markdown
---

## Step 4 — Cleanup

### 4a: Determine scope

- If NAME is provided, clean up only that specific worktree
- If no NAME, clean up all worktrees with `status: "merged"`

### 4b: Confirm

If cleaning multiple worktrees, list them and ask for confirmation:

```
These merged worktrees will be removed:
- auth-system (.worktrees/auth-system)
- billing (.worktrees/billing)

Proceed? [y/n]
```

If cleaning a single worktree, confirm: "Remove worktree `<NAME>`? [y/n]"

If the worktree status is "active" (not merged), warn: "Worktree `<NAME>` has not been merged yet. Remove anyway? [y/n]"

### 4c: Remove

For each worktree to remove:

```bash
git worktree remove .worktrees/<NAME>
```

If removal fails (e.g., uncommitted changes), show the error and ask: "Force remove (discards uncommitted changes)? [y/n]"

If forced: `git worktree remove --force .worktrees/<NAME>`

Remove the entry from `.worktrees/manifest.json`.

### 4d: Prune

After all removals:

```bash
git worktree prune
```

### 4e: Report

Print what was removed:

```
Cleaned up:
- auth-system (removed)
- billing (removed)

Remaining worktrees: N (or "none")
```

If the manifest is now empty, delete `.worktrees/manifest.json`.
```

- [ ] **Step 7: Add error handling section**

```markdown
---

## Error handling

- **`git worktree add` fails:** Show the error. Common causes: branch already exists (offer to use existing), dirty working tree, path already occupied.
- **Manifest file corrupted:** If JSON parsing fails, offer to recreate from `git worktree list` output.
- **`gh` not authenticated:** Suggest `gh auth login` (same as merge-it).
- **Worktree directory deleted manually:** Detect via cross-reference in status, offer `git worktree prune` to clean up.
- **Permission errors on directory creation:** Show the error and suggest checking filesystem permissions.
```

- [ ] **Step 8: Commit the new skill**

```bash
git add .claude/commands/gw/worktree.md
git commit -m "feat: add gw:worktree skill for concurrent feature development

New skill with four subcommands:
- create: set up isolated worktree with project setup and test verification
- status: show all worktrees with PR and CI status
- merge-all: merge all worktree branches via PRs in sequence
- cleanup: remove merged worktrees and prune references"
```

---

### Task 2: Make `gw:merge-it` Worktree-Aware

**Files:**
- Modify: `.claude/commands/gw/merge-it.md:34-62` (argument parsing, workflow routing)
- Modify: `.claude/commands/gw/merge-it.md:66-92` (pre-flight checks, Step 1)
- Modify: `.claude/commands/gw/merge-it.md:250-265` (Step 8 merge)

- [ ] **Step 1: Add `--all` flag to argument parsing**

In `.claude/commands/gw/merge-it.md`, in the "Parse arguments" section (around line 36), add after the `--skip-log-patrol` line:

```markdown
- If `--all` is present, set MERGE_ALL=true
```

- [ ] **Step 2: Update the argument-hint in frontmatter**

In `.claude/commands/gw/merge-it.md`, update the frontmatter `argument-hint` (line 4) to include `--all`:

```yaml
argument-hint: "[--all] [--skip-presentation] [--skip-review] [--skip-log-patrol] [--squash|--rebase] [--draft] [--reviewers <user,...>] [--labels <label,...>] [--base <branch>]"
```

- [ ] **Step 3: Add `--all` routing to workflow routing table**

In the workflow routing table (around line 55), add a new row:

```markdown
| `--all` | Delegates to `/gw:worktree merge-all` — do not continue with merge-it steps |
```

- [ ] **Step 4: Add Step 0.7 — Worktree Detection**

After the "Pre-flight checks" section (after line 85, before Step 1), insert:

```markdown
### Step 0.7: Worktree detection

Detect if running inside a git worktree:

\`\`\`bash
git_common=$(git rev-parse --git-common-dir 2>/dev/null)
git_dir=$(git rev-parse --git-dir 2>/dev/null)
\`\`\`

If `$git_common` is different from `$git_dir`, you are inside a worktree:

1. Set IN_WORKTREE=true
2. Derive the main worktree path: `MAIN_WORKTREE=$(cd "$git_common/.." && pwd)`
3. Check for manifest: `MANIFEST="$MAIN_WORKTREE/.worktrees/manifest.json"`
4. If manifest exists, read the entry for the current branch to get PURPOSE
5. Log: "Detected worktree environment. Branch: <current-branch>, Purpose: <purpose>"

**When IN_WORKTREE is true:**
- Step 1 (Create branch) is SKIPPED — the worktree branch is already the feature branch
- Step 3 (Create PR) will auto-populate the PR body with the purpose from the manifest
- Step 8 (Merge) will update the manifest entry after successful merge
```

- [ ] **Step 5: Update Step 1 to skip when in worktree**

In Step 1 (around line 87), add at the very beginning:

```markdown
If IN_WORKTREE is true, skip this step entirely — the worktree's branch is already the feature branch. Proceed to Step 2.
```

- [ ] **Step 6: Update Step 3 to use manifest purpose**

In Step 3 (around line 98), add after the PR body description:

```markdown
If IN_WORKTREE is true and PURPOSE is available from the manifest, prepend the PR body with:
```
## Purpose
<PURPOSE from manifest>
```
```

- [ ] **Step 7: Update Step 8 to update manifest after merge**

In Step 8 (around line 250), add after the successful merge confirmation:

```markdown
If IN_WORKTREE is true and MANIFEST exists, update the manifest entry for the current branch:
- Set `status` to `"merged"`
- Set `pr_number` to the PR number that was just merged

\`\`\`bash
# Read manifest from main worktree and update entry
# Use python or jq to update the JSON:
python3 -c "
import json, sys
with open('$MANIFEST') as f:
    data = json.load(f)
for w in data['worktrees']:
    if w['branch'] == '<current-branch>':
        w['status'] = 'merged'
        w['pr_number'] = <pr-number>
with open('$MANIFEST', 'w') as f:
    json.dump(data, f, indent=2)
"
\`\`\`
```

- [ ] **Step 8: Add `--all` handling at the top of the workflow**

After the "Workflow routing" section, add:

```markdown
### --all flag handling

If MERGE_ALL is true:
1. Verify you are NOT inside a worktree (this flag should be run from the main working directory)
2. Check if `.worktrees/manifest.json` exists. If not, print: "No worktrees found. Create worktrees first with `/gw:worktree create <name>`." and stop.
3. Invoke `/gw:worktree merge-all` and stop — do not continue with the normal merge-it steps.
```

- [ ] **Step 9: Commit merge-it changes**

```bash
git add .claude/commands/gw/merge-it.md
git commit -m "feat(merge-it): add worktree awareness and --all flag

- Step 0.7: detect worktree environment via git-common-dir
- Skip branch creation when inside a worktree
- Auto-populate PR description with manifest purpose
- Update manifest status after successful merge
- --all flag delegates to gw:worktree merge-all"
```

---

### Task 3: Update Skill References

**Files:**
- Modify: `.claude/commands/gw/saas-idea.md` (lines 1427, 1443, 1801, 2138)
- Modify: `.claude/commands/gw/research.md` (line 984)
- Modify: `.claude/commands/gw/review-app.md` (line 922)

- [ ] **Step 1: Update `gw:saas-idea` references**

In `.claude/commands/gw/saas-idea.md`, replace all 4 occurrences:

Line 1427 — replace:
```
- Use `superpowers:using-git-worktrees` for feature branches
```
with:
```
- Use `/gw:worktree create <name>` for feature branch isolation
```

Line 1443 — replace:
```
| Feature branches | `superpowers:using-git-worktrees` |
```
with:
```
| Feature branches | `/gw:worktree create <name>` |
```

Line 1801 — replace:
```
- `superpowers:using-git-worktrees` — for feature branch isolation
```
with:
```
- `/gw:worktree create <name>` — for feature branch isolation
```

Line 2138 — replace:
```
8. `superpowers:using-git-worktrees` — for feature branches
```
with:
```
8. `/gw:worktree create <name>` — for feature branches
```

- [ ] **Step 2: Update `gw:research` reference**

In `.claude/commands/gw/research.md`, line 984, replace:
```
- `superpowers:using-git-worktrees` — for feature branch isolation (if project has multiple phases)
```
with:
```
- `/gw:worktree create <name>` — for feature branch isolation (if project has multiple phases)
```

- [ ] **Step 3: Update `gw:review-app` reference**

In `.claude/commands/gw/review-app.md`, line 922, replace:
```
| Active feature branches | 2+ non-default branches | `superpowers:using-git-worktrees` | Process |
```
with:
```
| Active feature branches | 2+ non-default branches | `/gw:worktree create <name>` | Process |
```

- [ ] **Step 4: Commit reference updates**

```bash
git add .claude/commands/gw/saas-idea.md .claude/commands/gw/research.md .claude/commands/gw/review-app.md
git commit -m "refactor: replace superpowers:using-git-worktrees with /gw:worktree

Update references in saas-idea (4), research (1), and review-app (1)
to point to the new gw:worktree skill."
```

---

### Task 4: Update README

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Add `gw:worktree` to the skill table**

In `README.md`, in the "Available Skills" table (around line 20), add a new row after the `/gw:merge-it` row:

```markdown
| `/gw:worktree` | Manage git worktrees for concurrent feature development — create isolated workspaces, check status across all worktrees, merge all branches via PRs, and clean up after merge. |
```

- [ ] **Step 2: Add concurrent development workflow section**

After the `/gw:update` skill reference section (before "Creating Custom Personas"), add:

```markdown
### /gw:worktree

\`\`\`
/gw:worktree create <name> [--purpose "description"]
/gw:worktree status
/gw:worktree merge-all
/gw:worktree cleanup [name]
\`\`\`

Manage git worktrees for concurrent feature development. Each worktree gets its own branch and isolated workspace, allowing parallel work on multiple features.

| Subcommand | Description |
|------------|-------------|
| `create <name>` | Create a new worktree with branch, project setup, and baseline test verification |
| `status` | Show all worktrees with branch, PR, CI status, and purpose |
| `merge-all` | Merge all active worktree branches via PRs (uses `gw:merge-it` per branch) |
| `cleanup [name]` | Remove merged worktrees (or a specific one) and prune git references |

#### Options

| Flag | Description | Default |
|------|-------------|---------|
| `--purpose "description"` | Describe what this worktree is for (shown in status and PR) | "No purpose specified" |

#### Concurrent development workflow

```
/gw:worktree create auth-system --purpose "OAuth2 login flow"
/gw:worktree create billing --purpose "Stripe billing integration"
# Work in each worktree independently (cd .worktrees/auth-system, etc.)
/gw:worktree status                # check progress across all worktrees
/gw:worktree merge-all             # merge everything via PRs in sequence
/gw:worktree cleanup               # remove merged worktrees
```

Worktrees are stored in `.worktrees/` (gitignored). State is tracked in `.worktrees/manifest.json`.
```

- [ ] **Step 3: Update `gw:merge-it` description in README**

In the `/gw:merge-it` section of README.md, update the description to mention worktree awareness. In the options table (around line 249), add a new row:

```markdown
| `--all` | Merge all active worktrees via PRs (delegates to `/gw:worktree merge-all`) | |
```

Also add a brief note after the merge-it options table:

```markdown
#### Worktree awareness

When run inside a git worktree (created by `/gw:worktree create`), merge-it automatically:
- Skips branch creation (uses the worktree's branch)
- Populates the PR description with the worktree's purpose
- Updates the worktree manifest after merge
```

- [ ] **Step 4: Commit README updates**

```bash
git add README.md
git commit -m "docs: add gw:worktree to README and update merge-it docs

- Add gw:worktree to skill table and full reference section
- Add concurrent development workflow example
- Document merge-it --all flag and worktree awareness"
```
