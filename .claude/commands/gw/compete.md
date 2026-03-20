---
name: compete
description: Competitive feature analysis with structured team debate, TDD test scaffolds, and implementation planning
argument-hint: "[--deep] [--refresh] [--skip-pptx] [--skip-gsd] [--skip-tests] [--team auto|ask|N] [--add \"Competitor\"] [--remove \"Competitor\"] [--list]"
---

## Step 0 — Update check

Resolve the gw-skills repo directory and run its update check script:

```bash
GW_REPO="$(cd "$(readlink ~/.claude/commands/gw)/../../.." 2>/dev/null && pwd)" || GW_REPO="$HOME/.gw-skills"
bash "$GW_REPO/check-update.sh" 2>/dev/null || true
```

If the output contains `UPDATE_AVAILABLE`, tell the user how many commits behind they are and ask: "gw-skills has updates available. Run /gw:update to install them, or continue?" If they want to update, invoke `/gw:update` and stop. Otherwise continue. If the script is missing or fails, skip silently.

---

## Step 0.5 — GSD Project Detection (Model Inheritance)

Skip this step if you are inside a GSD project (`~/.config/opencode/.planning/` exists).

If `.planning/config.json` exists in the current or parent directories:
1. Try to resolve and read its JSON content using Bash/Grep
2. Extract `model_profile` (default: "balanced")
3. If a profile is found, use it for all agent spawns instead of default Claude model
4. Log: "Using GSD model profile: {profile}" in the first output message

This enables gw skills to inherit opencode's model preferences within managed projects.

---

## Step 1 — Parse Arguments & Route

You are an orchestrator for competitive feature analysis. You research competitors, assemble a team of diverse specialists for structured debate, and produce a prioritized feature implementation plan backed by TDD test scaffolds. Follow these steps precisely.

Parse the arguments: "$ARGUMENTS"
- If "--deep" is present, set DEEP_RESEARCH=true. Default: false
- If "--hire", "--fire", or "--roster" is present: tell the user "Use `/gw:workforce` for persona management. Examples: `/gw:workforce --hire \"Name\" --background \"...\"`, `/gw:workforce --fire \"Name\"`, `/gw:workforce --roster`" and stop.
- If "--refresh" is present, set FORCE_REFRESH=true
- If "--skip-pptx" is present, set SKIP_PPTX=true
- If "--skip-gsd" is present, set SKIP_GSD=true
- If "--skip-tests" is present, set SKIP_TESTS=true
- If "--team N|auto|ask" is present: if N is a number, set TEAM_MODE=auto and TEAM_SIZE_OVERRIDE=N (clamped to 3-10). If "auto", set TEAM_MODE=auto. If "ask", set TEAM_MODE=ask. Default TEAM_MODE: auto
- If "--add \"Name\"" is present, set ADD_COMPETITOR
- If "--remove \"Name\"" is present, set REMOVE_COMPETITOR
- If "--list" is present, set LIST_COMPETITORS=true

## Workflow routing

Based on arguments and detected state, the workflow may skip steps:

| Condition | Steps executed |
|-----------|----------------|
| Default (full run) | 0 → 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9 → 10 → 11 → 12 |
| `--add/--remove/--list` | 0 → 1 → 3 (registry management only) |
| `--hire/--fire/--roster` | 0 → 1 (redirect to `/gw:workforce`) |
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

## Step 4 — Research Phase

Launch one background research agent per competitor in a SINGLE message using the Agent tool with `run_in_background=true` and `subagent_type="general-purpose"`.

### Freshness Check

Before launching agents, check each competitor's existing research file at `.competitors/research/{COMPETITOR_SLUG}.md`. If the file exists and contains a date header:

- If research is **<7 days old** and `--refresh` is **not** set, ask: "Research for {name} is {N} days old. Re-use [enter], refresh [r], or skip [s]?"
  - **[enter]:** skip the agent for this competitor, use cached file
  - **[r]:** launch agent (ignore cache)
  - **[s]:** exclude this competitor from this run entirely
