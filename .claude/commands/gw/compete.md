---
name: compete
description: Competitive feature analysis with structured team debate, TDD test scaffolds, and implementation planning
argument-hint: "[--deep] [--refresh] [--skip-pptx] [--skip-planning] [--skip-gsd] [--skip-tests] [--team auto|ask|N] [--add \"Competitor\"] [--remove \"Competitor\"] [--list] [--no-branch]"
---

## Step 0 — Preamble

Resolve the gw-skills repo path, then read and follow `$GW_REPO/.claude/commands/gw/_shared/preamble.md` for update check and GSD project detection:

```bash
GW_REPO="$(cd "$(readlink ~/.claude/commands/gw)/../../.." 2>/dev/null && pwd)" || GW_REPO="$HOME/.gw-skills"
```

GW_REPO persists for the duration of this skill run — do not re-resolve it in later steps.

---

## Step 0.5 — Branch Isolation

Set `SKILL_NAME="compete"`.

Read and follow `$GW_REPO/.claude/commands/gw/_shared/branch-first.md` for branch creation.

---

## Step 1 — Parse Arguments & Route

You are an orchestrator for competitive feature analysis. You research competitors, assemble a team of diverse specialists for structured debate, and produce a prioritized feature implementation plan backed by TDD test scaffolds. Follow these steps precisely.

Parse the arguments: "$ARGUMENTS"

| Flag | Variable | Default | Notes |
|------|----------|---------|-------|
| `--deep` | DEEP_RESEARCH | false | |
| `--refresh` | FORCE_REFRESH | false | |
| `--skip-pptx` | SKIP_PPTX | false | |
| `--skip-planning` / `--skip-gsd` | SKIP_PLANNING | false | |
| `--skip-tests` | SKIP_TESTS | false | |
| `--team <N\|auto\|ask>` | TEAM_MODE, TEAM_SIZE_OVERRIDE | auto | N (number, clamped 3-10) sets TEAM_SIZE_OVERRIDE |
| `--add "Name"` | ADD_COMPETITOR | — | |
| `--remove "Name"` | REMOVE_COMPETITOR | — | |
| `--list` | LIST_COMPETITORS | false | |
| `--no-branch` | NO_BRANCH | false | Skip branch isolation (see Step 0.5) |
| `--hire` / `--fire` / `--roster` | — | — | Redirect: "Use `/gw:workforce`..." and **stop** |

## Workflow routing

Based on arguments and detected state, the workflow may skip steps:

| Condition | Steps executed |
|-----------|----------------|
| Default (full run) | 0 → 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9 → 10 → 11 → 12 |
| `--add/--remove/--list` | 0 → 1 → 3 (registry management only) |
| `--hire/--fire/--roster` | 0 → 1 (redirect to `/gw:workforce`) |
| `--skip-tests` | Skip Step 9 |
| `--skip-pptx` | Skip Step 11 |
| `--skip-planning` / `--skip-gsd` | Skip Step 12 |
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

## Step 4 — Research Phase

Launch one background research agent per competitor in a SINGLE message using the Agent tool with `run_in_background=true` and `subagent_type="general-purpose"`.

### Freshness Check

Before launching agents, check each competitor's existing research file at `.competitors/research/{COMPETITOR_SLUG}.md`. If the file exists and contains a date header:

- If research is **<7 days old** and `--refresh` is **not** set, ask: "Research for {name} is {N} days old. Re-use [enter], refresh [r], or skip [s]?"
  - **[enter]:** skip the agent for this competitor, use cached file
  - **[r]:** launch agent (ignore cache)
  - **[s]:** exclude this competitor from this run entirely
- If `--refresh` is set (FORCE_REFRESH=true), skip the freshness prompt and always re-research.

### Agent Prompt & Output

Read and follow `$GW_REPO/.claude/commands/gw/_shared/compete-research-agent.md` for the agent prompt template, output format, rate limit guard, and collection verification.

Set depth to `deep` if DEEP_RESEARCH is true, otherwise `lightweight`.

---

## Step 5 — Team Assembly

