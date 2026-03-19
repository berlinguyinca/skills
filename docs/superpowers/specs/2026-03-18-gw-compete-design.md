# Design Spec: `gw:compete` — Competitive Feature Analysis Skill

**Date:** 2026-03-18
**Status:** Draft
**Skill name:** `gw:compete`
**File:** `.claude/commands/gw/compete.md`
**Approach:** Skill + Workforce Module (Approach B)

---

## Overview

A gw-skill that maintains a project-local competitor registry, researches competitor features using parallel agents, assembles a configurable team of diverse personas (the "workforce") for structured debate, and produces a prioritized feature implementation plan backed by TDD test scaffolds, a PowerPoint presentation, and GSD integration.

The workforce persists globally in the gw-skills repo (`workforce/` directory), growing over time as the user hires new personas via the CLI. The competitor registry and research cache are project-local (`.competitors/`).

---

## Skill Interface

```
/gw:compete [--deep] [--hire "Name" --background "..."] [--fire "Name"]
            [--roster] [--refresh] [--skip-pptx] [--skip-gsd] [--skip-tests]
            [--team N] [--add "Competitor"] [--remove "Competitor"] [--list]
```

### Modes

| Command | Behavior |
|---------|----------|
| `/gw:compete` | Full run: detect/research competitors, assemble team, debate, plan |
| `/gw:compete --add "Notion"` | Register a competitor, skip analysis |
| `/gw:compete --remove "Notion"` | Remove a competitor |
| `/gw:compete --list` | Show registered competitors |
| `/gw:compete --hire "Woodworker" --background "..."` | Add persona to global workforce |
| `/gw:compete --fire "Woodworker"` | Remove persona from workforce |
| `/gw:compete --roster` | Show all available personas (defaults + custom) |
| `/gw:compete --deep` | Enable deep research (forums, community crawl) |
| `/gw:compete --refresh` | Force re-research even if cache <7 days old |
| `/gw:compete --team 5` | Override suggested team size |

### Argument Parsing

Parse from `"$ARGUMENTS"`:
- `--deep` → DEEP_RESEARCH=true (default: false)
- `--hire "Name" --background "..."` → HIRE_NAME, HIRE_BACKGROUND
- `--fire "Name"` → FIRE_NAME
- `--roster` → SHOW_ROSTER=true
- `--refresh` → FORCE_REFRESH=true
- `--skip-pptx` → SKIP_PPTX=true
- `--skip-gsd` → SKIP_GSD=true
- `--skip-tests` → SKIP_TESTS=true
- `--team N` → TEAM_SIZE_OVERRIDE=N (clamped 3-10)
- `--add "Name"` → ADD_COMPETITOR
- `--remove "Name"` → REMOVE_COMPETITOR
- `--list` → LIST_COMPETITORS=true

---

## File Locations

| Path | Scope | Purpose |
|------|-------|---------|
| `.competitors/registry.json` | Project-local | Registered competitors with metadata |
| `.competitors/research/{slug}.md` | Project-local | Per-competitor research findings |
| `.competitors/feature-matrix.json` | Project-local | Structured feature comparison |
| `.competitors/debate/round1/{slug}.md` | Project-local | Round 1 position statements |
| `.competitors/debate/round2/{slug}.md` | Project-local | Round 2 cross-examination responses |
| `.competitors/debate/CONSENSUS.md` | Project-local | Supervisor synthesis |
| `.competitors/SELECTED.json` | Project-local | User's feature selections |
| `.competitors/tests/{feature}-manifest.md` | Project-local | Test manifests per feature |
| `.competitors/REPORT.md` | Project-local | Final synthesis report |
| `docs/gw/compete-report-YYYY-MM-DD.pptx` | Project-local | PowerPoint presentation |
| `workforce/_defaults/*.md` | Global (gw-skills repo) | Pre-shipped personas |
| `workforce/*.md` (non-_defaults) | Global (gw-skills repo) | User-added personas |

---

## Step Structure

### Step 0 — Update Check

Standard gw-skills update check pattern:
```bash
GW_REPO="$(cd "$(readlink ~/.claude/commands/gw)/../../.." 2>/dev/null && pwd)" || GW_REPO="$HOME/.gw-skills"
bash "$GW_REPO/check-update.sh" 2>/dev/null || true
```

