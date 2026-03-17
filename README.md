# gw-skills

A collection of Claude Code skills by Gert Wohlgemuth. All skills are prefixed `gw:` and available as slash commands in Claude Code.

## Install

```bash
git clone https://github.com/wohlgemuth/skills.git ~/.gw-skills && ~/.gw-skills/install.sh
```

## Uninstall

```bash
~/.gw-skills/uninstall.sh && rm -rf ~/.gw-skills
```

## Available Skills

| Skill | Description |
|-------|-------------|
| `/gw:analyze-app` | Analyze any application across specialist dimensions (UX, security, architecture, etc.) with role-adapted agents. Auto-detects app type (web, server, cli, mobile, library) and spawns 5-6 parallel specialists. |
| `/gw:update` | Update all gw-skills to the latest version. |

## Updating

Skills automatically check for updates when you run them. If updates are available, you'll be asked whether to update before continuing.

You can also update manually at any time:

```
/gw:update
```

New skills are available immediately — no reinstall needed.

## How It Works

`install.sh` symlinks `.claude/commands/gw/` into `~/.claude/commands/gw/`, making all skills available globally in Claude Code. Since it's a symlink, `git pull` delivers new skills instantly.

## Skill Options

### /gw:analyze-app

```
/gw:analyze-app [--skip-cloud] [--skip-gsd] [--type web|server|cli|mobile|library]
```

- `--skip-cloud` — Skip cloud/infrastructure cost analysis
- `--skip-gsd` — Skip automatic GSD project/milestone creation
- `--type <type>` — Force app type instead of auto-detecting

Outputs a prioritized `.analysis/REPORT.md` with findings from all specialists.
