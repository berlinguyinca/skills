---
name: analyze-app
description: Analyze any application across specialist dimensions with role-adapted agents
argument-hint: "[--skip-cloud] [--skip-gsd] [--skip-testing] [--skip-security] [--skip-seo] [--skip-test-review] [--skip-defaults] [--skip-fix] [--skip-pptx] [--skip-recommend] [--type web|server|cli|mobile|library|saas] [--scope full|recent|recent:N|timeframe:<spec>] [--team auto|ask|N]"
---

## Step 0 — Update check

Resolve the gw-skills repo directory and run its update check script:

```bash
GW_REPO="$(cd "$(readlink ~/.claude/commands/gw)/../../.." 2>/dev/null && pwd)" || GW_REPO="$HOME/.gw-skills"
bash "$GW_REPO/check-update.sh" 2>/dev/null || true
```

If the output contains `UPDATE_AVAILABLE`, tell the user how many commits behind they are and ask: "gw-skills has updates available. Run /gw:update to install them, or continue?" If they want to update, invoke `/gw:update` and stop. Otherwise continue. If the script is missing or fails, skip silently.

---

You are an orchestrator for a multi-dimensional application analysis. You assemble a **tailored team of specialists** based on the project's type, size, and complexity. Follow these steps precisely.

Parse the arguments: "$ARGUMENTS"
- If "--skip-cloud" or "--skip-aws" is present, set SKIP_CLOUD=true
- If "--skip-gsd" is present, set SKIP_GSD=true
- If "--skip-testing" is present, set SKIP_TESTING=true
- If "--skip-security" is present, set SKIP_SECURITY=true
- If "--skip-seo" is present, set SKIP_SEO=true
- If "--skip-test-review" is present, set SKIP_TEST_REVIEW=true
- If "--skip-defaults" is present, set SKIP_DEFAULTS=true
- If "--skip-fix" is present, set SKIP_FIX=true
- If "--skip-pptx" is present, set SKIP_PPTX=true
- If "--skip-recommend" is present, set SKIP_RECOMMEND=true
- If "--type X" is present, set FORCED_TYPE=X (one of: web, server, cli, mobile, library, saas)
- If "--scope X" is present, set SCOPE_MODE=X (one of: full, recent, recent:N, timeframe:<spec>). Default: full
- If "--team X" is present: if X is a number, set TEAM_MODE=auto and TEAM_SIZE_OVERRIDE=X (overrides complexity-based sizing). If X is "auto" or "ask", set TEAM_MODE=X. Default: ask

---

## Step 1 — Pre-flight, Detection & Sizing

### 1a. Check for existing analysis

Check if `.analysis/` directory exists. If it does, ask the user: "`.analysis/` already exists. Refresh all reports, or skip analysis and just view existing REPORT.md?" If they choose to skip, read and present `.analysis/REPORT.md` and stop. If they choose to refresh, continue.

Run `mkdir -p .analysis`

### 1b. Stack detection

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
- `setup.py`, `setup.cfg` with `console_scripts` (Python CLI)
- `bin/` directory with executable scripts

Read `CLAUDE.md` and `README.md` if they exist (in parallel). These provide project context.

**Determine the APP_TYPE** using the detected stack. If FORCED_TYPE was set, use that instead. Otherwise, classify using these rules:

| Detected Signals | APP_TYPE |
|---|---|
| React, Vue, Angular, Svelte, Next.js, Vite with HTML/CSS, Tailwind, frontend framework + optional backend | **web** |
| FastAPI, Flask, Django, Express, Gin, Rails, .NET API without significant frontend | **server** |
| Click, Typer, Cobra, clap, argparse, `console_scripts`, `bin/` executables, no web framework | **cli** |
| React Native, Flutter, Swift/iOS, Kotlin/Android, Expo | **mobile** |
| `setup.py`/`pyproject.toml` with library metadata, no entry point, published to npm/PyPI/crates.io | **library** |
| Mixed frontend + backend | **web** (default for full-stack) |

### 1b-saas. SaaS signal detection