**Team suggestion table for this skill:**

| APP_TYPE | Suggested Team |
|----------|---------------|
| web | UX Specialist, UI Designer, Web Designer, Product Manager, Backend Engineer, End User Advocate |
| server | Software Architect, Backend Engineer, Performance Engineer, Security Engineer, DevOps Engineer |
| cli | Software Architect, UX Specialist, End User Advocate, Backend Engineer |
| mobile | UX Specialist, UI Designer, Performance Engineer, Security Engineer, Product Manager |
| library | Software Architect, Backend Engineer, QA Engineer, End User Advocate |
| saas | Product Manager, Business Analyst, UX Specialist, Security Engineer, Backend Engineer, Performance Engineer |

Context line for approval gate: `Project: {PROJECT_NAME}`

Read and follow `$GW_REPO/.claude/commands/gw/_shared/team-assembly.md` using the table above for team suggestions.

---

## Step 6 — Feature Matrix Generation

Read and follow `$GW_REPO/.claude/commands/gw/_shared/compete-feature-matrix.md` — section "Feature Matrix Generation" only. Use FEATURE_INVENTORY from Step 2 and research files from Step 4.

---

## Step 7 — Structured Debate

Read and follow `$GW_REPO/.claude/commands/gw/_shared/debate-rounds.md` with these compete-specific overrides:

- **RESEARCH_DIR** = `.competitors`
- **Research input:** each agent reads `.competitors/feature-matrix.json` (not individual research files)
- **Round 1 task override:** Instead of "formulate a position on the research question", each agent picks their TOP 5 features to implement, ranks them 1-5, explains why from their specialist perspective, flags "trap features" (attractive but a mistake to build now), and notes features missing from the matrix.
- **Round 1 output format override:** Replace "Position / Top Conclusions / Uncertainties / Recommendations / Risks" sections with:
  - **Top 5 Features to Implement** (numbered, each with "Why" and "Effort: Small/Medium/Large")
  - **Trap Features** (name + why it's a trap from this persona's perspective)
  - **Missing from Matrix** (features or dimensions not captured)
- **Round 2 task override:** Instead of "respond to disagreements about research conclusions", agents respond to disagreements about feature priority and trap status. "Updated Conclusions" becomes "Updated Rankings (if changed)".
- **Round 3 consensus format override:** Replace the generic consensus format with:

```markdown
# Debate Consensus

**Date:** {date}
**Team:** {N} specialists, 2 debate rounds
**Disagreements examined:** {N}

## Ranked Feature Recommendations

### Tier 1: Strong Consensus (implement)
| # | Feature | Consensus | Effort | Key Argument |
|---|---------|-----------|--------|-------------|
| 1 | {name} | 5/6 agree | Medium | {summary} |

### Tier 2: Moderate Consensus (consider)
(same table format)

### Tier 3: Contested (needs user decision)
| # | Feature | For | Against | Key Tension |
|---|---------|-----|---------|-------------|

## Trap Features (team consensus: avoid)
| Feature | Flagged By | Reason |
|---------|-----------|--------|

## Supervisor's Final Recommendation
{Narrative synthesis: what to build, what to skip, what order, and why.
Explicitly notes where the supervisor overruled minority positions and why.}
```

---

## Step 8 — Feature Selection Dialog

Present consensus to the user in this exact format:

```
Competitive Feature Analysis — Consensus Results

RECOMMENDED (strong consensus):
  1. [5/6 agree] Real-time editing        Effort: Large    Gap: competitive_gap
  2. [5/6 agree] API webhooks             Effort: Medium   Gap: competitive_gap
  3. [6/6 agree] Keyboard shortcuts       Effort: Small    Gap: competitive_gap

CONTESTED (split opinion):
  4. [3/6 agree] AI assistant             Effort: Large    Gap: opportunity
     FOR: Product Manager, UX Specialist, Business Analyst
     AGAINST: Woodworker ("bolted-on AI feels like particle board"),
              Backend Engineer ("maintenance burden"), Security Engineer ("data risk")
  5. [3/6 agree] Plugin ecosystem         Effort: Large    Gap: competitive_gap
     FOR: Software Architect, Backend Engineer, End User Advocate
     AGAINST: Product Manager ("scope creep"), QA Engineer ("testing nightmare")

TRAPS (team flagged as avoid):
  6. [1/6 agree] Blockchain integration   Effort: Large    Gap: opportunity
     "Nobody's asking for this" — End User Advocate

Select features to implement:
  All recommended [a], pick by number [1,2,4], select all [*], or review debate [r]?
```

