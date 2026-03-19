# gw:compete Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the `gw:compete` competitive feature analysis skill with persistent workforce, structured debate, TDD test scaffolding, and PowerPoint/GSD output.

**Architecture:** Single skill file (`.claude/commands/gw/compete.md`) orchestrates parallel agents for research, debate, and test generation. A `workforce/` directory in the gw-skills repo stores persona definitions as individual markdown files. Project-local data lives in `.competitors/`.

**Tech Stack:** Claude Code skill (markdown), python-pptx (presentation), Playwright (session recording scaffolds), GSD integration

**Spec:** `docs/superpowers/specs/2026-03-18-gw-compete-design.md`

---

### Task 1: Create default workforce persona files

**Files:**
- Create: `workforce/_defaults/software-architect.md`
- Create: `workforce/_defaults/ux-specialist.md`
- Create: `workforce/_defaults/ui-designer.md`
- Create: `workforce/_defaults/web-designer.md`
- Create: `workforce/_defaults/backend-engineer.md`
- Create: `workforce/_defaults/product-manager.md`
- Create: `workforce/_defaults/qa-engineer.md`
- Create: `workforce/_defaults/security-engineer.md`
- Create: `workforce/_defaults/devops-engineer.md`
- Create: `workforce/_defaults/data-scientist.md`
- Create: `workforce/_defaults/physicist.md`
- Create: `workforce/_defaults/woodworker.md`
- Create: `workforce/_defaults/business-analyst.md`
- Create: `workforce/_defaults/end-user-advocate.md`
- Create: `workforce/_defaults/performance-engineer.md`

- [ ] **Step 1: Create workforce directory structure**

```bash
mkdir -p workforce/_defaults
```

- [ ] **Step 2: Create all 15 default persona files**

Each file uses this frontmatter-only format:

```markdown
---
name: Software Architect
background: 15 years designing distributed systems, from monoliths to microservices
perspective: System design, scalability, technical debt, clean boundaries
priorities: Will this scale? Are the boundaries clean? What's the maintenance cost in 2 years?
debate_style: Draws architecture diagrams in words, asks about coupling and cohesion, references SOLID principles
---
```

Create all 15 files using the persona details from the spec (Section "Default Workforce"):

