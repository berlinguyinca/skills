---
name: review-app
description: Analyze any application across specialist dimensions with role-adapted agents
argument-hint: "[--skip-cloud] [--skip-planning] [--skip-gsd] [--skip-testing] [--skip-security] [--skip-seo] [--skip-test-review] [--skip-defaults] [--skip-fix] [--skip-pptx] [--skip-recommend] [--skip-simplify] [--skip-test-gen] [--type web|server|cli|mobile|library|saas] [--scope full|recent|recent:N|timeframe:<spec>] [--team auto|ask|N] [--hire|--fire|--roster]"
---

## Step 0 — Preamble

Resolve the gw-skills repo path, then read and follow `$GW_REPO/.claude/commands/gw/_shared/preamble.md` for update check and GSD project detection:

```bash
GW_REPO="$(cd "$(readlink ~/.claude/commands/gw)/../../.." 2>/dev/null && pwd)" || GW_REPO="$HOME/.gw-skills"
```

GW_REPO persists for the duration of this skill run — do not re-resolve it in later steps.

---

You are an orchestrator for a multi-dimensional application analysis. You assemble a **tailored team of specialists** based on the project's type, size, and complexity. Follow these steps precisely.

Parse the arguments: "$ARGUMENTS"
- If "--skip-cloud" or "--skip-aws" is present, set SKIP_CLOUD=true
- If "--skip-planning" or "--skip-gsd" is present, set SKIP_PLANNING=true
- If "--skip-testing" is present, set SKIP_TESTING=true
- If "--skip-security" is present, set SKIP_SECURITY=true
- If "--skip-seo" is present, set SKIP_SEO=true
- If "--skip-test-review" is present, set SKIP_TEST_REVIEW=true
- If "--skip-defaults" is present, set SKIP_DEFAULTS=true
- If "--skip-fix" is present, set SKIP_FIX=true
- If "--skip-pptx" is present, set SKIP_PPTX=true
- If "--skip-recommend" is present, set SKIP_RECOMMEND=true
- If "--skip-simplify" is present, set SKIP_SIMPLIFY=true
- If "--skip-test-gen" is present, set SKIP_TEST_GEN=true
- If "--type X" is present, set FORCED_TYPE=X (one of: web, server, cli, mobile, library, saas)
- If "--scope X" is present, set SCOPE_MODE=X (one of: full, recent, recent:N, timeframe:<spec>). Default: full
- If "--team X" is present: if X is a number, set TEAM_MODE=auto and TEAM_SIZE_OVERRIDE=X (overrides complexity-based sizing). If X is "auto" or "ask", set TEAM_MODE=X. Default: auto
- If "--hire", "--fire", or "--roster" is present: tell the user "Use `/gw:workforce` for persona management. Examples: `/gw:workforce --hire "Name" --background "..."`, `/gw:workforce --fire "Name"`, `/gw:workforce --roster`" and stop.

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

**COVERAGE_TARGET: 80%** — referenced throughout this skill as the minimum acceptable test coverage.

Compute the project size with a fast glob `**/*` excluding `node_modules`, `.git`, `dist`, `build`, `vendor`, `__pycache__`, `.next`. If the glob takes >10 seconds, fall back to `git ls-files | wc -l` for the file count:

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

**Maximum:** 10

If TEAM_SIZE_OVERRIDE is set (from `--team N`), use that value instead (still clamped to 3–10).

Build STACK_CONTEXT containing the detected stack info, APP_TYPE, file count, project size, key file paths, and any relevant excerpts from CLAUDE.md/README.md. Keep it under 500 words.

---

## Step 1.5 — Team Assembly

**Team suggestion table for this skill:**

| APP_TYPE | Suggested Team |
|----------|---------------|
| web | UX Designer, Web Designer, Architect, Complexity |
| server | SRE, Architect, Performance, DevOps, Complexity |
| cli | CLI UX, Architect, Cross-Platform, Complexity |
| mobile | Mobile UX, Mobile Perf, Architect, Cross-Platform, Complexity |
| library | API Design, Architect, Documentation, Compatibility, Complexity |
| saas | SRE, UX Designer, Architect, Revenue Strategist, Growth Analyst, Sales Engineer, Performance, Complexity |