Options:
- **[a]:** Select all Tier 1 (strong consensus) features
- **[1,2,4]:** Select specific features by number
- **[*]:** Select everything (including contested)
- **[r]:** Display the full debate transcripts for review, then re-prompt

Save selections to `.competitors/SELECTED.json`:
```json
{
  "date": "YYYY-MM-DD",
  "selected": [
    { "name": "Real-time editing", "consensus": "5/6", "effort": "Large" },
    { "name": "API webhooks", "consensus": "5/6", "effort": "Medium" }
  ],
  "deferred": [...],
  "rejected": [...]
}
```

**APPROVAL GATE — Do not proceed past this step without explicit user confirmation of feature selection.**

---

## Step 9 — Test Scaffold Generation

Skip if SKIP_TESTS is true.

Read and follow `$GW_REPO/.claude/commands/gw/_shared/compete-feature-matrix.md` — section "Test Scaffold Generation" only. Use the selected features from Step 8.

---

## Step 9.5 — Build Manifest (optional)

If SKIP_TESTS is true, skip this step.

Generate a build manifest from the selected features and their test scaffolds.

1. Read `SELECTED.json` from `.competitors/` for the user's chosen features
2. Read `CONSENSUS.md` from `.competitors/debate/` for success criteria
3. For each selected feature:
   - Set `name` to the feature slug
   - Set `description` from the feature's debate consensus summary
   - Collect test scaffold paths from `.competitors/tests/<feature-slug>-*-manifest.md`
   - Set `test_scaffolds` to the actual test file paths referenced in the manifest files
   - Extract `acceptance_tests` from the feature's success criteria in CONSENSUS.md
   - Set `dependencies` to empty (competitive features are independent additions)
4. Set `project` to `compete`
5. Set `tech_stack` by detecting the current project's stack
6. Write manifest to `.competitors/build-manifest.json`
7. Commit: `git add .competitors/build-manifest.json && git commit -m "feat: generate build manifest for competitive features"`

Ask:

```
Build manifest generated with <N> features (all Wave 1 — independent):
  - <feature-1> (<N> test scaffolds)
  - <feature-2> (<N> test scaffolds)
  ...

Execute TDD implementation in parallel worktrees? [y] / Generate manifest only [m] / Skip to report [s]
```

- `[y]`: invoke `/gw:worktree execute .competitors/build-manifest.json`
- `[m]`: tell user: "Manifest saved. Run `/gw:worktree execute .competitors/build-manifest.json` when ready."
- `[s]`: continue to Step 10

---

## Step 10 — Report Synthesis

Launch a single foreground synthesis agent (`subagent_type="general-purpose"`) that reads all artifacts:
- `.competitors/registry.json`
- `.competitors/research/*.md`
- `.competitors/feature-matrix.json`
- `.competitors/debate/CONSENSUS.md`
- `.competitors/SELECTED.json`
- `.competitors/tests/*-manifest.md`

Writes `.competitors/REPORT.md` with sections: Executive Summary (3-5 sentences), Feature Matrix table (Us vs each competitor with Gap Type), Competitive Position (Advantages, Critical Gaps, Opportunities, Traps to Avoid), Team Debate Summary (Consensus Features selected + Contested Features deferred), Test Coverage Plan (feature x test-type matrix with counts), and Implementation Roadmap (Phase 1: Quick Wins S-effort, Phase 2: Core Gaps M-L effort, Phase 3: Strategic Features L-XL effort). Each phase follows TDD: scaffolded tests exist, implementation makes them pass.

