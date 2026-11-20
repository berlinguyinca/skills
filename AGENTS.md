# AGENTS.md

## Repository purpose

This repository distributes `gw:` Claude Code slash commands. Command definitions
live in `.claude/commands/gw/`; shared command fragments live in
`.claude/commands/gw/_shared/`; reusable team personas live in `workforce/`.

## Editing command skills

- Keep each public command's YAML front matter (`name`, `description`, and where
  applicable `argument-hint`) accurate; the README command table documents the
  public surface.
- Reuse or update the appropriate `_shared/` fragment for behavior shared by
  multiple commands instead of duplicating it across command files.
- Keep command examples and documented flags synchronized with the command
  definition.

## Shared command workflows

- Public commands that use the common startup flow reference
  `.claude/commands/gw/_shared/preamble.md`; update the shared preamble rather
  than copying its update check or GSD project detection into individual
  commands. GSD-2 detection (`.gsd/STATE.md`) takes precedence over the legacy
  GSD v1 configuration (`.planning/config.json`).
- The artifact-producing commands (`audit-repo`, `compete`, `research`,
  `review-app`, and `saas-idea`) use the shared branch-first workflow by
  default. Keep their `--no-branch` opt-out, intent commit, and `agent_merge`
  PR handoff aligned with the corresponding `_shared/` fragments.

## Local commands

- Install the commands: `./install.sh`. It symlinks
  `.claude/commands/gw/` to `~/.claude/commands/gw/`.
- Remove only that symlink: `./uninstall.sh`.
- Check whether the installed checkout is behind its upstream: `./check-update.sh`.
  This command performs a network fetch and intentionally exits silently when
  the checkout cannot be located or the fetch times out.

## Validation

There is no project-level test runner or CI configuration in this checkout.
For changes to shell scripts, run:

```bash
bash -n check-update.sh install.sh uninstall.sh
```

For changes to command documentation, inspect the edited Markdown and ensure
the README's exposed-command list remains consistent.