### Step 1 — Parse Arguments & Route

Parse all flags. Route based on mode:

| Condition | Steps Executed |
|-----------|----------------|
| Default (full run) | 0 → 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9 → 10 → 11 → 12 |
| `--add/--remove/--list` | 0 → 1 → 3 (registry management only) |
| `--hire/--fire/--roster` | 0 → 1 (workforce management only) |
| `--skip-tests` | Skip Step 9 |
| `--skip-pptx` | Skip Step 11 |
| `--skip-gsd` | Skip Step 12 |
| `--refresh` | Step 4 ignores cached research |
| Registry + research cached | Step 3 asks "use existing? refresh? add more?" |

**Approval gates:**
- After Step 3 — confirm competitor list before expensive research
- After Step 5 — confirm team composition before spawning debate agents
- After Step 8 — confirm feature selection before test generation

### Step 2 — Project Detection

Reuses the analyze-app detection pattern:

1. **Stack detection:** Glob for `package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml`, `*.tf`, `docker-compose.yml`, `Dockerfile`, `*.csproj`, `Gemfile`, `pubspec.yaml`, etc.
2. **Read context:** `README.md`, `CLAUDE.md` if they exist.
3. **Determine APP_TYPE:** web, server, cli, mobile, library, saas (same rules as analyze-app).
4. **Build FEATURE_INVENTORY:** Scan for route definitions, API endpoints, CLI commands, UI components, database models, config options. This becomes "what we already have."
5. **Build STACK_CONTEXT:** Detected stack, file count, APP_TYPE, key file paths, relevant excerpts. Keep under 500 words.

### Step 3 — Competitor Registry

#### 3a. Auto-detection

Scan for competitor signals in parallel:

| Source | Detection Method |
|--------|-----------------|
| README.md | Grep for "alternative to", "inspired by", "compared to", "vs", competitor names |
| package.json / pyproject.toml | Check for SDKs/integrations that imply a competitive space |
| Marketing copy | Scan `landing/`, `marketing/`, `docs/` directories for competitor mentions |
| `.competitors/registry.json` | Load previously registered competitors |

#### 3b. Present & confirm

```
Detected competitors for {project_name} ({APP_TYPE}):
  1. [AUTO] Notion     — mentioned in README.md ("alternative to Notion")
  2. [AUTO] Coda       — mentioned in README.md
  3. [REGISTERED] Obsidian  — from registry

Add more [a], remove [r], confirm and research [enter]?
```

#### 3c. Save registry

Write/update `.competitors/registry.json`:
```json
{
  "project": "my-app",
  "app_type": "web",
  "competitors": [
    { "name": "Notion", "source": "auto:README.md", "added": "2026-03-18" },
    { "name": "Obsidian", "source": "manual", "added": "2026-03-15" }
  ]
}
```

For `--add`/`--remove`/`--list`: skip 3a and 3b, go directly to registry management and stop.

### Step 4 — Research Phase

Launch one background research agent per competitor in a SINGLE message (all parallel, `run_in_background=true`, `subagent_type="general-purpose"`).

#### Agent prompt template

```
You are a competitive research analyst investigating {COMPETITOR_NAME}.

Research depth: {lightweight|deep}

LIGHTWEIGHT TASKS (always):
- WebSearch for official site, features page, pricing page, changelog, API docs
- WebFetch on the top 3-5 most relevant pages
- Extract: feature list, pricing tiers, tech stack (if public), integrations, recent changes

DEEP TASKS (only if depth=deep):
- WebSearch for "{COMPETITOR_NAME} vs" site:reddit.com
- WebSearch for "{COMPETITOR_NAME}" site:news.ycombinator.com
- WebSearch for "{COMPETITOR_NAME} review" on G2, Capterra, ProductHunt
- WebSearch for "{COMPETITOR_NAME} alternative" blog comparisons
- Extract: user complaints, feature requests, pain points, switching reasons, praise

RULES:
- Be thorough but factual — cite sources for every claim
- Distinguish between confirmed features and rumored/beta features
- Note pricing currency and date (pricing changes frequently)
- For community sentiment, include vote counts or engagement metrics

Write your findings to .competitors/research/{COMPETITOR_SLUG}.md in this format:

# {Competitor Name} — Competitive Research

**Date:** {today}
**Depth:** {lightweight|deep}
**Sources:** {N} pages crawled

## Features
{categorized feature list}

## Pricing
| Tier | Price | Key Limits |
|------|-------|------------|

## Tech Stack (public)
{if discoverable}

## Integrations
{list of integrations/ecosystem}

## Recent Changes
{changelog highlights from last 6 months}

## Community Sentiment (deep only)
### Pain Points
{complaints with source and engagement}
### Praise
{positive feedback with source}
### Feature Requests
{what users are asking for}
```

