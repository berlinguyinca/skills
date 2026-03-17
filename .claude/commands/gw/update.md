---
name: update
description: Update gw-skills to the latest version
---

Run the following Bash command:

```
cd ~/.gw-skills && git pull --ff-only 2>&1
```

If it succeeds, count the `.md` files in `~/.gw-skills/.claude/commands/gw/` (excluding `update.md`) and tell the user how many skills are now installed.

If it fails (e.g., local changes conflict), tell the user and suggest `cd ~/.gw-skills && git reset --hard origin/main && git pull`.