Context line for approval gate: `Project: {PROJECT_NAME} ({APP_TYPE})`

Read and follow `$GW_REPO/.claude/commands/gw/_shared/team-assembly.md` using the table above for team suggestions.

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
- Test coverage below the coverage threshold (80%) is CRITICAL. Estimate coverage by comparing test files to source files. Flag untested critical paths. Coverage enforcement in Step 5g will generate tests for uncovered code — list the TOP 10 uncovered files/functions to feed that step (Step 5g will pick the top 5 most critical from that list).
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

When building the agent prompt for a specialist, check if the persona file has content after the frontmatter (`prompt_additions` from Step 1e). If it does, **append** that content after the generic template as specialist-specific instructions.

For example, the SEO Specialist, Test Sense-Checker, and Coding Defaults Enforcer persona files include additional instructions that are appended to their agent prompts automatically.

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

### 5d. Generate fix manifest and execute

Group approved fixes into independent bundles by logical concern:

| Bundle | Contains |
|--------|----------|
| `security-fixes` | All CRITICAL and WARNING security findings |
| `performance-fixes` | All performance findings |
| `test-coverage` | All missing test / coverage gap findings |
| `quality-fixes` | All clarity, maintainability, and other findings |

Skip any bundle that has zero approved fixes.

For each bundle:
- Set `name` to the bundle slug (e.g., `security-fixes`)
- Set `description` to a summary of all fixes in the bundle
- Derive `acceptance_tests` from each review finding:
  - Security: "XSS vulnerability in <file>:<line> is patched", "SQL injection in <file>:<line> is parameterized"
  - Performance: "Response time for <endpoint> improved", "<function> avoids N+1 query"
  - Test coverage: "Coverage for <module> reaches 80%", "Critical path <X> has regression test"
  - Quality: "Dead code in <file> removed", "Function <X> has clear naming"
- Set `spec_file` to `.analysis/REPORT.md`
- Set `dependencies` to empty (fix bundles are independent)
- Set `files_hint` to the target files for each bundle

Set `project` to `review-fix`.

Write manifest to `.analysis/fix-manifest.json`.

Commit: `git add .analysis/fix-manifest.json && git commit -m "feat: generate fix manifest from review findings"`

Invoke `/gw:worktree execute .analysis/fix-manifest.json` directly (no y/m/s prompt — user already approved fixes at the approval gate in Step 5c).

After execution completes, continue to the next step (simplification, test generation, etc.).

### 5e. Verify fixes

After all fix agents complete:

1. **Auto-detect test suite** using this priority order:
   - **package.json** — look for `scripts.test`, `scripts.test:unit`, or `scripts.test:ci`. Run via `npm test` (or `yarn test` / `pnpm test` if lockfile present)
   - **pyproject.toml** / **pytest** — check for `[tool.pytest]` section, `pytest.ini`, or `setup.cfg` with pytest config. Run via `pytest`
   - **Cargo.toml** — run `cargo test`
   - **go.mod** — run `go test ./...`
   - **Makefile** — check for `test`, `check`, or `verify` targets. Run via `make test`

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

### 5f. Code Simplification

Skip this sub-step if SKIP_SIMPLIFY is true OR no fixes were applied in Step 5d.

Launch a **foreground** Agent (`subagent_type="code-simplifier:code-simplifier"`) with this prompt:

```
You are simplifying code that was just modified by automated fix agents.

Read all .analysis/fixes/*-fix-summary.md files to identify which files were modified.

For each modified file:
1. Read the file
2. Review for: duplicated logic, unnecessary complexity, inconsistent style, dead code, missed utility reuse
3. Apply minimal, obvious simplifications using the Edit tool
4. Preserve all existing behavior — do not change semantics

RULES:
- Only touch files that were modified by fix agents (listed in fix summaries)
- Do NOT refactor unrelated code
- Do NOT add comments or documentation
- Keep changes minimal and obvious — if a simplification is debatable, skip it
- Prefer removing dead code and deduplicating over restructuring

After simplifications, write .analysis/fixes/simplification-summary.md containing:
- Files simplified with brief description of each change
- Total lines removed/changed
- "No simplifications needed" if nothing was worth changing
```

After simplification completes, re-run the test suite (same detection as Step 5e). If tests fail, revert all simplifications using `git checkout -- {files}` and note "Simplifications reverted due to test failure" in the summary.

### 5g. Coverage Enforcement

Skip this sub-step if SKIP_TESTING is true OR SKIP_TEST_GEN is true.

Read the QA Engineer's report from `.analysis/*-testing-qa.md` for coverage data.

**If coverage >= 80%:** Print "Coverage is at {N}% — above 80% threshold, skipping test generation." and proceed to Step 5h.

**If coverage < 80%:**

1. **Select targets:** Pick up to 5 lowest-coverage critical-path files from the QA report. Prioritize: auth, payment, data mutation > utility, formatting.

2. **Detect test patterns:** Read 2-3 existing test files to identify: test framework (Jest, pytest, Go testing, etc.), naming conventions, directory structure, assertion style, mock patterns.

3. **Generate tests:** Launch up to 5 parallel **background** Agents (`subagent_type="general-purpose"`, `run_in_background=true`), each writing tests for one uncovered module:

```
You are a test writer generating meaningful tests for an uncovered module.

Target file: {FILE_PATH}
Test framework: {DETECTED_FRAMEWORK}
Test directory: {DETECTED_TEST_DIR}
Naming convention: {DETECTED_NAMING}

Write tests that:
- Test actual behavior, not implementation details
- Cover the happy path + 2 edge cases minimum
- Follow existing test patterns exactly (framework, assertions, file naming)
- Mock only external dependencies (network, filesystem, databases)
- Do NOT mock internal modules
- Write the test file to {TEST_FILE_PATH}

After writing, list what you tested and why in a brief summary.
```

4. **Verify tests:** After all test-generation agents complete, run the test suite. For each failing new test:
   - Spawn a fix agent (1 retry attempt)
   - If still failing after retry, delete the test file
   - Note deleted tests in summary

5. **Measure delta:** If a coverage tool is available, re-run coverage and report the delta (before → after).

6. **Write summary:** Write `.analysis/fixes/coverage-enforcement-summary.md` containing:
   - Coverage before and after (if measurable)
   - Tests generated: file path, what it tests, pass/fail status
   - Tests deleted (if any) with reason
   - Remaining coverage gap (if still < 80%)

### 5h. Update synthesis report

Launch a foreground Agent (`subagent_type="general-purpose"`) to update the report:

```
You are updating the analysis report after fixes were applied.

Read .analysis/REPORT.md and all .analysis/fixes/*-fix-summary.md files.

Update REPORT.md:
1. Add a "## Fixes Applied" section after the Scorecard, listing each fix with status (PASS/FAIL/REVERTED)
2. In Priority 1 and Priority 2 sections, mark fixed items with [FIXED] prefix on their title
3. Update the Scorecard health ratings if fixes improved a dimension (e.g., Security went from "Needs Work" to "Fair")
4. Update the Executive Summary to reflect fixes applied (e.g., "X of Y critical issues were automatically resolved")
5. If .analysis/fixes/simplification-summary.md exists, add a "## Simplifications Applied" section after "Fixes Applied" listing each simplification with affected files
6. If .analysis/fixes/coverage-enforcement-summary.md exists, add a "## Tests Generated" section with coverage delta (before/after percentage) and list of generated test files

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

## Step 7 — Implementation Planning

Skip this step if SKIP_PLANNING is true.

Present the implementation options:

```
Analysis complete. How would you like to proceed?
  [p] Superpowers — invoke superpowers:writing-plans from REPORT.md (recommended)
  [g] GSD — create project/milestone from analysis
  [d] Done — handle implementation manually