- If `--refresh` is set (FORCE_REFRESH=true), skip the freshness prompt and always re-research.

### Agent Prompt Template

For each competitor that needs research, launch an agent with the following prompt (substituting the placeholders):

```
You are a competitive research analyst investigating {COMPETITOR_NAME}.

Research depth: {lightweight|deep}

## LIGHTWEIGHT TASKS (always perform these)

1. WebSearch for: "{COMPETITOR_NAME} official site", "{COMPETITOR_NAME} features", "{COMPETITOR_NAME} pricing", "{COMPETITOR_NAME} changelog", "{COMPETITOR_NAME} API docs"
2. WebFetch the top 3-5 most relevant pages from the search results (official site, features page, pricing page, changelog, API/developer docs).
3. Extract and record:
   - Complete feature list (every feature you can find, with brief descriptions)
   - Pricing tiers (name, price, currency, billing period, key limits/inclusions)
   - Tech stack (only if publicly disclosed — do not guess)
   - Integrations and supported platforms
   - Recent changes (last 3-6 months of changelog entries or release notes)

## DEEP TASKS (only if depth=deep)

4. WebSearch for: '"{COMPETITOR_NAME} vs" site:reddit.com', Hacker News discussions mentioning {COMPETITOR_NAME}, G2/Capterra/ProductHunt reviews for {COMPETITOR_NAME}, '"{COMPETITOR_NAME} alternative"' blog comparisons.
5. WebFetch the top 3-5 most relevant community/review pages.
6. Extract and record:
   - User complaints and pain points (with source URLs and vote/upvote counts where visible)
   - Feature requests that appear repeatedly
   - Reasons users cite for switching away from {COMPETITOR_NAME}
   - Genuine praise and strengths users highlight

## RULES

- Be thorough but strictly factual — cite a source URL for every claim.
- Clearly distinguish **confirmed** features (found on official site/docs) from **rumored** or **community-reported** features.
- Always note the currency and retrieval date for pricing information.
- For community sentiment, include vote counts or engagement signals where available.

## OUTPUT

Write your findings to: `.competitors/research/{COMPETITOR_SLUG}.md`

Use this exact format:

---
competitor: {COMPETITOR_NAME}
researched: {TODAY_DATE}
depth: {lightweight|deep}
sources_count: {N}
---

# {COMPETITOR_NAME} — Competitive Research

## Features

| Feature | Description | Confirmed? | Source |
|---------|-------------|------------|--------|
| ...     | ...         | Yes/No     | URL    |

## Pricing

| Tier | Price | Billing | Key Limits | Source |
|------|-------|---------|------------|--------|
| ...  | ...   | ...     | ...        | URL    |

(Currency: {USD/EUR/etc.} — prices as of {TODAY_DATE})

## Tech Stack (Public)

- ...

## Integrations

- ...

## Recent Changes

- {DATE}: {change description} — {source URL}

## Community Sentiment

(Included only for depth=deep)

### Pain Points

- "{quote or paraphrase}" — {source URL} ({vote count} upvotes)

### Praise

- "{quote or paraphrase}" — {source URL} ({vote count} upvotes)

### Feature Requests

- "{request}" — {source URL} (mentioned {N} times)
```

### Rate Limit Guard

If any WebSearch or WebFetch call returns an error (rate limit, timeout, or access denied):
1. Retry once after a short backoff (~5 seconds).
2. If the retry also fails, note `"research incomplete — {reason}"` in the output file and continue writing whatever was collected so far.
3. Do not abort the entire research run due to a single tool failure.

### Collection

After all background agents complete, verify that each expected research file exists at `.competitors/research/*.md`. Print a status table:

```
Research Status:
  [done] notion.md          (42 features, 4 tiers, 12 sources)
  [done] coda.md            (38 features, 3 tiers, 8 sources)
  [FAILED] obsidian.md      (research incomplete — rate limited)
```

