---
name: review-app
description: Full-stack application review — security, architecture, UX, testing, cloud cost analysis with AI specialists. Use when the user asks to review, audit, or analyze an application's quality, security, architecture, or UX.
argument-hint: "[--focus dim1,dim2,...] [--skip-cloud] [--skip-planning] [--skip-gsd] [--skip-testing] [--skip-security] [--skip-seo] [--skip-test-review] [--skip-defaults] [--skip-fix] [--skip-pptx] [--skip-recommend] [--skip-simplify] [--skip-test-gen] [--type web|server|cli|mobile|library|saas] [--scope full|recent|recent:N|timeframe:<spec>] [--team auto|ask|N] [--hire|--fire|--roster] [--no-branch]"
---

## Step 0 — Preamble

Resolve the gw-skills repo path, then read and follow `$GW_REPO/.claude/commands/gw/_shared/preamble.md` for update check and GSD project detection:

```bash
GW_REPO="$(cd "$(readlink ~/.claude/commands/gw)/../../.." 2>/dev/null && pwd)" || GW_REPO="$HOME/.gw-skills"
```

GW_REPO persists for the duration of this skill run — do not re-resolve it in later steps.

---

## Step 0.5 — Branch Isolation

Set `SKILL_NAME="review-app"`.

Read and follow `$GW_REPO/.claude/commands/gw/_shared/branch-first.md` for branch creation.

---

You are an orchestrator for a multi-dimensional application analysis. You assemble a **tailored team of specialists** based on the project's type, size, and complexity. Follow these steps precisely.

Parse the arguments: "$ARGUMENTS"
- If `--focus <dimensions>` is present, set FOCUS_DIMS to the comma-separated list. Valid dimensions: `cloud`, `security`, `testing`, `seo`, `test-review`, `defaults`, `fix`, `pptx`, `recommend`, `simplify`, `test-gen`. All dimensions NOT in the list are treated as skipped.
- If both `--focus` and any `--skip-*` flags are present, `--focus` takes precedence. Warn: "Both --focus and --skip flags provided. Using --focus dimensions only."
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
- If "--no-branch" is present, set NO_BRANCH=true. Default: false. Skips branch isolation (see Step 0.5).
- If "--hire", "--fire", or "--roster" is present: tell the user "Use `/gw:workforce` for persona management. Examples: `/gw:workforce --hire "Name" --background "..."`, `/gw:workforce --fire "Name"`, `/gw:workforce --roster`" and stop.

**--focus flag behavior:** When FOCUS_DIMS is set, derive skip flags from it:
- For each valid dimension NOT in FOCUS_DIMS, set its corresponding SKIP variable to true
- Dimension mapping: `cloud` -> SKIP_CLOUD, `security` -> SKIP_SECURITY, `testing` -> SKIP_TESTING, `seo` -> SKIP_SEO, `test-review` -> SKIP_TEST_REVIEW, `defaults` -> SKIP_DEFAULTS, `fix` -> SKIP_FIX, `pptx` -> SKIP_PPTX, `recommend` -> SKIP_RECOMMEND, `simplify` -> SKIP_SIMPLIFY, `test-gen` -> SKIP_TEST_GEN

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
- 2+ signals detected -> override APP_TYPE to `saas`
- 1 signal detected -> keep current APP_TYPE but note: "SaaS signals detected; use `--type saas` for business-focused analysis."

### 1c. Scope resolution

Resolve the SCOPE_MODE to produce FILE_SCOPE (a list of files to focus on):

| Scope Mode | Git Command |
|---|---|
| `full` (default) | No filtering — FILE_SCOPE stays empty |
| `recent` | `git log --name-only --pretty=format: -20 \| sort -u \| sed '/^$/d'` |
| `recent:N` | Same with `-N` (e.g. `recent:50` -> `-50`) |
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
| Medium | 50-200 | 5 |
| Large | 200-500 | 7 |
| Monorepo | 500+ | 9 |

**Adjustments** (+1 each, capped at 10):
- 3+ languages detected
- Infrastructure code present (Terraform, K8s manifests, Docker)
- 2+ frameworks detected

**Maximum:** 10

If TEAM_SIZE_OVERRIDE is set (from `--team N`), use that value instead (still clamped to 3-10).

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

Read and follow `$GW_REPO/.claude/commands/gw/_shared/review-specialist-prompt.md` for the agent prompt template and findings report output format. Use only the "Specialist Agent Prompt Template" section — the simplification and coverage enforcement sections are used later in Step 5.

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

Read and follow `$GW_REPO/.claude/commands/gw/_shared/review-synthesis-format.md` for the synthesis agent prompt and REPORT.md structure. Use only the "Synthesis Agent" section — the "Update Synthesis Report" section is used later in Step 5h.

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

Read and follow `$GW_REPO/.claude/commands/gw/_shared/review-specialist-prompt.md` — use the "Code Simplification Agent (Step 5f)" section.

### 5g. Coverage Enforcement

Read and follow `$GW_REPO/.claude/commands/gw/_shared/review-specialist-prompt.md` — use the "Coverage Enforcement Agent (Step 5g)" section.

### 5h. Update synthesis report

Read and follow `$GW_REPO/.claude/commands/gw/_shared/review-synthesis-format.md` — use the "Update Synthesis Report (Step 5h)" section.

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

Read and follow `$GW_REPO/.claude/commands/gw/_shared/review-pptx-slides.md` for presentation data gathering, JSON schema, slide structure, and execution.

---

## Step 9 — Skill Recommendations & Auto-Install

Skip this step if SKIP_RECOMMEND is true.

Read and follow `$GW_REPO/.claude/commands/gw/_shared/review-recommendations.md` for signal detection, recommendation display, installation, and persona contribution (Step 9.5).

---

## Step 11.5 — Intent Commit & Auto-PR

Read and follow `$GW_REPO/.claude/commands/gw/_shared/intent-commit.md` to write and commit the `.gw-intent.md` file.

Then read and follow `$GW_REPO/.claude/commands/gw/_shared/auto-pr.md` to create a PR with the `agent_merge` label.

---

## Final — Session Summary

Read and follow `$GW_REPO/.claude/commands/gw/_shared/session-summary.md`.