```

**If [p] (default/recommended):** Tell the user: "Invoking superpowers:writing-plans. The plan will use `.analysis/REPORT.md` as the requirements source." Then invoke the Skill tool: `Skill(skill="superpowers:writing-plans")`.

**If [g]:** Check if `~/.claude/commands/gsd/` exists. If it does:
1. Check if `.planning/PROJECT.md` exists (i.e., GSD project already initialized).
   - **If yes (brownfield/existing project):** Automatically invoke `/gsd:new-milestone` and reference `.analysis/REPORT.md` as the requirements source. Tell the user you are creating a new GSD milestone from the recommended phases.
   - **If no (greenfield):** Automatically invoke `/gsd:new-project` and reference `.analysis/REPORT.md` as the requirements source. Tell the user you are creating a GSD project from the recommended phases.
If GSD commands don't exist, say: "GSD not installed. Use [p] Superpowers instead, or find the full analysis in `.analysis/REPORT.md`."

**If [d]:** Say "Full analysis available in `.analysis/REPORT.md`." and continue.

---

## Step 8 — Generate Findings Presentation

Skip this step if SKIP_PPTX is true.

### 8a. Gather presentation data

1. Read `.analysis/REPORT.md` — extract Executive Summary, Scorecard, Priority 1-2 items, Compound Wins, Recommended Phases, and (if present) Fixes Applied section.
2. Detect the default branch: `git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@'` — fall back to `main` then `master`.
3. If on a non-default branch, run `git diff --stat {default_branch}...HEAD` to capture what changed compared to the default branch. Parse the diff stat into a list of: file path, lines added, lines removed.
4. If on the default branch (no diff), skip the "Changes vs Default Branch" slide — focus only on findings.

### 8b. Build JSON data file

Write a JSON file to `/tmp/review_app_presentation_data.json` with this schema:

```json
{
  "project_name": "{project name from Step 1}",
  "app_type": "{APP_TYPE}",
  "date": "{today's date}",
  "stack_summary": "{stack summary from STACK_CONTEXT}",
  "executive_summary": "{text from REPORT.md Executive Summary}",
  "scorecard": [
    { "dimension": "Security", "health": "Good", "critical": 0, "warnings": 2, "top_issue": "..." }
  ],
  "priority_1_items": [
    { "title": "...", "effort": "Quick Win", "dimensions": "Security, Architecture", "fixed": false }
  ],
  "priority_2_items": [
    { "title": "...", "effort": "Medium", "dimensions": "Testing", "fixed": true }
  ],
  "compound_wins": [
    { "title": "...", "improves": ["Security", "Performance"], "action": "..." }
  ],
  "phases": [
    { "name": "Phase 1: Critical Fixes", "effort": "S", "items": ["item1", "item2"] }
  ],
  "fixes_applied": {
    "total": 5,
    "passed": 4,
    "failed": 0,
    "reverted": 1
  },
  "branch_diff": {
    "has_diff": true,
    "default_branch": "main",
    "current_branch": "feat/analysis-fixes",
    "files_changed": 12,
    "insertions": 340,
    "deletions": 85,
    "file_stats": [
      { "file": "src/auth.ts", "added": 45, "removed": 12 }
    ]
  }
}
```

If no fixes were applied, set `fixes_applied` to `null`. If on the default branch, set `branch_diff.has_diff` to `false`. Cap `file_stats` to the top 10 files sorted by total churn (added + removed) to keep the JSON and slide manageable for large repos.

### 8c. Write and execute the Python presentation script

Write a Python script to `/tmp/review_app_presentation.py`. The script reads the JSON data file and generates a `.pptx` presentation.

**Design system** (matches `gw:weekly-review` palette — the canonical gw-skills design system. Note: `gw:merge-it` uses a slightly different palette; it should be aligned in a future update):

