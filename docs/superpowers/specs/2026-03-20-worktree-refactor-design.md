# Worktree Integration for gw-skills

**Date:** 2026-03-20
**Status:** Draft

## Problem

gw-skills currently use `git checkout -b` for branching (via `gw:merge-it`), limiting work to one feature branch per working directory. Several skills reference `superpowers:using-git-worktrees` for isolation but never actually integrate with it. There is no way to run multiple features concurrently and merge them together at the end.

## Solution

A new `gw:worktree` skill that manages the full worktree lifecycle, paired with worktree-awareness in `gw:merge-it`, and updated references in code-generating skills.

## Design Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Orchestration model | Central `gw:worktree` skill | Keeps worktree logic in one place; avoids duplication across 10 skills |
| Merge strategy | PR-based (each branch gets its own PR) | Leverages existing merge-it flow, GitHub CI, and conflict detection |
| Worktree setup | Create + project setup + test verification | Ensures clean baseline; follows superpowers convention |
| Session management | Report path only (no auto-launch) | Avoids platform-dependent terminal spawning |
| State tracking | `.worktrees/manifest.json` | Light metadata for status and merge-all ordering |

---

## Component 1: `gw:worktree` Skill

New skill at `.claude/commands/gw/worktree.md` with four subcommands.

### `gw:worktree create <name> [--purpose "description"]`

**Steps:**

1. **Directory selection** — Check for existing `.worktrees/` directory > `worktrees/` > CLAUDE.md preference > ask user. Prefer `.worktrees/` (hidden).
2. **Gitignore verification** — Run `git check-ignore -q .worktrees`. If not ignored, add to `.gitignore` and commit.
3. **Create worktree** — `git worktree add .worktrees/<name> -b <name>`
4. **Project setup** — Auto-detect and run:
   - `package.json` → `npm install`
   - `Cargo.toml` → `cargo build`
   - `requirements.txt` → `pip install -r requirements.txt`
   - `pyproject.toml` → `poetry install`
   - `go.mod` → `go mod download`
5. **Baseline verification** — Run detected test suite. Report failures; ask whether to proceed if tests fail.
6. **Update manifest** — Write entry to `.worktrees/manifest.json`.
7. **Report** — Display path, branch, test status.

**Output example:**
```
Worktree created: .worktrees/auth-system
Branch: auth-system
Tests: 47 passing, 0 failures
Purpose: Implement OAuth2 login flow

cd .worktrees/auth-system to start working.
```

### `gw:worktree status`

**Steps:**

1. Read `.worktrees/manifest.json`.
2. Cross-reference with `git worktree list` (detect orphaned or removed worktrees, update manifest accordingly).
3. For each active worktree, check PR status: `gh pr list --head <branch> --json number,state,statusCheckRollup`.
4. Display table.

**Output example:**
```
| Name         | Branch       | Created    | PR    | CI      | Purpose                    |
|--------------|--------------|------------|-------|---------|----------------------------|
| auth-system  | auth-system  | 2026-03-20 | #42   | passing | Implement OAuth2 login     |
| billing      | billing      | 2026-03-20 | —     | —       | Stripe billing integration |
| notifications| notifications| 2026-03-21 | #43   | failing | Push notification system   |
```

### `gw:worktree merge-all`

**Steps:**

1. Read manifest, filter to active (non-merged) worktrees.
2. Present ordered list with PR status. User confirms or reorders.
3. For each worktree in order:
   a. `cd` into the worktree directory.
   b. If no PR exists, invoke `gw:merge-it` flow (push, create PR, review, fix, merge).
   c. If PR exists but not merged, invoke `gw:merge-it` from Step 4 onward (review, fix, merge).
   d. After successful merge, update manifest entry: `status: "merged"`, record `pr_number`.
   e. If merge fails (conflicts, CI failure), stop and report. Ask whether to skip and continue with next, or abort.
4. After all processed, report summary: N merged, N skipped, N remaining.
5. Offer cleanup of merged worktrees.