Run these checks in parallel to detect SaaS indicators:

| Signal | Detection Method |
|---|---|
| Payment SDK | Grep for `stripe`, `paddle`, `lemonsqueezy` in dependency files |
| Pricing/billing | Glob for files with `pricing`, `billing`, `subscription`, `plan` in name |
| Multi-tenancy | Grep for `tenant`, `organization`, `workspace` in models/schema files |
| Auth providers | Grep for `auth0`, `clerk`, `workos`, `okta` in dependency files |
| Feature flags | Grep for `launchdarkly`, `flagsmith`, `unleash` in dependency files |

**Rule:** If FORCED_TYPE is not set:
- 2+ signals detected → override APP_TYPE to `saas`
- 1 signal detected → keep current APP_TYPE but note: "SaaS signals detected; use `--type saas` for business-focused analysis."

### 1c. Scope resolution

Resolve the SCOPE_MODE to produce FILE_SCOPE (a list of files to focus on):

| Scope Mode | Git Command |
|---|---|
| `full` (default) | No filtering — FILE_SCOPE stays empty |
| `recent` | `git log --name-only --pretty=format: -20 \| sort -u \| sed '/^$/d'` |
| `recent:N` | Same with `-N` (e.g. `recent:50` → `-50`) |
| `timeframe:2w` | `git log --name-only --pretty=format: --since="2 weeks ago" \| sort -u \| sed '/^$/d'` |
| `timeframe:YYYY-MM-DD..YYYY-MM-DD` | `git log --since=START --until=END --name-only --pretty=format: \| sort -u \| sed '/^$/d'` |

**Guards:**
- If FILE_SCOPE has >200 files, warn the user and fall back to `full` scope.
- If FILE_SCOPE has 0 files, ask the user to adjust the scope parameter.

### 1d. Complexity sizing

Compute the project size with a fast glob `**/*` excluding `node_modules`, `.git`, `dist`, `build`, `vendor`, `__pycache__`, `.next`:

| Project Size | Files | Base Team Size |
|---|---|---|
| Small | < 50 | 3 |
| Medium | 50–200 | 5 |
| Large | 200–500 | 7 |
| Monorepo | 500+ | 9 |

**Adjustments** (+1 each, capped at 10):
- 3+ languages detected
- Infrastructure code present (Terraform, K8s manifests, Docker)
- 2+ frameworks detected

**Minimum:** `max(3, count_of_active_mandatory_specialists)` — ensures all non-skipped mandatory specialists always fit
**Maximum:** 10

If TEAM_SIZE_OVERRIDE is set (from `--team N`), use that value instead (still clamped to 3–10).

Build STACK_CONTEXT containing the detected stack info, APP_TYPE, file count, project size, key file paths, and any relevant excerpts from CLAUDE.md/README.md. Keep it under 500 words.

---

## Specialist Pool

