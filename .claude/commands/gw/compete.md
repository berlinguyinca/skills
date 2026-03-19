---
name: compete
description: Competitive feature analysis with structured team debate, TDD test scaffolds, and implementation planning
argument-hint: "[--deep] [--hire \"Name\" --background \"...\"] [--fire \"Name\"] [--roster] [--refresh] [--skip-pptx] [--skip-gsd] [--skip-tests] [--team N] [--add \"Competitor\"] [--remove \"Competitor\"] [--list]"
---

## Step 0 — Update check

Resolve the gw-skills repo directory and run its update check script:

```bash
GW_REPO="$(cd "$(readlink ~/.claude/commands/gw)/../../.." 2>/dev/null && pwd)" || GW_REPO="$HOME/.gw-skills"
bash "$GW_REPO/check-update.sh" 2>/dev/null || true
```

If the output contains `UPDATE_AVAILABLE`, tell the user how many commits behind they are and ask: "gw-skills has updates available. Run /gw:update to install them, or continue?" If they want to update, invoke `/gw:update` and stop. Otherwise continue. If the script is missing or fails, skip silently.

---

You are an orchestrator for competitive feature analysis. You research competitors, assemble a team of diverse specialists for structured debate, and produce a prioritized feature implementation plan backed by TDD test scaffolds. Follow these steps precisely.

Parse the arguments: "$ARGUMENTS"
- If "--deep" is present, set DEEP_RESEARCH=true. Default: false
- If "--hire \"Name\" --background \"...\"" is present, set HIRE_NAME and HIRE_BACKGROUND
- If "--fire \"Name\"" is present, set FIRE_NAME
- If "--roster" is present, set SHOW_ROSTER=true
- If "--refresh" is present, set FORCE_REFRESH=true
- If "--skip-pptx" is present, set SKIP_PPTX=true
- If "--skip-gsd" is present, set SKIP_GSD=true
- If "--skip-tests" is present, set SKIP_TESTS=true
- If "--team N" is present, set TEAM_SIZE_OVERRIDE=N (clamped to 3-10)
- If "--add \"Name\"" is present, set ADD_COMPETITOR
- If "--remove \"Name\"" is present, set REMOVE_COMPETITOR
- If "--list" is present, set LIST_COMPETITORS=true

## Workflow routing

Based on arguments and detected state, the workflow may skip steps:

| Condition | Steps executed |
|-----------|----------------|
| Default (full run) | 0 → 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9 → 10 → 11 → 12 |
| `--add/--remove/--list` | 0 → 1 → 3 (registry management only) |
| `--hire/--fire/--roster` | 0 → 1 (workforce management only) |
| `--skip-tests` | Skip Step 9 |
| `--skip-pptx` | Skip Step 11 |
| `--skip-gsd` | Skip Step 12 |
| `--refresh` | Step 4 ignores cached research |
| Registry exists + research cached | Step 3 asks "use existing? refresh? add more?" |

**Approval gates** (stop and wait for user confirmation):
- After Step 3 — confirm competitor list before expensive research
- After Step 5 — confirm team composition before spawning debate agents
- After Step 8 — confirm feature selection before test generation