```
PRIMARY      = RGBColor(0x2C, 0x3E, 0x50)  # dark blue-gray — titles, headers
SECONDARY    = RGBColor(0x34, 0x49, 0x5E)  # medium blue-gray — body text
ACCENT       = RGBColor(0x34, 0x98, 0xDB)  # bright blue — highlights, KPIs
SUCCESS      = RGBColor(0x27, 0xAE, 0x60)  # green — good health, fixed items
DANGER       = RGBColor(0xE7, 0x4C, 0x3C)  # red — critical items
WARNING      = RGBColor(0xF3, 0x9C, 0x12)  # amber — warnings
MUTED        = RGBColor(0x95, 0xA5, 0xA6)  # gray — captions, labels
BG_WHITE     = RGBColor(0xFF, 0xFF, 0xFF)
BG_LIGHT     = RGBColor(0xF8, 0xF9, 0xFA)
```

- Font: Calibri throughout
- Slide dimensions: 16:9 widescreen (13.333" x 7.5")
- Title: 32pt bold PRIMARY
- Heading: 24pt bold PRIMARY
- Body: 14pt SECONDARY
- KPI Value: 36pt bold ACCENT
- KPI Label: 11pt uppercase MUTED
- Accent bar: 0.06" wide ACCENT strip at left edge of every slide

**Slide structure:**

1. **Title Slide** — Project name, "Application Analysis Report", date, app type badge, stack summary subtitle
2. **Executive Summary Slide** — Executive summary text in a card layout with the overall health verdict
3. **Scorecard Slide** — Table with dimension, health (color-coded: green/amber/red), critical count, warning count, top issue. Use colored rectangles as health indicators.
4. **Critical Issues Slide(s)** — Priority 1 items. Each item: title, effort badge (colored shape), dimensions, [FIXED] badge if applicable. If >5 items, split across multiple slides.
5. **Important Issues Slide** — Priority 2 items in condensed format (title + effort only). Mark [FIXED] items with green checkmark.
6. **Compound Wins Slide** — Each compound win: title, which dimensions improve (as colored badges), action summary.
7. **Changes vs Default Branch Slide** (only if `branch_diff.has_diff` is true) — Branch comparison header (current vs default), file change count, insertions/deletions as colored bars (green for added, red for removed), top 10 changed files as a mini table.
8. **Fix Summary Slide** (only if `fixes_applied` is not null) — Donut-style visual: passed (green), failed (red), reverted (amber). Issue count comparison: "X of Y critical issues resolved".
9. **Recommended Phases Slide** — Phase timeline as horizontal cards: Phase 1 → Phase 2 → Phase 3, each with T-shirt size effort badge and item count.
10. **Closing Slide** — "Full report: `.analysis/REPORT.md`", date, "Generated by gw:review-app"

**Script execution:**

```bash
mkdir -p docs/gw
uv run --with python-pptx python /tmp/review_app_presentation.py
```

Fallback: `python3 -m pip install python-pptx && python3 /tmp/review_app_presentation.py`

If both fail, tell the user: "PowerPoint generation failed — python-pptx is required. Install it with `pip install python-pptx` or use `--skip-pptx` to skip presentation generation." Do not generate an HTML fallback.

**Output path:** `docs/gw/analysis-report-{YYYY-MM-DD}.pptx` (all gw-skills use `docs/gw/` for generated presentations)

### 8d. Present result

Tell the user: "Presentation saved to `docs/gw/analysis-report-{date}.pptx`"

If the project is a git repo with uncommitted changes to the presentation file, ask: "Commit the presentation to the branch? [y/n]"

If yes:
```bash
git add docs/gw/analysis-report-*.pptx
git commit -m "docs: add analysis findings presentation"
```

## Step 9 — Skill Recommendations & Auto-Install

Skip this step if SKIP_RECOMMEND is true.

### 9a. Detect skill relevance signals