**Rate limit guard:** If WebSearch/WebFetch returns errors, retry once with backoff. If still failing, note "research incomplete" and continue.

**Freshness:** Research files include date. On subsequent runs, if <7 days old and `--refresh` is not set, ask: "Research for {name} is {N} days old. Re-use [enter], refresh [r], or skip [s]?"

#### Collection

After all agents complete, verify each `.competitors/research/*.md` exists. Print status:
```
Research Status:
  [done] notion.md          (42 features, 4 tiers, 12 sources)
  [done] coda.md            (38 features, 3 tiers, 8 sources)
  [FAILED] obsidian.md      (research incomplete — rate limited)
```

### Step 5 — Team Assembly

#### 5a. Load workforce

Resolve the gw-skills repo path (same pattern as Step 0). Read all persona files from:
1. `$GW_REPO/workforce/_defaults/*.md` — pre-shipped personas
2. `$GW_REPO/workforce/*.md` (excluding `_defaults/`) — user-added personas

Parse frontmatter from each: `name`, `background`, `perspective`, `priorities`, `debate_style`.

#### 5b. Suggest team composition

Based on APP_TYPE, suggest the best subset:

| APP_TYPE | Suggested Team |
|----------|---------------|
| web | UX Specialist, UI Designer, Web Designer, Product Manager, Backend Engineer, End User Advocate |
| server | Software Architect, Backend Engineer, Performance Engineer, Security Engineer, DevOps Engineer |
| cli | Software Architect, UX Specialist, End User Advocate, Backend Engineer |
| mobile | UX Specialist, UI Designer, Performance Engineer, Security Engineer, Product Manager |
| library | Software Architect, Backend Engineer, QA Engineer, End User Advocate |
| saas | Product Manager, Business Analyst, UX Specialist, Security Engineer, Backend Engineer, Performance Engineer |

Custom personas are always shown as available additions.

#### 5c. Approval gate

```
Project: my-app (web, 180 files)

Suggested team (6 specialists):
  1. UX Specialist        [recommended]
  2. Product Manager       [recommended]
  3. Backend Engineer      [recommended]
  4. Web Designer          [recommended]
  5. End User Advocate     [recommended]
  6. Security Engineer     [recommended]

Also available:
  7. Software Architect
  8. Woodworker (custom)
  9. Mass Spectrometrist (custom)
  ...

Accept [enter], resize [N], add by number [+7,8], or customize [c]?
```

- **Accept:** proceed with suggested team
- **Resize [N]:** adjust team size (add/remove from relevance order)
- **Add [+N,N]:** add specific personas to the suggested team
- **Customize [c]:** show full roster, pick by number

If `--team N` was set, auto-size to N using the relevance order (still show for confirmation).

#### Workforce management commands

For `--hire`:
1. Slugify the name (e.g., "Mass Spectrometrist" → `mass-spectrometrist`)
2. Create `$GW_REPO/workforce/mass-spectrometrist.md` with:
   ```markdown
   ---
   name: Mass Spectrometrist
   background: {from --background flag}
   perspective: {auto-derived from background: key concerns and viewpoint}
   priorities: {auto-derived: what this persona cares most about}
   debate_style: {auto-derived: how they argue and what evidence they cite}
   ---
   ```
3. Print: "Hired Mass Spectrometrist. Available in all future `/gw:compete` runs."

For `--fire`:
1. Find matching file in `$GW_REPO/workforce/` (not `_defaults/`)
2. Delete the file
3. Print: "Removed {name} from workforce."
4. If the user tries to fire a default persona: "Can't fire default personas. They ship with the skill."

For `--roster`:
1. List all personas with source:
   ```
   Workforce Roster (18 personas):
     [default] Software Architect — System design, scalability, technical debt
     [default] UX Specialist — User flows, friction, accessibility
     ...
     [custom]  Woodworker — Craftsmanship, ergonomics, "does it feel right"
     [custom]  Mass Spectrometrist — Data precision, calibration, scientific defensibility
   ```