| File | Name | Background | Perspective | Priorities | Debate Style |
|------|------|-----------|-------------|-----------|-------------|
| `software-architect.md` | Software Architect | 15 years designing distributed systems | System design, scalability, technical debt | Will this scale? Are the boundaries clean? What's the maintenance cost? | Architecture diagrams in words, coupling/cohesion analysis, SOLID references |
| `ux-specialist.md` | UX Specialist | 12 years in user research and interaction design | User flows, friction points, accessibility | Can a new user figure this out in 30 seconds? Where will they get stuck? | User journey narratives, friction analysis, "show me the happy path" |
| `ui-designer.md` | UI Designer | 10 years in visual design and design systems | Visual design, consistency, polish, hierarchy | Is the design system coherent? Does the visual hierarchy guide the eye? | References design tokens, spacing scales, contrast ratios, consistency audits |
| `web-designer.md` | Web Designer | 12 years building responsive, performant websites | Responsive design, performance, SEO, cross-browser | Does it work on every screen size? Is it fast on 3G? | Core Web Vitals references, mobile-first arguments, progressive enhancement |
| `backend-engineer.md` | Backend Engineer | 10 years building APIs, data pipelines, and infrastructure | APIs, data models, infrastructure, reliability | Data integrity first. What happens when this fails at 3 AM? | Database schema analysis, API contract review, failure mode enumeration |
| `product-manager.md` | Product Manager | 8 years shipping products from zero to scale | Prioritization, ROI, user value, market fit | Does this move the needle? What's the opportunity cost of building this instead of that? | Cost-benefit framing, user story references, "what problem does this solve?" |
| `qa-engineer.md` | QA Engineer | 10 years in quality assurance across web, mobile, and backend | Edge cases, test coverage, reliability, regression | What breaks when this goes wrong? What's the blast radius? | Enumerates failure scenarios, asks about error handling, references test pyramids |
| `security-engineer.md` | Security Engineer | 12 years in application security and compliance | Auth, data protection, compliance, attack surfaces | What can be exploited? What data is at risk? What's the threat model? | OWASP references, threat modeling, "assume the attacker knows everything" |
| `devops-engineer.md` | DevOps Engineer | 8 years in CI/CD, infrastructure, and observability | Deployment, monitoring, scalability, rollback | Can we deploy this safely? Can we roll it back in 30 seconds? | Deployment pipeline analysis, observability gaps, "how do we know it's broken?" |
| `data-scientist.md` | Data Scientist | 10 years in analytics, experimentation, and ML | Analytics, metrics, data-driven decisions, experimentation | How do we measure if this worked? What's the success metric? | A/B test framing, metric definitions, "correlation is not causation" |
| `physicist.md` | Physicist | 20 years in theoretical and experimental physics | First-principles thinking, modeling, simplification | Strip away assumptions — what's actually true here? What's the simplest model? | Fermi estimation, dimensional analysis metaphors, "let's derive this from scratch" |
| `woodworker.md` | Woodworker | 30 years building furniture and hand tools | Craftsmanship, ergonomics, material quality, tactile experience | Does it feel right in your hands? Is it built to last? Is the joinery clean or are we hiding screws? | Practical metaphors, questions about longevity and fit-and-finish, "would you be proud to show this?" |
| `business-analyst.md` | Business Analyst | 10 years in market analysis and competitive strategy | Market fit, competitive positioning, revenue, growth | Does this make money? Does it win customers from competitors? | Competitive matrix references, TAM/SAM/SOM framing, "where's the moat?" |
| `end-user-advocate.md` | End User Advocate | 15 years in customer support and user advocacy | Simplicity, onboarding, plain language, accessibility | Could my mom use this? Will the help text actually help? | Real user stories, plain language rewrites, "I tried to use it and got stuck here" |
| `performance-engineer.md` | Performance Engineer | 10 years in performance optimization and load testing | Speed, resource usage, scalability limits, bottlenecks | How does it behave at 10x load? Where's the bottleneck? | Profiling data references, p99 latency arguments, "show me the benchmark" |

- [ ] **Step 3: Verify all files exist**

Run: `ls -la workforce/_defaults/`
Expected: 15 `.md` files

- [ ] **Step 4: Commit**

```bash
git add workforce/
git commit -m "feat(compete): add default workforce personas (15 specialists)"
```

---

### Task 2: Skill frontmatter, Step 0 (update check), and Step 1 (argument parsing & routing)

**Files:**
- Create: `.claude/commands/gw/compete.md`

- [ ] **Step 1: Write frontmatter and Step 0**

Create `.claude/commands/gw/compete.md` with the YAML frontmatter following the established gw-skills pattern:

```markdown
---
name: compete
description: Competitive feature analysis with structured team debate, TDD test scaffolds, and implementation planning
argument-hint: "[--deep] [--hire \"Name\" --background \"...\"] [--fire \"Name\"] [--roster] [--refresh] [--skip-pptx] [--skip-gsd] [--skip-tests] [--team N] [--add \"Competitor\"] [--remove \"Competitor\"] [--list]"
---

## Step 0 — Update check

Resolve the gw-skills repo directory and run its update check script:

\`\`\`bash
GW_REPO="$(cd "$(readlink ~/.claude/commands/gw)/../../.." 2>/dev/null && pwd)" || GW_REPO="$HOME/.gw-skills"
bash "$GW_REPO/check-update.sh" 2>/dev/null || true
\`\`\`

If the output contains `UPDATE_AVAILABLE`, tell the user how many commits behind they are and ask: "gw-skills has updates available. Run /gw:update to install them, or continue?" If they want to update, invoke `/gw:update` and stop. Otherwise continue. If the script is missing or fails, skip silently.
```

