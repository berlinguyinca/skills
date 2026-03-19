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

For any `[FAILED]` entries, offer: "Retry failed research? [y/n]" — if yes, re-launch only the failed agents.

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

Parse frontmatter from each: `name`, `background`, `perspective`, `priorities`, `debate_style`.

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

Show this exact format:

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

If `--team N` was set, auto-size to N using the relevance order (still show for confirmation).

**APPROVAL GATE — Stop and wait for user confirmation before proceeding to Step 6.**

### Workforce management commands

For `--hire`:
1. Slugify the name (e.g., "Mass Spectrometrist" → `mass-spectrometrist`)
2. Create `$GW_REPO/workforce/mass-spectrometrist.md` with frontmatter:
   - `name`: from --hire flag
   - `background`: from --background flag
   - `perspective`: auto-derived from background (key concerns and viewpoint)
   - `priorities`: auto-derived (what this persona cares most about)
   - `debate_style`: auto-derived (how they argue and what evidence they cite)
3. Print: "Hired {Name}. Available in all future `/gw:compete` runs."

For `--fire`:
1. Find matching file in `$GW_REPO/workforce/` (NOT `_defaults/`)
2. Delete the file
3. Print: "Removed {Name} from workforce."
4. If user tries to fire a default persona: "Can't fire default personas. They ship with the skill."

For `--roster`:
List all personas grouped by source:

```
Workforce Roster ({N} personas):
  [default] Software Architect — System design, scalability, technical debt
  [default] UX Specialist — User flows, friction, accessibility
  ...
  [custom]  Woodworker — Craftsmanship, ergonomics, "does it feel right"
  [custom]  Mass Spectrometrist — Data precision, calibration, scientific defensibility
```

End with `---` separator.

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

Then launch all team agents again in parallel with a prompt containing:
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