### Step 6 — Feature Matrix Generation

Launch a single foreground agent (`subagent_type="general-purpose"`) with:
- The project's FEATURE_INVENTORY from Step 2
- All `.competitors/research/*.md` files
- Instruction to build a comprehensive feature-by-feature comparison

The agent writes `.competitors/feature-matrix.json`:
```json
{
  "generated": "2026-03-18",
  "project": "my-app",
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

**Status values:** `full`, `partial`, `missing`, `planned`
**Gap types:**
- `competitive_gap` — they have it, we don't
- `competitive_advantage` — we have it, they don't
- `parity` — everyone has it
- `opportunity` — nobody has it yet (from community pain points in deep mode)

Present the matrix to the user as a readable table before proceeding to debate.

### Step 7 — Structured Debate

Three rounds of structured debate with the assembled team.

#### Round 1 — Position Statements

Launch all team agents in parallel (`run_in_background=true`) with:

```
You are a {PERSONA_NAME}.

Background: {background}
Perspective: {perspective}
Priorities: {priorities}
Debate style: {debate_style}

You are reviewing a competitive feature analysis for {PROJECT_NAME} ({APP_TYPE}).

Read the feature matrix at .competitors/feature-matrix.json.
Read the project context: {STACK_CONTEXT}

From your unique perspective:
1. Pick your top 5 features to implement. Rank them 1-5.
2. For each, explain WHY from your specific background and priorities.
3. Flag any features you think are TRAPS — features that look appealing but aren't worth pursuing. Explain why.
4. Note any features MISSING from the matrix that you think matter from your perspective.

Write your position to .competitors/debate/round1/{PERSONA_SLUG}.md in this format:

# {Persona Name} — Round 1 Position

## Top 5 Features to Implement
### 1. {Feature Name}
**Why:** {explanation from your perspective}
**Effort assessment:** {your take on the effort}

### 2. ...

## Trap Features (avoid these)
### {Feature Name}
**Why it's a trap:** {explanation}

## Missing from Matrix
{features the analysis missed}
```

After all agents complete, verify each file exists.

#### Round 2 — Cross-Examination

The supervisor agent (foreground) reads all Round 1 positions. It identifies the top 3-5 disagreements — features where agents strongly disagree on priority or trap status.

Then launch all team agents again in parallel with:

```
You are a {PERSONA_NAME} in Round 2 of a structured debate.

Background: {background}
Perspective: {perspective}
Debate style: {debate_style}

Here are all Round 1 positions from your colleagues:
{all round 1 positions concatenated}

