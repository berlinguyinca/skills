# Branch-First Execution

Shared module for creating an isolated branch before skill work begins. The calling skill sets `SKILL_NAME` before including this module.

---

## Detect Current State

### Check skip conditions

Skip branch creation (set `BRANCH_CREATED=false`) if ANY of these are true:

1. **Already in a worktree:**
   ```bash
   git_common=$(git rev-parse --git-common-dir 2>/dev/null)
   git_dir=$(git rev-parse --git-dir 2>/dev/null)
   ```
   If `$git_common` != `$git_dir` → set `IN_WORKTREE=true`, skip. Log: "In worktree — skipping branch creation."

2. **Already on a `gw/` branch:**
   ```bash
   current_branch=$(git symbolic-ref --short HEAD 2>/dev/null)
   ```
   If `$current_branch` starts with `gw/` → set `ALREADY_GW_BRANCH=true`, skip. Log: "Already on gw/ branch — skipping branch creation."

3. **`--no-branch` flag** is present in `$ARGUMENTS` → skip. Log: "Branch isolation disabled via --no-branch."

If skipped, set these variables and stop:
- `BRANCH_CREATED=false`
- `GW_BRANCH=$current_branch`
- `BASE_BRANCH=$current_branch`

---

## Stash Uncommitted Changes

Check for uncommitted changes:

```bash
git status --porcelain
```

If output is non-empty:
```bash
git stash push -m "gw:auto-stash before gw/${SKILL_NAME}"
```
Set `STASHED=true`. Log: "Stashed uncommitted changes."

If output is empty: set `STASHED=false`.

---

## Create Branch

1. Record the base branch:
   ```bash
   BASE_BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null || echo "main")
   ```

2. Generate a short ID:
   ```bash
   SHORT_ID=$(date +%Y%m%d)-$(head -c 4 /dev/urandom | xxd -p | head -c 4)
   ```

3. Create and switch to the new branch:
   ```bash
   GW_BRANCH="gw/${SKILL_NAME}/${SHORT_ID}"
   git checkout -b "${GW_BRANCH}"
   ```

4. If `STASHED=true`, pop the stash:
   ```bash
   git stash pop
   ```
   If pop fails, warn: "Could not pop stash. Recover manually with `git stash list`."

5. Set `BRANCH_CREATED=true`.

Log: "Working on branch: `${GW_BRANCH}` (based on `${BASE_BRANCH}`)"

---

## Variables Set

| Variable | Value | Purpose |
|----------|-------|---------|
| `GW_BRANCH` | `gw/<skill-name>/<short-id>` or current branch | Branch name for this execution |
| `BASE_BRANCH` | Original branch name | Target for PR creation later |
| `BRANCH_CREATED` | `true` / `false` | Whether this module created a new branch |
| `IN_WORKTREE` | `true` / `false` | Whether running inside a worktree |
| `STASHED` | `true` / `false` | Whether changes were stashed |