Scan the project for signals that map to specific skills. Run these checks in parallel:

| Signal | Detection | Recommended Skill | Category |
|--------|-----------|-------------------|----------|
| No test-before-code git patterns | Git log analysis (same as coding-defaults enforcer) | `superpowers:test-driven-development` | Process |
| No E2E/Playwright tests | Missing playwright.config, no @playwright/test dep | `superpowers:test-driven-development` | Process |
| Complex multi-step task ahead (from Priority 1 items) | 3+ Priority 1 items with effort > Quick Win | `superpowers:writing-plans` | Process |
| Multiple independent subsystems | 3+ specialist dimensions flagged CRITICAL | `superpowers:dispatching-parallel-agents` | Process |
| Bug or failure patterns detected | Test failures, error patterns in logs | `superpowers:systematic-debugging` | Process |
| No PR review workflow | Missing `.github/CODEOWNERS`, no PR templates | `superpowers:requesting-code-review` | Process |
| Active feature branches | 2+ non-default branches | `/gw:worktree create <name>` | Process |
| No presentation/docs workflow | No `docs/gw/` directory with `.pptx` files, no merge-it usage | `gw:merge-it` | Workflow |
| No periodic review | No weekly review config at `~/.config/gw-skills/weekly-review.json` | `gw:weekly-review` | Workflow |
| SaaS signals detected (from Step 1) | APP_TYPE = saas or SaaS signals present | `gw:saas-idea` | Workflow |
| No project planning | Missing `.planning/` directory | `superpowers:writing-plans` or `gsd:new-project` | Planning |
| Existing project with stale phases | `.planning/` exists but no recent phase activity | `gsd:progress` | Planning |
| No CI/CD pipeline | Missing `.github/workflows/`, `Jenkinsfile`, `.gitlab-ci.yml` | `superpowers:verification-before-completion` | Process |
| Fixes applied in Step 5 (code changed, benefits from ongoing simplification) | Any fix agents ran and produced fix summaries | `superpowers:code-simplifier` | Process |
| Complex architectural issues (3+ CRITICAL findings across different dimensions) | 3+ dimensions have CRITICAL-severity findings | `superpowers:brainstorming` | Process |

### 9b. Check what's already available

1. Check which gw-skills are installed: `ls ~/.claude/commands/gw/ 2>/dev/null`
2. Check which GSD skills are installed: `ls ~/.claude/commands/gsd/ 2>/dev/null`
3. Check if superpowers are available: glob for `~/.claude/plugins/cache/claude-plugins-official/superpowers/` or check if any `superpowers:*` skills appear in the skill list. Superpowers are globally available when installed — they don't need per-project setup.
4. Read the project's `CLAUDE.md` if it exists — check if any skill references are already documented there

Filter out skills that are already installed or referenced in CLAUDE.md.

### 9c. Present recommendations

Display a recommendations table, grouped by category:

```
Recommended Skills for {project_name}:

Process Skills:
  1. [INSTALL] superpowers:test-driven-development
     Why: No TDD patterns detected, 3 test files have ceremonial assertions
  2. [AVAILABLE] superpowers:writing-plans
     Why: 5 Priority 1 items need coordinated implementation
  3. [INSTALL] superpowers:systematic-debugging
     Why: Test failures detected in 2 modules

Workflow Skills:
  4. [INSTALL] gw:merge-it
     Why: No presentation workflow — changes go undocumented
  5. [AVAILABLE] gw:weekly-review
     Why: Already installed, recommend configuring for this repo

Planning Skills:
  6. [INSTALL] gsd:new-project
     Why: No project planning structure detected

[INSTALL] = not yet referenced in project | [AVAILABLE] = installed but not used

Install all recommended [a], select by number [1,3,6], skip [s]?
```

- **[INSTALL]** means the skill exists in the user's environment but isn't referenced in the project's CLAUDE.md
- **[AVAILABLE]** means it's already referenced or the user already uses it

### 9d. Install selected skills