Header: `**Project:** {name} ({APP_TYPE}) | **Date:** {date} | **Competitors analyzed:** {N} | **Team:** {N} specialists, 3 debate rounds | **Research depth:** lightweight|deep`

---

## Step 11 — PowerPoint Generation

Skip if SKIP_PPTX is true.

Read and follow `$GW_REPO/.claude/commands/gw/_shared/compete-pptx-slides.md` for slide structure and execution. Input data comes from REPORT.md, feature matrix, consensus, and test manifests.

---

## Step 12 — Implementation Planning

Skip if SKIP_PLANNING is true.

Present the implementation options:

```
Competitive analysis complete. How would you like to proceed?
  [p] Superpowers — invoke superpowers:writing-plans from REPORT.md (recommended)
  [g] GSD — create project/milestone from competitive analysis
  [d] Done — handle implementation manually
```

**If [p] (default/recommended):** Tell the user: "Invoking superpowers:writing-plans. The plan will use `.competitors/REPORT.md` as the requirements source." Then invoke the Skill tool: `Skill(skill="superpowers:writing-plans")`. Each selected feature becomes a plan phase. Each phase starts with: "Make the scaffolded tests pass for {feature}."

**If [g]:** Check if `~/.claude/commands/gsd/` exists. If it does:
1. Check if `.planning/PROJECT.md` exists (GSD project already initialized).
   - **If yes (brownfield):** Automatically invoke `/gsd:new-milestone` and reference `.competitors/REPORT.md` as the requirements source.
   - **If no (greenfield):** Automatically invoke `/gsd:new-project` and reference `.competitors/REPORT.md` as the requirements source.
If GSD commands don't exist, say: "GSD not installed. Use [p] Superpowers instead, or find the full analysis in `.competitors/REPORT.md`."

**If [d]:** Say "Full analysis available in `.competitors/REPORT.md`." and continue.

---

## Step 12.5 — Persona Contribution

Skip this step if `CREATED_PERSONAS` is empty.

Present the created personas and offer to contribute them to gw-skills defaults. If the user selects `[y]`:

1. Save the current directory and branch
2. `cd $GW_REPO` and check for uncommitted changes (offer to stash)
3. Create branch: `persona/{slug}` (single) or `persona/batch-YYYY-MM-DD` (multiple)
4. Copy each `workforce/{slug}.md` to `workforce/_defaults/{slug}.md`
5. Stage, commit, push, and create PR via `gh pr create`
6. If stashed, `git stash pop`; return to original directory and branch
7. Print the PR URL

---

## Step 12.5 — Intent Commit & Auto-PR

Read and follow `$GW_REPO/.claude/commands/gw/_shared/intent-commit.md` to write and commit the `.gw-intent.md` file.

Then read and follow `$GW_REPO/.claude/commands/gw/_shared/auto-pr.md` to create a PR with the `agent_merge` label.

---

## Final — Session Summary

Read and follow `$GW_REPO/.claude/commands/gw/_shared/session-summary.md`.

Files specific to this skill:

```
  [new]   .competitors/registry.json
  [new]   .competitors/research/*.md
  [new]   .competitors/feature-matrix.json
  [new]   .competitors/debate/CONSENSUS.md
  [new]   .competitors/SELECTED.json
  [new]   .competitors/tests/**
  [new]   .competitors/REPORT.md
  [new]   docs/gw/compete-*.pptx                  (--skip-pptx to skip)
  [new]   build-manifest.json                      (--skip-planning to skip)
```

---

### Error handling

- If WebSearch/WebFetch fails during research: retry once, then mark competitor as "research incomplete" and continue
- If a debate agent fails: note as `[FAILED]` in status, supervisor synthesizes with available positions
- If `python-pptx` unavailable: suggest `pip install python-pptx` or `--skip-pptx`
- If GSD not installed: inform user, suggest superpowers:writing-plans as primary alternative, continue without GSD
- If workforce directory missing: create it with `mkdir -p`
- If user tries to `--fire` a default persona: reject with explanation
- If `--hire` name conflicts with existing persona: ask to overwrite or rename
- Never force-push or use destructive git operations without asking