- [ ] **Step 2: Write argument parsing section**

Add the "Parse arguments" section immediately after Step 0. Copy the exact flag definitions from the spec's "Argument Parsing" section. Include all 12 flags with their variable mappings and defaults.

- [ ] **Step 3: Write the workflow routing section**

Add the routing table and approval gates. Copy the exact routing table from the spec showing which steps execute for each condition (default, --add/--remove/--list, --hire/--fire/--roster, --skip-tests, --skip-pptx, --skip-gsd, --refresh, cached state). Include the 3 approval gate locations.

- [ ] **Step 4: Verify frontmatter parses correctly**

Run: `head -5 .claude/commands/gw/compete.md`
Expected: Valid YAML frontmatter with name, description, argument-hint

- [ ] **Step 5: Commit**

```bash
git add .claude/commands/gw/compete.md
git commit -m "feat(compete): add skill frontmatter, update check, argument parsing, and routing"
```

---

### Task 3: Step 2 (project detection) and Step 3 (competitor registry)

**Files:**
- Modify: `.claude/commands/gw/compete.md`

- [ ] **Step 1: Write Step 2 — Project Detection**

Add the full Step 2 section. Follow the spec exactly — it mirrors review-app's detection pattern:
1. Stack detection with parallel globs (package.json, pyproject.toml, go.mod, Cargo.toml, etc.)
2. Read README.md + CLAUDE.md for context
3. APP_TYPE determination using the same rules as review-app (web, server, cli, mobile, library, saas)
4. FEATURE_INVENTORY construction — scan for route definitions, API endpoints, CLI commands, UI components, database models, config options
5. STACK_CONTEXT summary (under 500 words)

Include the APP_TYPE classification table from review-app's spec (the same signal → type mapping).

- [ ] **Step 2: Write Step 3 — Competitor Registry**

Add the full Step 3 section with three sub-steps:

**3a. Auto-detection** — the signal detection table from the spec (README grep, dependency scan, marketing copy scan, existing registry load). State that all scans run in parallel.

**3b. Present & confirm** — the exact output format from the spec showing [AUTO] and [REGISTERED] tags with the interactive prompt (Add more [a], remove [r], confirm [enter]).

**3c. Save registry** — the JSON schema for `.competitors/registry.json` with project, app_type, and competitors array. Include the routing note: "For --add/--remove/--list: skip 3a and 3b, go directly to registry management and stop."

For `--add`: create `.competitors/` if needed, add entry to registry.json, print confirmation.
For `--remove`: find and remove entry from registry.json, print confirmation.
For `--list`: read and display registry.json contents.

- [ ] **Step 3: Commit**

```bash
git add .claude/commands/gw/compete.md
git commit -m "feat(compete): add project detection and competitor registry (Steps 2-3)"
```

---

### Task 4: Step 4 (research phase)

**Files:**
- Modify: `.claude/commands/gw/compete.md`

- [ ] **Step 1: Write Step 4 — Research Phase**

Add the full Step 4 section. Include:

1. **Agent launching pattern** — "Launch one background research agent per competitor in a SINGLE message using the Agent tool with `run_in_background=true` and `subagent_type="general-purpose"`."

2. **Agent prompt template** — Copy the exact template from the spec. It includes:
   - Lightweight tasks (always): WebSearch official site, features, pricing, changelog, API docs; WebFetch top 3-5 pages; extract features, pricing, tech stack, integrations, changes
   - Deep tasks (only if depth=deep): Reddit, HN, G2/Capterra/ProductHunt searches; blog comparison searches; extract complaints, requests, pain points, praise
   - Rules: factual + cited, distinguish confirmed vs rumored, note pricing currency/date, include engagement metrics
   - Output format: the full markdown template for `.competitors/research/{COMPETITOR_SLUG}.md` with all sections (Features, Pricing, Tech Stack, Integrations, Recent Changes, Community Sentiment)