For skills the user approves:

**For superpowers skills:** These are already available globally. "Installing" means adding a reference to the project's `CLAUDE.md` so they're top-of-mind. Append to `CLAUDE.md` (create if it doesn't exist):

```markdown
## Recommended Skills

The following skills were identified by `gw:review-app` as beneficial for this project:

- `superpowers:test-driven-development` — Use TDD for all new features and bug fixes
- `superpowers:writing-plans` — Plan multi-step tasks before coding
- `superpowers:systematic-debugging` — Use scientific debugging for failures
```

**For gw: skills:** gw-skills is necessarily already installed (the user is running `gw:review-app`). Just add the recommended skill references to CLAUDE.md so they're discoverable for the project.

**For gsd: skills:** Check if superpowers are available first (glob for `~/.claude/plugins/cache/claude-plugins-official/superpowers/` or check if any `superpowers:*` skills appear in the skill list).
- If superpowers are available: prefer recommending the superpowers equivalent (e.g., `superpowers:writing-plans`) as the primary option, and mention GSD as an alternative.
- Check if GSD is installed (`~/.claude/commands/gsd/` exists).
  - If yes: GSD skills are already available, add to CLAUDE.md recommendations as an alternative.
  - If not: tell the user: "GSD not installed — use `superpowers:writing-plans` as the primary planning alternative, or install GSD for full project management support."

### 9e. Configure thinking mode

If the project has complex architectural issues (3+ CRITICAL findings across different dimensions), suggest enabling extended thinking:

```
This project has complex cross-cutting issues. For best results when implementing fixes:
- Use extended thinking mode if available (model-dependent)
- Pair with superpowers:brainstorming before major architectural changes
- Use superpowers:writing-plans for multi-phase implementations
```

### 9f. Summary

Print a final summary:

```
Skills configured for {project_name}:
  - {N} skills recommended
  - {N} references added to CLAUDE.md
  - {N} already available (no action needed)

Next steps:
  - Run /gw:merge-it when ready to ship changes
  - Use superpowers:writing-plans to create a structured implementation plan (or /gsd:new-project if GSD is installed)
  - Use superpowers:test-driven-development for all new code
```

---

## Step 9.5 — Persona Contribution

Skip this step if `CREATED_PERSONAS` is empty.

Present the created personas:

```
New persona(s) created during this run:
  - {Name1} (workforce/{slug1}.md)
  - {Name2} (workforce/{slug2}.md)

Contribute to gw-skills defaults? This creates a PR to share with all users.
  Contribute [y], skip [n]?
```

If the user selects `[y]`:

1. Save the current directory and branch
2. `cd $GW_REPO`
3. Check for uncommitted changes — if the working tree is dirty, ask: "gw-skills repo has uncommitted changes. Stash them? [y/n]" If yes, `git stash`. If no, abort contribution.
4. Create a branch:
   - Single persona: `persona/{slug}`
   - Multiple personas: `persona/batch-YYYY-MM-DD`
5. For each persona in `CREATED_PERSONAS`:
   - Copy `workforce/{slug}.md` → `workforce/_defaults/{slug}.md`
6. Stage and commit:
   ```bash
   git add workforce/_defaults/
   git commit -m "feat(workforce): add {Name} persona

   Background: {background}
   Created inline during gw:review-app run."
   ```
   (For multiple personas, list all names in the commit message.)
7. Push: `git push -u origin {branch}`
8. Create PR:
   ```bash
   gh pr create --title "Add {Name} persona to defaults" --body "$(cat <<'EOF'
   ## New Persona: {Name}

   **Background:** {background}
   **Skills used by:** gw:compete, gw:research, gw:review-app, gw:saas-idea
   **Created:** Inline during gw:review-app run on {date}

   Generated with [Claude Code](https://claude.com/claude-code)
   EOF
   )"
   ```
9. If stashed in step 3, `git stash pop`
10. Return to the original directory and branch
11. Print the PR URL