### `gw:worktree cleanup [name]`

**Steps:**

1. If `name` provided, remove that specific worktree. If not, remove all worktrees with `status: "merged"`.
2. For each: `git worktree remove <path>`.
3. Remove entry from manifest.
4. Run `git worktree prune` to clean up stale references.
5. Report what was removed.

### Manifest Format

File: `.worktrees/manifest.json`

```json
{
  "worktrees": [
    {
      "name": "auth-system",
      "branch": "auth-system",
      "path": ".worktrees/auth-system",
      "created": "2026-03-20T14:00:00Z",
      "purpose": "Implement OAuth2 login flow",
      "pr_number": null,
      "status": "active"
    }
  ]
}
```

**Status values:** `active` | `merged` | `abandoned`

The manifest file itself lives inside `.worktrees/` and is therefore gitignored along with the worktree directories.

---

## Component 2: `gw:merge-it` Changes

### New Step 0.7 — Worktree Detection

After existing pre-flight checks, before Step 1:

```bash
git_common=$(git rev-parse --git-common-dir)
git_dir=$(git rev-parse --git-dir)
if [ "$git_common" != "$git_dir" ]; then
  # Running inside a worktree
  MAIN_WORKTREE=$(git rev-parse --path-format=absolute --git-common-dir | sed 's|/\.git$||')
  MANIFEST="$MAIN_WORKTREE/.worktrees/manifest.json"
fi
```

### Behavioral Changes When Inside a Worktree

| Step | Change |
|---|---|
| Step 1 — Create branch | **Skip** — branch exists from `gw:worktree create` |
| Step 2 — Push branch | No change |
| Step 3 — Create PR | Auto-populate description with purpose from manifest |
| Steps 4-7 — Review/fix/present | No change |
| Step 8 — Merge | After merge, update manifest: set `status: "merged"`, record `pr_number` |
| Step 9 — Log patrol | No change |

### New `--all` Flag

When called with `--all` from the main worktree (not inside a worktree):
- Delegates to `gw:worktree merge-all` logic.
- Equivalent shortcut so users don't need two commands.

### Backward Compatibility

- merge-it works exactly as before when not in a worktree.
- No changes to existing flags: `--squash`, `--rebase`, `--skip-review`, `--skip-presentation`, `--draft`, `--reviewers`, `--labels`, `--base`.

---

## Component 3: Skill Reference Updates

Replace `superpowers:using-git-worktrees` references with `/gw:worktree` in four skills:

| Skill | Files with references | Change |
|---|---|---|
| `gw:saas-idea` | 4 occurrences | Replace with `/gw:worktree create <name>` recommendation |
| `gw:compete` | Implementation output section | Replace with `/gw:worktree create <name>` recommendation |
| `gw:research` | 1 occurrence | Replace with `/gw:worktree create <name>` recommendation |
| `gw:review-app` | Multi-branch detection section | Replace with `/gw:worktree create <name>` recommendation |

These are text-only changes. No behavioral logic changes in these skills.

---

## Component 4: README Updates

- Add `gw:worktree` to the skill table with subcommand descriptions.
- Add "Concurrent Development Workflow" section:

```
## Concurrent Development

Work on multiple features simultaneously using worktrees:

1. /gw:worktree create auth-system --purpose "OAuth2 login"
2. /gw:worktree create billing --purpose "Stripe integration"
3. Work in each worktree independently
4. /gw:worktree status              # check progress
5. /gw:worktree merge-all           # merge everything via PRs
6. /gw:worktree cleanup             # remove merged worktrees
```

- Update `gw:merge-it` description to mention worktree awareness.

---

## Out of Scope

- Auto-creating worktrees from within skills (skills recommend, user decides)
- Conflict resolution tooling beyond what GitHub PRs provide
- Cross-worktree dependency management
- Spawning new Claude Code sessions in worktrees

## Dependencies

- `git` (worktree support, available since git 2.5)
- `gh` CLI (already required by merge-it)
- No new external dependencies