3. **Rate limit guard** — retry once with backoff, then "research incomplete"

4. **Freshness check** — if research <7 days old and no --refresh, ask "Re-use [enter], refresh [r], or skip [s]?"

5. **Collection** — verify each file exists, print status table with [done]/[FAILED] indicators and summary stats

- [ ] **Step 2: Commit**

```bash
git add .claude/commands/gw/compete.md
git commit -m "feat(compete): add research phase with parallel agents (Step 4)"
```

---

### Task 5: Step 5 (team assembly and workforce management)

**Files:**
- Modify: `.claude/commands/gw/compete.md`

- [ ] **Step 1: Write Step 5 — Team Assembly**

Add the full Step 5 section with sub-steps:

**5a. Load workforce** — Resolve GW_REPO path (same as Step 0). Read all `$GW_REPO/workforce/_defaults/*.md` and `$GW_REPO/workforce/*.md` (excluding _defaults/). Parse frontmatter from each: name, background, perspective, priorities, debate_style.

**5b. Suggest team composition** — The APP_TYPE → suggested team mapping table from the spec (web → UX Specialist, UI Designer, Web Designer, Product Manager, Backend Engineer, End User Advocate; etc. for all 6 app types). Note that custom personas are always shown as available additions.

**5c. Approval gate** — The exact output format from the spec showing suggested team with [recommended] tags, available additions with custom tags, and the interactive prompt (Accept [enter], resize [N], add by number [+7,8], customize [c]). Include behavior for each option. Note that --team N auto-sizes using relevance order but still shows for confirmation.

- [ ] **Step 2: Write workforce management commands**

Add the `--hire`, `--fire`, and `--roster` command handling:

**--hire:** Slugify name, create `$GW_REPO/workforce/{slug}.md` with frontmatter (name from flag, background from --background flag, perspective/priorities/debate_style auto-derived from background). Print confirmation.

**--fire:** Find matching file in `$GW_REPO/workforce/` (NOT _defaults/). Delete file. Print confirmation. Reject with explanation if user tries to fire a default persona.

**--roster:** List all personas grouped by [default] and [custom] with name and perspective.

- [ ] **Step 3: Commit**

```bash
git add .claude/commands/gw/compete.md
git commit -m "feat(compete): add team assembly and workforce management (Step 5)"
```

---

### Task 6: Step 6 (feature matrix) and Step 7 (structured debate)

**Files:**
- Modify: `.claude/commands/gw/compete.md`

- [ ] **Step 1: Write Step 6 — Feature Matrix Generation**

Add the full Step 6 section:
- Launch a single foreground agent with the FEATURE_INVENTORY and all research files
- Agent writes `.competitors/feature-matrix.json` using the exact JSON schema from the spec (generated, project, competitors, categories array with features containing name, our_status, competitors map, gap_type, effort_estimate, community_signal)
- Define status values: full, partial, missing, planned
- Define gap types: competitive_gap, competitive_advantage, parity, opportunity
- Present matrix to user as readable table before debate

- [ ] **Step 2: Write Step 7, Round 1 — Position Statements**

Add Round 1 of the structured debate:
- Launch all team agents in parallel (`run_in_background=true`)
- Copy the exact agent prompt template from the spec — includes persona context (name, background, perspective, priorities, debate_style), project context, instruction to pick top 5 features, flag traps, note missing features
- Output format: `.competitors/debate/round1/{PERSONA_SLUG}.md` with the exact markdown template from the spec
- After completion: verify each file exists

- [ ] **Step 3: Write Step 7, Round 2 — Cross-Examination**

Add Round 2:
- Supervisor (foreground agent) reads all Round 1 positions, identifies top 3-5 disagreements
- Launch all team agents again in parallel with the exact prompt from spec — includes all colleagues' Round 1 positions, identified disagreements, specific devil's advocate challenge per persona
- Output: `.competitors/debate/round2/{PERSONA_SLUG}.md`

