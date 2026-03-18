---
name: update
description: Update gw-skills to the latest version
---

## Step 1 — Locate the repo

Resolve the gw-skills repo directory by following the symlink at `~/.claude/commands/gw`:

```bash
REPO_DIR="$(cd "$(readlink ~/.claude/commands/gw)/../../.." && pwd)"
echo "$REPO_DIR"
```

If `~/.claude/commands/gw` is not a symlink (readlink fails), fall back to `~/.gw-skills`. If neither exists, tell the user: "Could not find gw-skills repo. Re-install with: `git clone https://github.com/berlinguyinca/skills.git ~/.gw-skills && ~/.gw-skills/install.sh`" and stop.

## Step 2 — Pull updates

```bash
cd "$REPO_DIR" && git pull --ff-only 2>&1
```

If it succeeds, count the `.md` files in `$REPO_DIR/.claude/commands/gw/` (excluding `update.md`) and tell the user how many skills are now installed.

If it fails (e.g., local changes conflict), tell the user and suggest `cd $REPO_DIR && git reset --hard origin/main && git pull`.