The supervisor has identified these key disagreements:
{list of disagreements with devil's advocate challenges}

The supervisor challenges YOUR position:
"{specific devil's advocate argument targeting this persona's Round 1 stance}"

Respond to:
1. The disagreements — address each one from your perspective
2. The supervisor's challenge — defend your position or change your mind
3. Any colleague's argument that changed your thinking

Write to .competitors/debate/round2/{PERSONA_SLUG}.md
```

#### Round 3 — Supervisor Synthesis

A single foreground supervisor agent reads ALL Round 1 + Round 2 files and writes `.competitors/debate/CONSENSUS.md`:

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
| # | Feature | Consensus | Effort | Key Argument |
|---|---------|-----------|--------|-------------|

### Tier 3: Contested (needs user decision)
| # | Feature | For | Against | Key Tension |
|---|---------|-----|---------|-------------|
| N | {name} | Personas A,B | Personas C,D | {summary of disagreement} |

## Trap Features (team consensus: avoid)
| Feature | Flagged By | Reason |
|---------|-----------|--------|

## Supervisor's Final Recommendation
{Narrative synthesis: what to build, what to skip, what order, and why.
Explicitly notes where the supervisor overruled minority positions and why.}
```

### Step 8 — Feature Selection Dialog

Present consensus to the user:

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

TRAPS (team flagged as avoid):
  5. [1/6 agree] Blockchain integration   Effort: Large
     "Nobody's asking for this" — End User Advocate

Select features to implement:
  All recommended [a], pick by number [1,2,4], select all [*], or review debate [r]?
```

- **[a]:** Select all Tier 1 (strong consensus) features
- **[1,2,4]:** Select specific features by number
- **[*]:** Select everything (including contested)
- **[r]:** Display the full debate transcripts for review, then re-prompt

Save selections to `.competitors/SELECTED.json`:
```json
{
  "date": "2026-03-18",
  "selected": [
    { "name": "Real-time editing", "consensus": "5/6", "effort": "Large" },
    { "name": "API webhooks", "consensus": "5/6", "effort": "Medium" }
  ],
  "deferred": [...],
  "rejected": [...]
}
```

**APPROVAL GATE:** Do not proceed past this step without explicit user confirmation of feature selection.

### Step 9 — Test Scaffold Generation

Skip if SKIP_TESTS is true.

For each selected feature, spawn specialist testing agents in parallel (`run_in_background=true`).

#### Testing agent pool

| Agent | Responsibility | Output Pattern |
|-------|---------------|----------------|
| Unit Test Architect | Pure logic tests, isolated components | `tests/unit/feature-{slug}.test.{ext}` |
| Integration Test Architect | Cross-module, database, API contracts | `tests/integration/feature-{slug}.test.{ext}` |
| E2E Test Architect | Full user flows, happy + error paths | `tests/e2e/feature-{slug}.spec.{ext}` |
| Backend Test Architect | API endpoints, auth, data validation | `tests/backend/feature-{slug}.test.{ext}` |
| Stress Test Architect | Load, concurrency, resource limits | `tests/stress/feature-{slug}.test.{ext}` |
| Session Recorder | Playwright recorded user journeys (web only) | `tests/recorded/feature-{slug}.spec.{ext}` |

**Not all agents apply to every project.** Selection logic:

| APP_TYPE | Agents Used |
|----------|-------------|
| web | All 6 |
| server | Unit, Integration, Backend, Stress |
| cli | Unit, Integration, E2E |
| mobile | Unit, Integration, E2E |
| library | Unit, Integration, Stress |
| saas | All 6 |

#### Agent prompt template

```
You are a {TEST_SPECIALTY} generating TDD test scaffolds.

Project: {PROJECT_NAME} ({APP_TYPE})
Stack: {STACK_CONTEXT}
Feature to test: {FEATURE_NAME}
Feature description: {from matrix + consensus}

RULES:
1. Read existing test files to match the project's test framework, naming conventions, and patterns.
2. Generate test files with REAL assertions that describe expected behavior.
3. Implementation should be stubbed — tests MUST FAIL until the feature is built (true TDD).
4. Use descriptive test names that document the expected behavior.
5. Cover happy path, edge cases, and error cases.
6. For web apps: use the project's existing test framework. If none detected, default to Vitest (unit/integration) + Playwright (e2e/recorded).
7. For backend: test API contracts, auth boundaries, validation rules, and data integrity.
8. For stress: define load parameters, concurrency levels, and acceptable thresholds as constants at the top of the file.

Write test files to the appropriate directory.
Write a manifest to .competitors/tests/{FEATURE_SLUG}-{SPECIALTY}-manifest.md documenting what each test validates.
```

**Session Recorder (web apps only):**
- Generates Playwright test scripts with `page.goto()`, `page.click()`, `page.fill()` steps
- Includes `await expect(page).toHaveScreenshot()` for visual regression baselines
- Scaffolds `playwright.config.ts` if not already present
- Marks recorded sessions with `// RECORD: run with --headed to capture baseline`

#### Commit test scaffolds

After all testing agents complete, ask the user: "Test scaffolds generated. Commit to the branch? [y/n]"

If yes:
```bash
git add tests/
git add .competitors/tests/
git commit -m "test: scaffold TDD tests for competitive features

Features: {comma-separated feature names}
Types: unit, integration, e2e, backend, stress, recorded
All tests designed to FAIL until features are implemented."
```

### Step 10 — Report Synthesis

Launch a single foreground synthesis agent that reads all artifacts:
- `.competitors/registry.json`
- `.competitors/research/*.md`
- `.competitors/feature-matrix.json`
- `.competitors/debate/CONSENSUS.md`
- `.competitors/SELECTED.json`
- `.competitors/tests/*-manifest.md`

Writes `.competitors/REPORT.md`:

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

### Step 11 — PowerPoint Generation

Skip if SKIP_PPTX is true.

#### 11a. Build JSON data file

Write `/tmp/compete_presentation_data.json` with all data extracted from REPORT.md, feature matrix, consensus, and test manifests.

#### 11b. Write and execute Python script

Write `/tmp/compete_presentation.py` — reads JSON, generates `.pptx` using `python-pptx`.

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

Font: Calibri throughout. Slide dimensions: 16:9 widescreen. Accent bar: 0.06" wide ACCENT strip at left edge of every slide.

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

If both fail: "PowerPoint generation failed — python-pptx required. Use `--skip-pptx` to skip."

**Output:** `docs/gw/compete-report-YYYY-MM-DD.pptx`

Tell the user where the file was saved. If the project is a git repo, ask: "Commit the presentation? [y/n]"

### Step 12 — GSD Integration

Skip if SKIP_GSD is true.

Check if `~/.claude/commands/gsd/` exists:
- **If `.planning/PROJECT.md` exists** (brownfield): invoke `/gsd:new-milestone` referencing `.competitors/REPORT.md`
- **If no `.planning/`** (greenfield): invoke `/gsd:new-project` referencing `.competitors/REPORT.md`
- **If GSD not installed:** "Full analysis in `.competitors/REPORT.md`. Install GSD to auto-create a project from these phases."

Each selected feature becomes a GSD phase. Each phase starts with: "Make the scaffolded tests pass for {feature}."

---

## Default Workforce

Ships in `workforce/_defaults/`:

| # | Persona | Slug | Perspective | Priorities |
|---|---------|------|-------------|------------|
| 1 | Software Architect | `software-architect` | System design, scalability, technical debt | Clean boundaries, maintainability, long-term cost |
| 2 | UX Specialist | `ux-specialist` | User flows, friction, accessibility | Can a new user figure this out in 30 seconds? |
| 3 | UI Designer | `ui-designer` | Visual design, consistency, polish | Design system coherence, visual hierarchy, spacing |
| 4 | Web Designer | `web-designer` | Responsive, performance, SEO | Does it work on every screen? Is it fast? |
| 5 | Backend Engineer | `backend-engineer` | APIs, data models, infrastructure | Data integrity, API contracts, operational cost |
| 6 | Product Manager | `product-manager` | Prioritization, ROI, user value | Does this move the needle? What's the opportunity cost? |
| 7 | QA Engineer | `qa-engineer` | Edge cases, test coverage, reliability | What breaks when this goes wrong? |
| 8 | Security Engineer | `security-engineer` | Auth, data protection, compliance | What can be exploited? What data is at risk? |
| 9 | DevOps Engineer | `devops-engineer` | Deployment, monitoring, scalability | Can we deploy this safely? Can we roll it back? |
| 10 | Data Scientist | `data-scientist` | Analytics, metrics, data-driven decisions | How do we measure if this worked? |
| 11 | Physicist | `physicist` | First-principles thinking, modeling | Strip away assumptions — what's actually true? |
| 12 | Woodworker | `woodworker` | Craftsmanship, ergonomics, feel | Does it feel right? Is it built to last? |
| 13 | Business Analyst | `business-analyst` | Market fit, competitive positioning, revenue | Does this make money? Does it win customers? |
| 14 | End User Advocate | `end-user-advocate` | Simplicity, onboarding, plain language | Could my mom use this? |
| 15 | Performance Engineer | `performance-engineer` | Speed, resource usage, limits | How does it behave at 10x load? |

### Persona file format

```markdown
---
name: Woodworker
background: 30 years building furniture and hand tools
perspective: Craftsmanship, ergonomics, material quality, tactile experience
priorities: Does it feel right in your hands? Is it built to last? Is the joinery clean or are we hiding screws?
debate_style: Practical metaphors, questions about longevity and fit-and-finish
---
```

---

## Error Handling

- If WebSearch/WebFetch fails during research: retry once, then mark competitor as "research incomplete" and continue
- If a debate agent fails: note as `[FAILED]` in status, supervisor synthesizes with available positions
- If `python-pptx` unavailable: suggest `pip install python-pptx` or `--skip-pptx`
- If GSD not installed: inform user, continue without GSD
- If workforce directory missing: create it with `mkdir -p`
- If user tries to `--fire` a default persona: reject with explanation
- If `--hire` name conflicts with existing persona: ask to overwrite or rename
- Never force-push or destructive git operations without asking