- [ ] **Step 4: Write Step 7, Round 3 — Supervisor Synthesis**

Add Round 3:
- Single foreground supervisor agent reads ALL Round 1 + Round 2 files
- Writes `.competitors/debate/CONSENSUS.md` using the exact markdown template from the spec (Ranked Feature Recommendations with Tier 1/2/3, Trap Features table, Supervisor's Final Recommendation narrative)

- [ ] **Step 5: Commit**

```bash
git add .claude/commands/gw/compete.md
git commit -m "feat(compete): add feature matrix and structured debate with 3 rounds (Steps 6-7)"
```

---

### Task 7: Step 8 (feature selection) and Step 9 (test scaffold generation)

**Files:**
- Modify: `.claude/commands/gw/compete.md`

- [ ] **Step 1: Write Step 8 — Feature Selection Dialog**

Add the full Step 8 section:
- Present consensus using the exact output format from the spec — RECOMMENDED (strong consensus), CONTESTED (split opinion with FOR/AGAINST), TRAPS (team flagged as avoid)
- Interactive prompt: All recommended [a], pick by number [1,2,4], select all [*], review debate [r]
- Define behavior for each option ([r] displays full debate transcripts then re-prompts)
- Save selections to `.competitors/SELECTED.json` using the exact schema from spec (date, selected array, deferred array, rejected array)
- **APPROVAL GATE** — do not proceed without explicit user confirmation

- [ ] **Step 2: Write Step 9 — Test Scaffold Generation**

Add the full Step 9 section:
- Skip if SKIP_TESTS is true
- Define the testing agent pool table from spec (6 agents: Unit, Integration, E2E, Backend, Stress, Session Recorder) with their responsibility and output pattern
- Define APP_TYPE → agents used mapping table from spec
- Copy the exact agent prompt template from spec with all 8 rules
- Session Recorder specifics: Playwright scripts, toHaveScreenshot(), scaffold playwright.config.ts if missing, RECORD comment markers

- [ ] **Step 3: Write the commit section for test scaffolds**

Add the commit section: ask user "Test scaffolds generated. Commit to the branch? [y/n]". If yes, git add tests/ and .competitors/tests/, commit with the message template from spec.

- [ ] **Step 4: Commit**

```bash
git add .claude/commands/gw/compete.md
git commit -m "feat(compete): add feature selection dialog and test scaffold generation (Steps 8-9)"
```

---

### Task 8: Step 10 (report), Step 11 (PowerPoint), Step 12 (GSD), and error handling

**Files:**
- Modify: `.claude/commands/gw/compete.md`

- [ ] **Step 1: Write Step 10 — Report Synthesis**

Add the full Step 10 section:
- Launch single foreground synthesis agent that reads all artifacts (registry, research, matrix, consensus, selected, test manifests)
- Agent writes `.competitors/REPORT.md` using the exact markdown template from spec (Executive Summary, Feature Matrix table, Competitive Position with Advantages/Gaps/Opportunities/Traps, Team Debate Summary, Test Coverage Plan table, Implementation Roadmap with phased approach)

- [ ] **Step 2: Write Step 11 — PowerPoint Generation**

Add the full Step 11 section:

**11a.** JSON data file to `/tmp/compete_presentation_data.json`

**11b.** Python script to `/tmp/compete_presentation.py`. Include:
- The exact design system from spec (PRIMARY, SECONDARY, ACCENT, SUCCESS, DANGER, WARNING, MUTED, BG_WHITE, BG_LIGHT with hex values)
- Font: Calibri, 16:9 widescreen, accent bar
- All 11 slides from the spec table (Title, Executive Summary, Feature Matrix, Competitive Advantages, Critical Gaps, Opportunities, Debate Highlights, Selected Features, Test Coverage Plan, Implementation Roadmap, Closing)

**Execution:**
```bash
mkdir -p docs/gw
uv run --with python-pptx python /tmp/compete_presentation.py
```
Fallback: `python3 -m pip install python-pptx && python3 /tmp/compete_presentation.py`
Failure message if both fail.

**Output:** `docs/gw/compete-report-YYYY-MM-DD.pptx`
Ask user to commit if in a git repo.

- [ ] **Step 3: Write Step 12 — GSD Integration**

Add the full Step 12 section:
- Skip if SKIP_GSD is true
- Check for `~/.claude/commands/gsd/`
- Brownfield (`.planning/PROJECT.md` exists): invoke `/gsd:new-milestone` referencing `.competitors/REPORT.md`
- Greenfield (no `.planning/`): invoke `/gsd:new-project` referencing `.competitors/REPORT.md`
- Not installed: print guidance message
- Each selected feature becomes a GSD phase starting with "Make the scaffolded tests pass"

- [ ] **Step 4: Write error handling section**

Add the "Error handling" section at the end of the skill file. Include all 8 error cases from the spec:
- WebSearch/WebFetch failures
- Debate agent failures
- python-pptx unavailable
- GSD not installed
- Workforce directory missing
- Firing default personas
- Hire name conflicts
- Destructive git operations

- [ ] **Step 5: Verify complete skill file**

Run: `wc -l .claude/commands/gw/compete.md`
Expected: ~800-1200 lines (comparable to review-app at ~860 lines and saas-idea at ~1500 lines)

Run: `head -5 .claude/commands/gw/compete.md`
Expected: Valid YAML frontmatter

Run: `grep -c "^## Step\|^### Step\|^####" .claude/commands/gw/compete.md`
Expected: ~30+ section headers covering Steps 0-12

- [ ] **Step 6: Commit**

```bash
git add .claude/commands/gw/compete.md
git commit -m "feat(compete): add report synthesis, PowerPoint, GSD integration, and error handling (Steps 10-12)"
```

---

### Task 9: Final integration verification

**Files:**
- Read: `.claude/commands/gw/compete.md` (full file review)
- Read: `workforce/_defaults/*.md` (spot check)

- [ ] **Step 1: Verify skill file structure**

Read the complete `.claude/commands/gw/compete.md` and verify:
1. Frontmatter is valid (name, description, argument-hint)
2. Step 0 matches the standard update check pattern
3. All 13 steps are present (0 through 12)
4. All 3 approval gates are in place (after Steps 3, 5, 8)
5. Routing table covers all flag combinations
6. All file paths use `.competitors/` (project-local) and `workforce/` (global)
7. PowerPoint output path is `docs/gw/compete-report-YYYY-MM-DD.pptx`
8. All agent prompt templates include output file paths
9. No placeholder text, TODOs, or incomplete sections

- [ ] **Step 2: Verify workforce files**

Run: `ls workforce/_defaults/ | wc -l`
Expected: 15

Spot-check 3 persona files (software-architect.md, woodworker.md, end-user-advocate.md):
- Valid frontmatter with all 5 fields (name, background, perspective, priorities, debate_style)
- No placeholder content

- [ ] **Step 3: Cross-reference with spec**

Grep for key terms to ensure nothing was missed:
- `grep -c "APPROVAL GATE\|approval gate" .claude/commands/gw/compete.md` — expected: 3
- `grep -c "run_in_background" .claude/commands/gw/compete.md` — expected: 3+ (research, round 1, round 2, test scaffolds)
- `grep -c "docs/gw/" .claude/commands/gw/compete.md` — expected: 2+ (mkdir, output path)
- `grep "\.competitors/" .claude/commands/gw/compete.md | wc -l` — expected: 15+ (all the file paths)

- [ ] **Step 4: Final commit (if any fixes needed)**

```bash
git add .claude/commands/gw/compete.md workforce/
git commit -m "fix(compete): address integration review findings"
```

Only commit if Step 1-3 uncovered issues that required fixes. Skip if everything is clean.