Each specialist has a name, file slug, one-line role, categories, tags (which APP_TYPEs it's relevant to), and a mandatory flag.

### Mandatory Specialists (always selected unless explicitly skipped)

| # | Specialist | Slug | Skip Flag | Tags | Categories |
|---|---|---|---|---|---|
| 1 | Security Engineer | `security` | --skip-security | all | Auth, injection, input validation, secrets, API security, dependencies/CVEs |
| 2 | Testing/QA Analyst | `testing-qa` | --skip-testing | all | Coverage (unit/integration/e2e, **flag <80% as CRITICAL**), code duplication (**flag as WARNING**), test quality, CI/CD pipeline, test infra, test patterns |
| 3 | Cloud Cost Analyst | `cloud-cost` | --skip-cloud | all | Compute, database, networking, caching/CDN, reserved capacity, storage |
| 4 | SEO Specialist | `seo` | --skip-seo | all | Meta tags, Open Graph, structured data (schema.org), Core Web Vitals, crawlability (robots.txt, sitemap.xml), canonical URLs, semantic HTML, heading hierarchy, image alt text, internal linking, URL structure |
| 5 | Test Sense-Checker | `test-review` | --skip-test-review | all | Assertion quality (behavior vs implementation), mock overuse, tautological assertions, flaky patterns, dead/skipped tests, test-to-code coupling, test naming clarity |
| 6 | Coding Defaults Enforcer | `coding-defaults` | --skip-defaults | all | TDD evidence, Playwright setup & CLI tools, visual regression tests (screenshots, baselines), browser simulation (real browsers vs jsdom), test recording/tracing |

### Domain Specialists (selected by tag match + relevance order)

| # | Specialist | Slug | Tags | Categories |
|---|---|---|---|---|
| 7 | Software Architect | `architecture` | web,server,cli,mobile,library,saas | Boundaries, data flow, API design, patterns, scalability |
| 8 | Complexity Analyst | `complexity` | web,server,cli,mobile,library,saas | File metrics, coupling, **code duplication** (flag as red flag), dependency health, maintenance burden |
| 9 | UX Designer | `usability` | web,mobile,saas | Navigation, loading/error states, forms, a11y, responsive, feedback |
| 10 | Web Designer | `visual-design` | web | Design system, color, typography, spacing, dark mode, polish |
| 11 | Mobile UX Designer | `mobile-ux` | mobile | Navigation, touch, platform conventions, offline, accessibility |
| 12 | Mobile Performance | `mobile-perf` | mobile | Rendering, battery/network, memory, startup, bundle size |
| 13 | CLI UX Specialist | `cli-ux` | cli | Command structure, help/docs, I/O, progress, config, errors |
| 14 | Cross-Platform Engineer | `cross-platform` | cli,mobile | Platform compat, distribution, file system, shell integration |
| 15 | SRE / Reliability | `reliability` | server,saas | Health checks, error recovery, observability, degradation, deployment |
| 16 | DevOps / SysAdmin | `operations` | server,saas | Config management, resource limits, process mgmt, backup, monitoring |
| 17 | Performance Engineer | `performance` | server,saas | DB perf, API latency, memory/CPU, concurrency, caching, load testing |
| 18 | API Design Reviewer | `api-design` | library | Public API surface, type safety, error handling, versioning |
| 19 | Documentation Reviewer | `documentation` | library | README, API docs, migration guides, examples |
| 20 | Compatibility Analyst | `compatibility` | library | Runtime compat, bundler compat, peer deps, package config |

### SaaS Business Specialists

| # | Specialist | Slug | Tags | Categories |
|---|---|---|---|---|
| 21 | Revenue Strategist | `revenue` | saas | Pricing model, monetization, payment integration, feature gating, revenue leakage |
| 22 | Growth/Marketing Analyst | `growth` | saas | Analytics/tracking, onboarding flow, acquisition, conversion funnels |
| 23 | Sales Engineer | `sales-readiness` | saas | API/integration readiness, enterprise features (SSO, SCIM, audit), multi-tenancy, compliance |

### Relevance Order by APP_TYPE

Fill remaining team slots (after mandatory specialists) in this order:

Stability and user experience are the highest priorities. The order below reflects this — UX/UI specialists come before infrastructure ones.

- **web:** UX Designer, Web Designer, Architect, Complexity
- **server:** SRE, Architect, Performance, DevOps, Complexity
- **cli:** CLI UX, Architect, Cross-Platform, Complexity
- **mobile:** Mobile UX, Mobile Perf, Architect, Cross-Platform, Complexity
- **library:** API Design, Architect, Documentation, Compatibility, Complexity
- **saas:** SRE, UX Designer, Architect, Revenue Strategist, Growth Analyst, Sales Engineer, Performance, Complexity

---

## Step 1.5 — Team Assembly & Approval

### Assembly algorithm

1. Start with mandatory specialists (Security, Testing/QA, Cloud Cost, SEO, Test Sense-Checker, Coding Defaults Enforcer) — remove any that have their skip flag set
2. From the relevance-ordered list for the current APP_TYPE, add specialists until TEAM_SIZE is reached
3. Assign output file numbers sequentially: `01-{slug}.md`, `02-{slug}.md`, etc.

### Display proposed team

```
Project: {name} ({APP_TYPE}, {size} — {file_count} files)
Scope: {full | N files from recent commits | N files from timeframe}

Proposed team ({TEAM_SIZE} specialists):
  1. Security Engineer           [mandatory]
  2. Testing/QA Analyst          [mandatory]
  3. Cloud Cost Analyst          [mandatory]
  4. SEO Specialist              [mandatory]
  5. Test Sense-Checker          [mandatory]
  6. Coding Defaults Enforcer    [mandatory]
  7. Software Architect
  ...

Accept [enter], expand [e], or customize [c]?
```

### Handle response

- **Accept** (or if `--team auto` was set): proceed immediately with proposed team
- **Expand [e]**: show the remaining pool members not selected, user picks by number (comma-separated) to add
- **Customize [c]**: show the full pool with numbers, user picks exactly which specialists to use (comma-separated). Mandatory specialists are pre-selected but can be removed.

---

## Step 2 — Spawn specialist agents in parallel

Launch all selected specialists in a SINGLE message using the Agent tool with `run_in_background=true`. Each agent is `subagent_type="general-purpose"`.

### Agent prompt template

For each specialist, build the prompt from this template:

```
You are a {SPECIALIST_NAME} analyzing a {APP_TYPE} application.

{STACK_CONTEXT}

{FILE_SCOPE_BLOCK}

Focus on these categories: {CATEGORIES}

Discover by reading relevant source files, configs, and patterns.
Verify every file you cite exists using Glob/Grep.

RULES:
- You are analyzing the codebase in the current working directory.
- Only cite files that actually exist — use Glob and Grep to verify before citing.
- Be specific: include file paths with line numbers (path/to/file.ts:42).
- Be actionable: every finding must have a concrete recommendation.
- Use severity levels: CRITICAL (must fix — security hole, data loss, broken UX), WARNING (should fix — degraded experience, tech debt, cost waste), INFO (nice to have — polish, optimization).
- Code duplication is always a red flag — flag duplicated logic/patterns as WARNING with specific file pairs.
- Test coverage below 80% is CRITICAL. Estimate coverage by comparing test files to source files. Flag untested critical paths.
- If a dimension does not apply to this codebase, write a short "Not Applicable" report explaining why.
- Write your report to the specified output file using the Write tool.

Write your report in this exact format:

# {Dimension} Analysis

**Date:** {today's date}
**Stack:** {detected stack summary}
**App Type:** {APP_TYPE}
**Severity Summary:** {N} critical, {N} warning, {N} info

## {Category Name}

### [CRITICAL] {Finding title}
**Files:** `path/to/file.ts:42`, `other/file.py:15`
**Issue:** {clear description of the problem}
**Impact:** {why this matters — what breaks, what's at risk}
**Recommendation:** {specific steps to fix}

### [WARNING] {Finding title}
...

(repeat for all findings across all categories)

---
**Verdict:** {One sentence overall assessment of this dimension}

Write your report to .analysis/{NN}-{SLUG}.md
```

### Specialist-specific prompt additions

When building the agent prompt for these specialists, **append** the following instructions after the generic template:

**SEO Specialist (`seo`):**
```
ADDITIONAL SEO INSTRUCTIONS:
- Check <meta> tags (title, description, viewport, charset), OG/Twitter cards, structured data (JSON-LD / schema.org)
- Check for robots.txt, sitemap.xml, canonical URLs
- SPA without SSR/SSG = CRITICAL finding (invisible to crawlers without pre-rendering)
- Check for Lighthouse/PageSpeed CI integration (e.g. in GitHub Actions, CI config)
- Verify semantic HTML: proper heading hierarchy (single h1, h2>h3), landmark elements, image alt text
- Check internal linking structure, URL patterns (human-readable, no hash-only routing)
- For CLI/library apps (no web frontend): only check docs site SEO if one exists. If no docs site, produce a "Not Applicable" report explaining why and suggesting docs site creation.
```

**Test Sense-Checker (`test-review`):**
```
ADDITIONAL TEST REVIEW INSTRUCTIONS:
- READ actual test files — do not just count them. Examine assertions line by line.
- Flag these anti-patterns:
  * toBeDefined-only assertions (testing existence, not behavior)
  * Over-mocked tests (>3 mocks in a single test = WARNING, all deps mocked = CRITICAL)
  * Implementation-detail testing (testing private methods, internal state, CSS selectors)
  * No-assertion tests (test body with no expect/assert)
  * Snapshot tests >50 lines (brittle, rarely reviewed)
  * Mismatched test descriptions (describe/it text doesn't match what's tested)
  * Dead/permanently-skipped tests (.skip, xit, @disabled for >30 days)
  * Flaky patterns: time-dependent, order-dependent, shared mutable state
- Produce a "Test Health Score":
  * Meaningful (>70% of tests validate correct behavior)
  * Mixed (30-70%)
  * Ceremonial (<30% — tests exist for coverage metrics only)
- IMPORTANT: Testing/QA Analyst covers coverage metrics. YOUR focus is whether tests validate correct behavior, not whether they exist.
```

**Coding Defaults Enforcer (`coding-defaults`):**
```
ADDITIONAL CODING DEFAULTS INSTRUCTIONS:
- TDD Evidence:
  * Check git history for test-before-code patterns (test commits preceding implementation commits)
  * Check test file naming conventions (*.test.ts, *.spec.ts, test_*.py)
  * Check for test directory structure mirroring source directory structure
  * No TDD evidence in a project with >10 source files = WARNING
- Playwright:
  * Check for playwright.config.ts/js, @playwright/test in dependencies
  * Check for test files using Playwright (*.spec.ts in e2e/ or tests/ dirs)
  * Check for npx playwright codegen / show-trace usage in scripts or docs
  * Check CI integration (playwright in GitHub Actions / CI config)
  * Web app without Playwright or equivalent E2E framework = WARNING
- Visual Regression:
  * Check for toHaveScreenshot() calls, Percy, Chromatic, BackstopJS, or similar
  * Check for .png baseline files in test directories
  * Web app with UI components but no visual regression testing = WARNING
- Browser Simulation:
  * Flag if jsdom/happy-dom is the ONLY test environment for a web app (WARNING — not real browser testing)
  * Check for webServer config in Playwright/test config
  * Check for tracing setup (trace: 'on-first-retry' or similar)
- Web app with ZERO end-to-end tests = CRITICAL
```

When FILE_SCOPE is non-empty, the FILE_SCOPE_BLOCK is:
```
SCOPE: Focus analysis on these recently-changed files and their immediate
dependencies. Reference other files for context, but prioritize scoped files.
Files: {FILE_SCOPE}
```
When FILE_SCOPE is empty, omit the block entirely.

---

## Step 3 — Collect results

After launching all agents, wait for them to complete (you will be notified as each background agent finishes).

Once ALL agents have completed:

1. Verify each expected `.analysis/*.md` file exists and has content (use Glob and Read)
2. Print a status table:
   ```
   Analysis Status (APP_TYPE: {type}, Team: {N} specialists):
   [done] 01-{slug}.md       (N findings)
   [done] 02-{slug}.md       (N findings)
   [done] 03-{slug}.md       (N findings)
   ...
   ```
   Count findings by grepping for `### \[` in each file.

If any agent failed to produce output, note it as `[FAILED]` and continue with available reports.

---

## Step 4 — Spawn synthesis agent (foreground)

Launch a single foreground Agent (subagent_type="general-purpose") with this prompt:

"You are a technical lead synthesizing specialist analysis reports into a unified, prioritized improvement plan.

Read all available `.analysis/0*.md` files. Then write `.analysis/REPORT.md` in this format:

```markdown
# Application Analysis Report

**Date:** {today's date}
**Stack:** {stack summary}
**App Type:** {APP_TYPE}

## Executive Summary
{3-5 sentences: overall health, biggest risks, biggest opportunities}

## Scorecard

| Dimension | Health | Critical | Warnings | Top Issue |
|-----------|--------|----------|----------|-----------|
| {Specialist 1 dimension} | Good/Fair/Needs Work | N | N | one-liner |
| {Specialist 2 dimension} | ... | ... | ... | ... |
| ... | ... | ... | ... | ... |

## Priority 1: Do Now (Critical)
Items that pose immediate risk — security holes, data loss, broken UX.
For each item:
### N. {Title}
**Effort:** Quick Win / Medium / Large
**Dimensions:** {which dimensions flagged this}
**Issue:** {consolidated description}
**Action:** {specific fix}

## Priority 2: Do Soon (Important)
Items flagged as WARNING by multiple dimensions, or CRITICAL by one.

## Priority 3: Do Later (Improvement)
Single-dimension warnings and quality-of-life improvements.

## Priority 4: Nice to Have (Polish)
INFO-level items and optimizations.

## Compound Wins
Changes that improve multiple dimensions simultaneously. For each:
### {Title}
**Improves:** {Dimension 1}, {Dimension 2}, ...
**Action:** {what to do}
**Why it's a compound win:** {explanation}

{SAAS_SYNTHESIS_SECTIONS}

## Recommended Phases
Group the above into implementation phases:
### Phase 1: {Name} — Effort: {T-shirt size}
- Item 1
- Item 2

### Phase 2: {Name} — Effort: {T-shirt size}
...
```

Guidelines:
- Cross-reference findings: if Security and Architecture both flag the same area, merge them into one finding.
- Prioritize: CRITICAL > multi-dimension WARNING > single-dimension WARNING > INFO
- Be concrete about effort: Quick Win = <1 hour, Medium = 1-4 hours, Large = 1+ days
- Identify at least 3 compound wins if they exist.
- Keep the executive summary honest — don't sugarcoat, but acknowledge strengths."

### SaaS synthesis additions

When APP_TYPE is `saas`, replace `{SAAS_SYNTHESIS_SECTIONS}` with:

```
## Revenue Opportunities
Findings that represent monetization or growth opportunities.
Prioritize by estimated revenue impact (high/medium/low).

## Go-to-Market Readiness
- Self-serve readiness: onboarding, pricing page, payment flow
- Enterprise readiness: SSO, compliance, multi-tenancy, audit logging
- What is blocking each channel?
```

For non-saas APP_TYPEs, omit `{SAAS_SYNTHESIS_SECTIONS}` entirely.

---

## Step 5 — Catch-and-Fix Phase

Skip this entire step if SKIP_FIX is true.

### 5a. Extract actionable issues

Read `.analysis/REPORT.md`. Pull all Priority 1 and Priority 2 items. **Exclude:**
- Large architectural changes (effort = "Large")
- INFO-level items
- Items requiring external service changes (third-party APIs, DNS, CDN config)

Build an ISSUES list with: issue number, title, severity, effort, target file(s), and source dimension(s).

### 5b. Generate fix plan

For each actionable issue, determine:
- **Target files** with specific line numbers
- **Change description** (what exactly to modify)
- **Risk level** (Low = isolated change, Medium = touches shared code, High = cross-cutting)
- **Dependencies** (other fixes that must happen first or simultaneously)

Group fixes by target file. Present as a table:

```
Fix Plan ({N} actionable issues):

| # | Issue | Files | Risk | Effort | Dependencies |
|---|-------|-------|------|--------|-------------|
| 1 | {title} | path/file.ts:42 | Low | Quick Win | — |
| 2 | {title} | path/file.ts:88, other.ts:12 | Medium | Quick Win | #1 |
| ... | ... | ... | ... | ... | ... |
```

### 5c. Approval gate

Present the fix plan and ask:

```
Approve all [a], select specific by number [1,3,5], skip [s], or reject [r]?
```

- **Approve all**: proceed with all fixes
- **Select specific**: proceed with only the numbered fixes
- **Skip**: skip the fix phase entirely, continue to Step 6
- **Reject**: skip the fix phase entirely, continue to Step 6

**Do NOT proceed without explicit user approval.**

### 5d. Spawn fix agents

For each approved fix group (grouped by target file), launch a background Agent (`subagent_type="general-purpose"`):

```
You are a surgical code fixer. Apply ONLY the specified fixes — do not refactor, reformat, or improve surrounding code.

Fix to apply:
{FIX_DESCRIPTION}

Target file(s): {FILE_PATHS}

RULES:
- Read the target file(s) first using the Read tool
- Make the minimal change needed to fix the issue
- Do NOT refactor surrounding code
- Do NOT add comments explaining the fix
- Do NOT change formatting of untouched lines
- Use the Edit tool for all changes
- After applying fixes, write a summary to .analysis/fixes/{NN}-fix-summary.md containing:
  * What was changed
  * Files modified with line numbers
  * Before/after snippets (brief)
```

### 5e. Verify fixes

After all fix agents complete:

1. **Auto-detect test suite:** Look for `package.json` scripts (test/test:unit/test:e2e), `pytest.ini`/`pyproject.toml` [tool.pytest], `Cargo.toml`, `go.mod`, `Makefile` (test target). Run the first matching command:
   - `npm test` / `yarn test` / `pnpm test`
   - `pytest`
   - `cargo test`
   - `go test ./...`
   - `make test`

2. **Present results table:**
   ```
   Fix Verification:
   | # | Fix | Status | Details |
   |---|-----|--------|---------|
   | 1 | {title} | PASS | All tests pass |
   | 2 | {title} | FAIL | test_auth.py:42 — AssertionError |
   | ... | ... | ... | ... |
   ```

3. **On test failure**, ask:
   ```
   Tests failed after fixes. Options:
   - Auto-fix [a] (max 2 retries)
   - Revert all fixes [ra]
   - Revert specific [r1,r3]
   - Continue anyway [c]
   ```
   - Auto-fix: spawn a fix agent targeting the failing test, retry up to 2 times
   - Revert: use `git checkout -- {files}` to revert specified files
   - Continue: proceed with failing tests (user accepts the state)

4. **On success:** All tests pass — fixes are ready.

### 5f. Update synthesis report

Launch a foreground Agent (`subagent_type="general-purpose"`) to update the report:

```
You are updating the analysis report after fixes were applied.

Read .analysis/REPORT.md and all .analysis/fixes/*-fix-summary.md files.

Update REPORT.md:
1. Add a "## Fixes Applied" section after the Scorecard, listing each fix with status (PASS/FAIL/REVERTED)
2. In Priority 1 and Priority 2 sections, mark fixed items with [FIXED] prefix on their title
3. Update the Scorecard health ratings if fixes improved a dimension (e.g., Security went from "Needs Work" to "Fair")
4. Update the Executive Summary to reflect fixes applied (e.g., "X of Y critical issues were automatically resolved")

Write the updated report back to .analysis/REPORT.md
```

---

## Step 6 — Present results

After the synthesis (and optional fix) phase completes:

1. Read `.analysis/REPORT.md`
2. Print the Executive Summary and Scorecard table from the report
3. Print the Priority 1 items (just titles and effort)
4. Print compound wins (just titles)
5. If fixes were applied, print fix summary: issues fixed vs total, skipped items, test status
6. Print file listing with line counts

---

## Step 7 — GSD Integration

Skip this step if SKIP_GSD is true.

Check if `~/.claude/commands/gsd/` exists. If it does:

1. Check if `.planning/PROJECT.md` exists (i.e., GSD project already initialized).
   - **If yes (brownfield/existing project):** Automatically invoke `/gsd:new-milestone` and reference `.analysis/REPORT.md` as the requirements source. Tell the user you are creating a new GSD milestone from the recommended phases.
   - **If no (greenfield):** Automatically invoke `/gsd:new-project` and reference `.analysis/REPORT.md` as the requirements source. Tell the user you are creating a GSD project from the recommended phases.

If GSD commands don't exist, say: "Full analysis available in `.analysis/REPORT.md`. Install GSD to auto-create a project from these phases." and stop.