For any `[FAILED]` entries, offer: "Retry failed research? [y/n]" — if yes, re-launch only the failed agents. Max 2 retries per failed agent. After 2 failures for the same agent, continue with available reports.

---

## Step 5 — Team Assembly

### 5a. Load workforce

Resolve the gw-skills repo path (same pattern as Step 0):

```bash
GW_REPO="$(cd "$(readlink ~/.claude/commands/gw)/../../.." 2>/dev/null && pwd)" || GW_REPO="$HOME/.gw-skills"
```

Read all persona files from:
1. `$GW_REPO/workforce/_defaults/*.md` — pre-shipped personas
2. `$GW_REPO/workforce/*.md` (excluding `_defaults/`) — user-added personas

Parse frontmatter from each: `name`, `background`, `perspective`, `priorities`, `debate_style`, `search_skills`.

### 5b. Suggest team composition

Based on APP_TYPE, suggest the best subset. Use this table:

| APP_TYPE | Suggested Team |
|----------|---------------|
| web | UX Specialist, UI Designer, Web Designer, Product Manager, Backend Engineer, End User Advocate |
| server | Software Architect, Backend Engineer, Performance Engineer, Security Engineer, DevOps Engineer |
| cli | Software Architect, UX Specialist, End User Advocate, Backend Engineer |
| mobile | UX Specialist, UI Designer, Performance Engineer, Security Engineer, Product Manager |
| library | Software Architect, Backend Engineer, QA Engineer, End User Advocate |
| saas | Product Manager, Business Analyst, UX Specialist, Security Engineer, Backend Engineer, Performance Engineer |

Custom personas are always shown as available additions.

### 5c. Approval gate

**If TEAM_MODE is "auto" (default):** Skip the gate — auto-proceed with the suggested team. Print a brief summary:

```
Team ({N} specialists): {Name1}, {Name2}, {Name3}, ... — auto-proceeding (use --team ask for interactive selection)
```

**If TEAM_MODE is "ask":** Show this exact format and wait for user confirmation:

```
Project: {project_name} ({APP_TYPE}, {file_count} files)

Suggested team ({N} specialists):
  1. UX Specialist        [recommended]
  2. Product Manager       [recommended]
  3. Backend Engineer      [recommended]
  ...

Also available:
  7. Software Architect
  8. Woodworker (custom)
  9. Mass Spectrometrist (custom)
  ...

Accept [enter], resize [N], add by number [+7,8], or customize [c]?
```

Explain each option:
- **Accept:** proceed with suggested team
- **Resize [N]:** adjust team size (add/remove from relevance order)
- **Add [+N,N]:** add specific personas to the suggested team
- **Customize [c]:** show full roster, pick by number

**APPROVAL GATE — Stop and wait for user confirmation before proceeding to Step 6.**

---

## Step 6 — Feature Matrix Generation

Launch a single foreground agent (`subagent_type="general-purpose"`) with:
- The project's FEATURE_INVENTORY from Step 2
- All `.competitors/research/*.md` files
- Instruction to build a comprehensive feature-by-feature comparison

The agent writes `.competitors/feature-matrix.json`:
```json
{
  "generated": "YYYY-MM-DD",
  "project": "{project_name}",
  "competitors": ["Notion", "Coda", "Obsidian"],
  "categories": [
    {
      "name": "Collaboration",
      "features": [
        {
          "name": "Real-time editing",
          "our_status": "missing",
          "competitors": {
            "Notion": "full",
            "Coda": "full",
            "Obsidian": "missing"
          },
          "gap_type": "competitive_gap",
          "effort_estimate": "Large",
          "community_signal": "High demand on Reddit (340+ upvotes)"
        }
      ]
    }
  ]
}
```

