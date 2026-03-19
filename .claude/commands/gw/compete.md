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

---

## Step 2 — Project Detection

### 2a. Stack detection

Auto-detect the stack by globbing for these files (run all globs in parallel):
- `package.json` (Node/JS/TS — read it to find framework: React, Vue, Next, Angular, Svelte, Electron, React Native, etc.)
- `pyproject.toml`, `requirements.txt`, `Pipfile` (Python — check for Flask, Django, FastAPI, Click, Typer, etc.)
- `go.mod` (Go — check for net/http, gin, cobra, etc.)
- `Cargo.toml` (Rust — check for actix, rocket, clap, etc.)
- `*.tf` files (Terraform/IaC)
- `docker-compose.yml`, `Dockerfile`
- `*.csproj`, `*.sln` (C#/.NET)
- `Gemfile` (Ruby — check for Rails, Sinatra, etc.)
- `pubspec.yaml` (Dart/Flutter)
- `*.xcodeproj`, `*.xcworkspace` (iOS)
- `AndroidManifest.xml`, `build.gradle` (Android)

Read `README.md` and `CLAUDE.md` if they exist (in parallel). These provide project context.

### 2b. Determine APP_TYPE

If no type was forced via arguments, classify using these rules:

| Detected Signals | APP_TYPE |
|---|---|
| React, Vue, Angular, Svelte, Next.js, Vite with HTML/CSS, Tailwind, frontend framework + optional backend | **web** |
| FastAPI, Flask, Django, Express, Gin, Rails, .NET API without significant frontend | **server** |
| Click, Typer, Cobra, clap, argparse, `console_scripts`, `bin/` executables, no web framework | **cli** |
| React Native, Flutter, Swift/iOS, Kotlin/Android, Expo | **mobile** |
| `setup.py`/`pyproject.toml` with library metadata, no entry point, published to npm/PyPI/crates.io | **library** |
| Mixed frontend + backend | **web** (default for full-stack) |

### 2c. Build FEATURE_INVENTORY

Scan the project for existing features:
- **Route definitions:** grep for route patterns (`@app.route`, `router.get`, `app.Get`, etc.)
- **API endpoints:** grep for HTTP method decorators and handler registrations
- **CLI commands:** grep for command definitions (`@click.command`, `cobra.Command`, etc.)
- **UI components:** glob for component files in `src/components/`, `app/`, `pages/`, etc.
- **Database models:** grep for model/schema definitions (ORM models, SQL schemas, Prisma schema, etc.)
- **Config options:** check for settings files, env vars, feature flags

This inventory becomes "what we already have" for the feature matrix comparison.

### 2d. Build STACK_CONTEXT

Build STACK_CONTEXT containing: detected stack info, APP_TYPE, file count, project size, key file paths, and any relevant excerpts from CLAUDE.md/README.md. Keep it under 500 words.

---

## Step 3 — Competitor Registry

### 3a. Auto-detection

Scan for competitor signals in parallel:

| Source | Detection Method |
|--------|-----------------|
| README.md | Grep for "alternative to", "inspired by", "compared to", "vs", competitor names |
| package.json / pyproject.toml | Check for SDKs/integrations that imply a competitive space (e.g., `stripe` → payment space) |
| Marketing copy | Scan `landing/`, `marketing/`, `docs/` directories for competitor mentions |
| `.competitors/registry.json` | Load previously registered competitors |

### 3b. Present & confirm

Present findings and wait for user confirmation:

```
Detected competitors for {project_name} ({APP_TYPE}):
  1. [AUTO] Notion     — mentioned in README.md ("alternative to Notion")
  2. [AUTO] Coda       — mentioned in README.md
  3. [REGISTERED] Obsidian  — from registry

Add more [a], remove [r], confirm and research [enter]?
```

- **Add more [a]:** user types competitor names, added to the list
- **Remove [r]:** user picks numbers to remove
- **Confirm [enter]:** proceed to research with the current list

**APPROVAL GATE — Stop and wait for user confirmation before proceeding to Step 4.**

### 3c. Save registry

Write/update `.competitors/registry.json` (create `.competitors/` directory if it doesn't exist):

```json
{
  "project": "{project_name}",
  "app_type": "{APP_TYPE}",
  "competitors": [
    { "name": "Notion", "source": "auto:README.md", "added": "2026-03-18" },
    { "name": "Obsidian", "source": "manual", "added": "2026-03-15" }
  ]
}
```

For `--add`/`--remove`/`--list`: skip 3a and 3b, go directly to registry management and stop.

- **`--add "Name"`:** Create `.competitors/` if needed, add entry to registry.json with `"source": "manual"` and today's date. Print: "Added {Name} to competitor registry."
- **`--remove "Name"`:** Find and remove entry from registry.json. Print: "Removed {Name} from competitor registry."
- **`--list`:** Read and display registry.json contents as a formatted table. If no registry exists, print: "No competitors registered. Run `/gw:compete --add \"Name\"` or run a full analysis."

---