Status values: `full`, `partial`, `missing`, `planned`
Gap types:
- `competitive_gap` — they have it, we don't
- `competitive_advantage` — we have it, they don't
- `parity` — everyone has it
- `opportunity` — nobody has it yet (from community pain points in deep mode)

Present the matrix to the user as a readable table before proceeding to debate.

---

## Step 7 — Structured Debate

Three rounds with the assembled team.

### Round 1 — Position Statements

Launch all team agents in parallel (`run_in_background=true`). Each agent gets a prompt with:
- Their persona details (name, background, perspective, priorities, debate_style)
- Project context ({PROJECT_NAME}, {APP_TYPE})
- Instruction to read `.competitors/feature-matrix.json`
- Tasks: pick top 5 features, rank 1-5, explain why from their perspective, flag trap features, note missing features
- Output to `.competitors/debate/round1/{PERSONA_SLUG}.md`
- Output format with sections: Top 5 Features to Implement (numbered, with Why and Effort assessment), Trap Features (with Why it's a trap), Missing from Matrix

Agent prompt template:

```
You are {PERSONA_NAME}, a specialist with the following profile:
- Background: {PERSONA_BACKGROUND}
- Perspective: {PERSONA_PERSPECTIVE}
- Priorities: {PERSONA_PRIORITIES}
- Debate style: {PERSONA_DEBATE_STYLE}

## Context

Project: {PROJECT_NAME} ({APP_TYPE})

## Your Task

1. Read the feature matrix at `.competitors/feature-matrix.json`.
2. From your perspective, pick the TOP 5 features to implement next.
3. Rank them 1-5 (1 = highest priority).
4. For each, explain WHY from your specialist viewpoint and assess implementation effort (Small / Medium / Large).
5. Flag any "trap features" — things that look attractive but you believe would be a mistake to build right now.
6. Note any features or dimensions that are MISSING from the matrix entirely.

## Output

Write your position to: `.competitors/debate/round1/{PERSONA_SLUG}.md`

Use this format:

---
persona: {PERSONA_NAME}
round: 1
date: {TODAY_DATE}
---

# Round 1 — Position Statement: {PERSONA_NAME}

## Top 5 Features to Implement

1. **{Feature Name}** (Effort: {Small|Medium|Large})
   - **Why:** {explanation from this persona's perspective}

2. **{Feature Name}** (Effort: {Small|Medium|Large})
   - **Why:** {explanation}

3. **{Feature Name}** (Effort: {Small|Medium|Large})
   - **Why:** {explanation}

4. **{Feature Name}** (Effort: {Small|Medium|Large})
   - **Why:** {explanation}

5. **{Feature Name}** (Effort: {Small|Medium|Large})
   - **Why:** {explanation}

## Trap Features

- **{Feature Name}:** {Why it's a trap from this persona's perspective}

## Missing from Matrix

- {Any feature or dimension not captured in the matrix that you believe matters}
```

After all agents complete, verify each file exists at `.competitors/debate/round1/{PERSONA_SLUG}.md`.

### Round 2 — Cross-Examination

The supervisor (orchestrator itself, acting as a foreground step) reads all Round 1 positions. Identifies the top 3-5 disagreements — features where agents strongly disagree on priority or trap status.

Then launch all team agents again in parallel (`run_in_background=true`) with a prompt containing:
- Their persona details
- All colleagues' Round 1 positions (concatenated)
- The identified disagreements with devil's advocate challenges
- A specific devil's advocate argument targeting THIS persona's Round 1 stance
- Tasks: respond to disagreements, defend or change position, note if any colleague changed their thinking
- Output to `.competitors/debate/round2/{PERSONA_SLUG}.md`

Agent prompt template:

```
You are {PERSONA_NAME}, a specialist with the following profile:
- Background: {PERSONA_BACKGROUND}
- Perspective: {PERSONA_PERSPECTIVE}
- Priorities: {PERSONA_PRIORITIES}
- Debate style: {PERSONA_DEBATE_STYLE}

## Context

Project: {PROJECT_NAME} ({APP_TYPE})

## Your Round 1 Position

(Your Round 1 file content is included below for reference.)

## Your Colleagues' Round 1 Positions

{CONCATENATED_ROUND1_POSITIONS_OF_ALL_OTHER_PERSONAS}

## Key Disagreements Identified by the Supervisor

{NUMBERED_LIST_OF_TOP_3_TO_5_DISAGREEMENTS}
Example:
1. Feature X — {PersonaA} ranked it #1; {PersonaB} called it a trap.
2. Feature Y — {PersonaC} and {PersonaD} disagree on effort (Small vs Large).

## Devil's Advocate Challenge (for you specifically)

{TARGETED_CHALLENGE_ARGUING_AGAINST_THIS_PERSONAS_ROUND1_STANCE}

## Your Task

1. Respond to the key disagreements above. Do you hold your position or update it? Be specific.
2. Address the devil's advocate challenge directed at you. Rebut, concede, or refine your stance.
3. Note if any colleague made an argument that genuinely changed your thinking (and explain how).
4. If you are updating any of your Top 5 rankings or trap designations, state the updated list explicitly.

## Output

Write your response to: `.competitors/debate/round2/{PERSONA_SLUG}.md`

Use this format:

---
persona: {PERSONA_NAME}
round: 2
date: {TODAY_DATE}
---

# Round 2 — Cross-Examination: {PERSONA_NAME}

## Response to Disagreements

### Disagreement 1: {Feature Name}
{Your response — hold, concede, or refine}

### Disagreement 2: {Feature Name}
{Your response}

(continue for each disagreement)

## Response to Devil's Advocate Challenge

{Your rebuttal or concession}

## Mind Changes

- {Feature or position you updated, and why} (or "None — I hold my Round 1 position.")

## Updated Rankings (if changed)

(List only if your Top 5 changed from Round 1; otherwise write "Unchanged.")
```

### Round 3 — Supervisor Synthesis

A single foreground supervisor agent reads ALL Round 1 + Round 2 files and writes `.competitors/debate/CONSENSUS.md` with this format:

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

For each selected feature, spawn specialist testing agents in parallel (`run_in_background=true`).

### Testing agent pool

| Agent | Responsibility | Output Pattern |
|-------|---------------|----------------|
| Unit Test Architect | Pure logic tests, isolated components | `tests/unit/feature-{slug}.test.{ext}` |
| Integration Test Architect | Cross-module, database, API contracts | `tests/integration/feature-{slug}.test.{ext}` |
| E2E Test Architect | Full user flows, happy + error paths | `tests/e2e/feature-{slug}.spec.{ext}` |
| Backend Test Architect | API endpoints, auth, data validation | `tests/backend/feature-{slug}.test.{ext}` |
| Stress Test Architect | Load, concurrency, resource limits | `tests/stress/feature-{slug}.test.{ext}` |
| Session Recorder | Playwright recorded user journeys (web only) | `tests/recorded/feature-{slug}.spec.{ext}` |

Not all agents apply to every project:

| APP_TYPE | Agents Used |
|----------|-------------|
| web | All 6 |
| server | Unit, Integration, Backend, Stress |
| cli | Unit, Integration, E2E |
| mobile | Unit, Integration, E2E |
| library | Unit, Integration, Stress |
| saas | All 6 |

### Agent prompt template

Include a code block with:
- Role: "You are a {TEST_SPECIALTY} generating TDD test scaffolds."
- Project context, stack context, feature name and description
- 8 rules: match existing test framework, real assertions, tests MUST FAIL (true TDD), descriptive names, cover happy/edge/error, web default to Vitest+Playwright, test API contracts for backend, define load parameters for stress
- Output: test files + manifest to `.competitors/tests/{FEATURE_SLUG}-{SPECIALTY}-manifest.md`

### Session Recorder specifics (web apps only)

- Generates Playwright test scripts with `page.goto()`, `page.click()`, `page.fill()`
- Includes `await expect(page).toHaveScreenshot()` for visual regression
- Scaffolds `playwright.config.ts` if not present
- Marks with `// RECORD: run with --headed to capture baseline`

### Commit test scaffolds

After all testing agents complete, check if the project is in a git repository: if `git rev-parse --git-dir 2>/dev/null` fails, tell the user: "Test scaffolds were written but not committed (not a git repository)." and skip the commit step.

Otherwise, ask the user: "Test scaffolds generated. Commit to the branch? [y/n]"

If yes:
```bash
git add tests/
git add .competitors/tests/
git commit -m "test: scaffold TDD tests for competitive features

Features: {comma-separated feature names}
Types: unit, integration, e2e, backend, stress, recorded
All tests designed to FAIL until features are implemented."
```

---

## Step 10 — Report Synthesis

Launch a single foreground synthesis agent (`subagent_type="general-purpose"`) that reads all artifacts:
- `.competitors/registry.json`
- `.competitors/research/*.md`
- `.competitors/feature-matrix.json`
- `.competitors/debate/CONSENSUS.md`
- `.competitors/SELECTED.json`
- `.competitors/tests/*-manifest.md`

Writes `.competitors/REPORT.md` with this template:

```markdown
# Competitive Analysis Report

**Project:** {name} ({APP_TYPE})
**Date:** {date}
**Competitors analyzed:** {N}
**Team:** {N} specialists, 3 debate rounds
**Research depth:** lightweight|deep

## Executive Summary
{3-5 sentences: competitive position, biggest gaps, biggest advantages, recommended strategy}

## Feature Matrix
| Feature | Us | {Competitor1} | {Competitor2} | Gap Type |
|---------|-----|---------------|---------------|----------|

## Competitive Position
### Our Advantages
{features where we lead, with evidence}
### Critical Gaps
{features competitors have that we don't}
### Opportunities
{features nobody has yet — from community signals}
### Traps to Avoid
{features the team flagged as not worth pursuing, with reasoning}

## Team Debate Summary
### Consensus Features (selected for implementation)
{ranked list with effort estimates and key reasoning}
### Contested Features (deferred)
{what was argued, why it was deferred, conditions under which to reconsider}

## Test Coverage Plan
| Feature | Unit | Integration | E2E | Backend | Stress | Recorded |
|---------|------|-------------|-----|---------|--------|----------|
| {name} | {N} | {N} | {N} | {N} | {N} | {N} |

## Implementation Roadmap
### Phase 1: Quick Wins — Effort: S
{Small-effort features with strong consensus}
### Phase 2: Core Gaps — Effort: M-L
{Medium-effort competitive gaps}
### Phase 3: Strategic Features — Effort: L-XL
{Large-effort features and opportunities}

Each phase follows TDD: scaffolded tests exist, implementation makes them pass.
```

---

## Step 11 — PowerPoint Generation

Skip if SKIP_PPTX is true.

### 11a. Build JSON data file

Write `/tmp/compete_presentation_data.json` with all data extracted from REPORT.md, feature matrix, consensus, and test manifests.

### 11b. Write and execute Python script

Write `/tmp/compete_presentation.py` — reads the JSON data file and generates a `.pptx` presentation.

**Design system** (canonical gw-skills palette):
```
PRIMARY      = RGBColor(0x2C, 0x3E, 0x50)  # dark blue-gray — titles, headers
SECONDARY    = RGBColor(0x34, 0x49, 0x5E)  # medium blue-gray — body text
ACCENT       = RGBColor(0x34, 0x98, 0xDB)  # bright blue — highlights, KPIs
SUCCESS      = RGBColor(0x27, 0xAE, 0x60)  # green — advantages, full status
DANGER       = RGBColor(0xE7, 0x4C, 0x3C)  # red — gaps, missing status
WARNING      = RGBColor(0xF3, 0x9C, 0x12)  # amber — partial status, contested
MUTED        = RGBColor(0x95, 0xA5, 0xA6)  # gray — captions, labels
BG_WHITE     = RGBColor(0xFF, 0xFF, 0xFF)
BG_LIGHT     = RGBColor(0xF8, 0xF9, 0xFA)
```

Font: Calibri throughout. Slide dimensions: 16:9 widescreen (13.333" x 7.5"). Accent bar: 0.06" wide ACCENT strip at left edge of every slide.

**Slide structure:**

| # | Slide | Content |
|---|-------|---------|
| 1 | Title | Project name, "Competitive Analysis", date, team size badge |
| 2 | Executive Summary | Competitive position verdict, key stats as KPI cards (N competitors, N features compared, N gaps, N advantages) |
| 3 | Feature Matrix | Color-coded table: green=full, amber=partial, red=missing, blue=planned |
| 4 | Competitive Advantages | Green cards with our strengths and evidence |
| 5 | Critical Gaps | Red cards with gap severity and which competitors have each feature |
| 6 | Opportunities | Blue cards for features nobody has yet (deep mode community signals) |
| 7 | Debate Highlights | Key disagreements: for/against summary with persona names |
| 8 | Selected Features | What we're building: effort badges, consensus scores, phase assignment |
| 9 | Test Coverage Plan | Matrix showing test count per type per feature |
| 10 | Implementation Roadmap | Phase timeline: horizontal cards Phase 1 → 2 → 3 with T-shirt effort badges |
| 11 | Closing | "Full report: `.competitors/REPORT.md`", date, "Generated by gw:compete" |

**Execution:**
```bash
mkdir -p docs/gw
uv run --with python-pptx python /tmp/compete_presentation.py
```

Fallback: `python3 -m pip install python-pptx && python3 /tmp/compete_presentation.py`

If both fail: "PowerPoint generation failed — python-pptx is required. Install it with `pip install python-pptx` or use `--skip-pptx` to skip presentation generation." Do not generate an HTML fallback.

**Output:** `docs/gw/compete-report-YYYY-MM-DD.pptx`

Tell the user where the file was saved. If the project is a git repo with uncommitted changes to the presentation file, ask: "Commit the presentation to the branch? [y/n]"

If yes:
```bash
git add docs/gw/compete-report-*.pptx
git commit -m "docs: add competitive analysis presentation"
```

---

## Step 12 — GSD Integration

Skip if SKIP_GSD is true.

Check if `~/.claude/commands/gsd/` exists. If it does:

1. Check if `.planning/PROJECT.md` exists (GSD project already initialized).
   - **If yes (brownfield):** Automatically invoke `/gsd:new-milestone` and reference `.competitors/REPORT.md` as the requirements source. Tell the user: "Creating a new GSD milestone from the competitive analysis roadmap."
   - **If no (greenfield):** Automatically invoke `/gsd:new-project` and reference `.competitors/REPORT.md` as the requirements source. Tell the user: "Creating a GSD project from the competitive analysis roadmap."

Each selected feature becomes a GSD phase. Each phase starts with: "Make the scaffolded tests pass for {feature}."

If GSD commands don't exist, say: "Full analysis available in `.competitors/REPORT.md`. Install GSD to auto-create a project from these phases." and stop.

### Error handling

- If WebSearch/WebFetch fails during research: retry once, then mark competitor as "research incomplete" and continue
- If a debate agent fails: note as `[FAILED]` in status, supervisor synthesizes with available positions
- If `python-pptx` unavailable: suggest `pip install python-pptx` or `--skip-pptx`
- If GSD not installed: inform user, continue without GSD
- If workforce directory missing: create it with `mkdir -p`
- If user tries to `--fire` a default persona: reject with explanation
- If `--hire` name conflicts with existing persona: ask to overwrite or rename
- Never force-push or use destructive git operations without asking
