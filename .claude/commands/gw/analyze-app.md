---
name: analyze-app
description: Analyze any application across specialist dimensions with role-adapted agents
argument-hint: "[--skip-cloud] [--skip-gsd] [--type web|server|cli|mobile|library]"
---

## Step 0 — Update check

Run `~/.gw-skills/check-update.sh` using Bash. If the output contains `UPDATE_AVAILABLE`, tell the user how many commits behind they are and ask: "gw-skills has updates available. Run /gw:update to install them, or continue?" If they want to update, invoke `/gw:update` and stop. Otherwise continue. If the script is missing or fails, skip silently.

---

You are an orchestrator for a multi-dimensional application analysis. The specialist agents you spawn are **adapted to the type of application** being analyzed. Follow these steps precisely.

Parse the arguments: "$ARGUMENTS"
- If "--skip-cloud" or "--skip-aws" is present, set SKIP_CLOUD=true
- If "--skip-gsd" is present, set SKIP_GSD=true
- If "--type X" is present, set FORCED_TYPE=X (one of: web, server, cli, mobile, library)

---

## Step 1 — Pre-flight & App Type Detection

1. Check if `.analysis/` directory exists. If it does, ask the user: "`.analysis/` already exists. Refresh all reports, or skip analysis and just view existing REPORT.md?" If they choose to skip, read and present `.analysis/REPORT.md` and stop. If they choose to refresh, continue.

2. Run `mkdir -p .analysis`

3. Auto-detect the stack by globbing for these files (run all globs in parallel):
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

4. Read `CLAUDE.md` and `README.md` if they exist (in parallel). These provide project context.

5. **Determine the APP_TYPE** using the detected stack. If FORCED_TYPE was set, use that instead. Otherwise, classify using these rules:

   | Detected Signals | APP_TYPE |
   |---|---|
   | React, Vue, Angular, Svelte, Next.js, Vite with HTML/CSS, Tailwind, frontend framework + optional backend | **web** |
   | FastAPI, Flask, Django, Express, Gin, Rails, .NET API without significant frontend | **server** |
   | Click, Typer, Cobra, clap, argparse, `console_scripts`, `bin/` executables, no web framework | **cli** |
   | React Native, Flutter, Swift/iOS, Kotlin/Android, Expo | **mobile** |
   | `setup.py`/`pyproject.toml` with library metadata, no entry point, published to npm/PyPI/crates.io | **library** |
   | Mixed frontend + backend | **web** (default for full-stack) |

6. Print a summary like:
   ```
   Stack detected:
     Frontend: React 19 + TypeScript + Vite
     Backend: Python 3.12 + FastAPI
     Infra: Terraform (AWS)
     App Type: web (full-stack web application)

   Specialist team:
     1. UX Designer — usability & accessibility
     2. Web Designer — visual design & consistency
     3. Cloud Cost Analyst — infrastructure efficiency
     4. Security Engineer — vulnerabilities & hardening
     5. Software Architect — system design & patterns
     6. Complexity Analyst — maintainability & tech debt
   ```

Build a variable called STACK_CONTEXT that contains the detected stack info, APP_TYPE, key file paths, and any relevant excerpts from CLAUDE.md/README.md. This will be passed to every agent. Keep it under 500 words.

---

## Step 2 — Spawn specialist agents in parallel

Based on the APP_TYPE, select the appropriate agent roster from the profiles below. Launch all applicable agents in a SINGLE message using the Agent tool with `run_in_background=true`. Each agent is `subagent_type="general-purpose"`. Skip the cloud/infra agent if SKIP_CLOUD is true.

Every agent prompt MUST include:

1. The STACK_CONTEXT block from Step 1
2. The dimension-specific instructions from the selected profile
3. This shared rules block:

```
RULES:
- You are analyzing the codebase in the current working directory.
- Only cite files that actually exist — use Glob and Grep to verify before citing.
- Be specific: include file paths with line numbers (path/to/file.ts:42).
- Be actionable: every finding must have a concrete recommendation.
- Use severity levels: CRITICAL (must fix — security hole, data loss, broken UX), WARNING (should fix — degraded experience, tech debt, cost waste), INFO (nice to have — polish, optimization).
- If a dimension does not apply to this codebase, write a short "Not Applicable" report explaining why.
- Write your report to the specified output file using the Write tool.
```

4. This report format:

```
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
```

---

## Agent Profiles by App Type

### APP_TYPE = "web"

Agents tuned for web applications — emphasizes UX, visual design, browser concerns.

**Agent 1: UX Designer**
- **Output file:** `.analysis/01-usability.md`
- **Prompt preamble:** "You are a UX designer with deep expertise in web application usability, analyzing for user experience quality."
- **Categories:** Navigation & Information Architecture, Loading & Error States, Forms & Input (validation, labels, autofocus, tab order), Accessibility/a11y (ARIA, keyboard nav, contrast, screen readers, focus management), Mobile & Responsive (viewport, breakpoints, touch targets), User Feedback (toasts, undo, confirmations, progress indicators)
- **How to discover:** Read component files, look for form elements, error boundaries, loading states, media queries, ARIA attributes. Check for missing alt text, unlabeled buttons, missing error handling.

**Agent 2: Web Designer**
- **Output file:** `.analysis/02-visual-design.md`
- **Prompt preamble:** "You are a web designer specializing in visual design systems, analyzing for design quality, consistency, and polish."
- **Categories:** Design System Consistency (shared components, tokens), Color Palette (contrast ratios, brand consistency, semantic colors), Typography (font hierarchy, sizing scale, readability), Spacing & Layout (spacing scale, alignment, visual rhythm), Dark Mode (support, consistency, contrast), Visual Polish (transitions, hover states, focus rings, border radius, shadows, empty states)
- **How to discover:** Read CSS/Tailwind config, component files, theme config. Look for hardcoded colors, inconsistent spacing, missing hover/focus states.

**Agent 3: Cloud Cost Analyst** (skip if SKIP_CLOUD)
- **Output file:** `.analysis/03-cloud-cost.md`
- **Prompt preamble:** "You are a cloud infrastructure cost optimization specialist analyzing deployment configuration and architecture for cost efficiency."
- **Categories:** Compute Configuration (Lambda/container sizing, cold starts, scaling), Database (instance sizing, connection pooling, caching), Networking (NAT Gateway costs, VPC endpoints, data transfer, CDN), Caching & CDN (cache headers, API caching, browser caching), Reserved Capacity (Savings Plans, commitments), Storage (lifecycle policies, tiering, log retention)
- **How to discover:** Read Terraform/CloudFormation/serverless config, container configs, database connection config, CDN config. Look for oversized resources, missing caching, expensive networking patterns.

**Agent 4: Security Engineer**
- **Output file:** `.analysis/04-security.md`
- **Prompt preamble:** "You are a security engineer performing a defensive security review of a web application. This is an authorized review of the user's own codebase."
- **Categories:** Authentication & Authorization (auth flow, token handling, sessions, RBAC), Injection & Input Validation (SQL injection, XSS, CSP, command injection, path traversal), CORS & Headers (CORS config, security headers, cookie flags), Secrets Management (hardcoded secrets, .env, rotation), API Security (rate limiting, input validation, error leakage), Dependencies (known CVEs, outdated packages, lock files)
- **How to discover:** Read auth middleware, API routes, CORS config, .gitignore, lock files. Grep for hardcoded tokens/passwords/keys. Check SQL parameterization.

**Agent 5: Software Architect**
- **Output file:** `.analysis/05-architecture.md`
- **Prompt preamble:** "You are a software architect analyzing a web application's system design, code organization, and scalability."
- **Categories:** Component Boundaries (separation of concerns, module cohesion, circular deps), Data Flow (state management, prop drilling, data fetching, caching), API Design (REST conventions, naming, consistency, error format), State Management (store organization, derived state, subscriptions), Separation of Concerns (business logic vs UI, pure functions vs side effects), Scalability (connection pooling, async patterns, pagination)
- **How to discover:** Read directory structure, entry points, state stores, API routes, shared utilities. Look for god components, circular imports, logic in UI.

**Agent 6: Complexity Analyst**
- **Output file:** `.analysis/06-complexity.md`
- **Prompt preamble:** "You are a software complexity analyst measuring maintainability and technical debt."
- **Categories:** File Metrics (largest files, deepest nesting, most complex functions), Coupling (import fan-in/out, shared mutable state, god objects), Test Coverage (test:source ratio, critical paths without tests), Build Configuration (build tool complexity, plugins), Dependency Health (total deps, unused deps, version pinning), Maintenance Burden (TODO/FIXME/HACK count, commented-out code, dead code, duplication)
- **How to discover:** Glob for large files, Grep for TODO/FIXME/HACK, count test vs source files, read build config, check dependency counts.

---

### APP_TYPE = "server"

Agents tuned for backend services, APIs, daemons — emphasizes ops, reliability, performance.

**Agent 1: SRE / Reliability Engineer**
- **Output file:** `.analysis/01-reliability.md`
- **Prompt preamble:** "You are a Site Reliability Engineer analyzing a backend service for operational reliability, observability, and fault tolerance."
- **Categories:** Health Checks & Readiness (health endpoints, liveness probes, graceful shutdown), Error Handling & Recovery (retry logic, circuit breakers, dead letter queues, crash recovery), Logging & Observability (structured logging, log levels, request tracing, correlation IDs, metrics endpoints), Graceful Degradation (timeouts, fallbacks, partial responses, bulkhead patterns), Database Reliability (connection pooling, migration safety, query timeouts, transaction handling), Deployment Safety (rollback capability, blue-green/canary, feature flags)
- **How to discover:** Read main entry point, middleware, health endpoints, error handlers, logging config, database config, deployment scripts.

**Agent 2: Systems Administrator / DevOps**
- **Output file:** `.analysis/02-operations.md`
- **Prompt preamble:** "You are an experienced systems administrator and DevOps engineer analyzing a backend service for operational excellence and production readiness."
- **Categories:** Configuration Management (environment variables, config files, secrets injection, 12-factor compliance), Resource Limits (memory bounds, CPU limits, file descriptor limits, connection pool sizing), Process Management (signal handling, PID files, worker processes, supervisor config), Backup & Recovery (database backup strategy, point-in-time recovery, disaster recovery plan), Monitoring & Alerting (what to monitor, alerting thresholds, runbooks, on-call considerations), Capacity Planning (current resource usage, scaling triggers, bottleneck identification)
- **How to discover:** Read Dockerfiles, docker-compose, systemd units, Terraform/infra configs, CI/CD pipelines, environment variable usage, process management code.

**Agent 3: Cloud Cost Analyst** (skip if SKIP_CLOUD)
- Same as web profile above.

**Agent 4: Security Engineer**
- **Output file:** `.analysis/04-security.md`
- **Prompt preamble:** "You are a security engineer performing a defensive security review of a backend service. This is an authorized review of the user's own codebase."
- **Categories:** Authentication & Authorization (auth middleware, token validation, RBAC, service-to-service auth), Injection & Input Validation (SQL injection, command injection, SSRF, path traversal, deserialization), Network Security (TLS config, internal service communication, firewall rules, exposed ports), Secrets Management (hardcoded secrets, vault integration, rotation, .env handling), API Security (rate limiting, input validation, error leakage, authentication enforcement), Dependencies (known CVEs, outdated packages, supply chain)
- **How to discover:** Read auth middleware, API routes, database queries, network config, .gitignore. Grep for hardcoded secrets. Check SQL parameterization, input validation.

**Agent 5: Software Architect**
- **Output file:** `.analysis/05-architecture.md`
- **Prompt preamble:** "You are a software architect analyzing a backend service's system design, API patterns, and data architecture."
- **Categories:** API Design (REST/GraphQL conventions, versioning, pagination, error format, idempotency), Data Architecture (schema design, indexing strategy, migration patterns, data integrity), Service Boundaries (module cohesion, domain isolation, dependency direction), Async & Concurrency (worker patterns, queue usage, background jobs, race conditions), Caching Strategy (cache layers, invalidation, TTL policies, cache stampede prevention), Scalability (horizontal scaling readiness, statelessness, shared-nothing architecture)
- **How to discover:** Read API routes, database schemas/migrations, middleware chain, worker/queue code, caching config.

**Agent 6: Performance Engineer**
- **Output file:** `.analysis/06-performance.md`
- **Prompt preamble:** "You are a performance engineer analyzing a backend service for latency, throughput, and resource efficiency."
- **Categories:** Database Performance (N+1 queries, missing indexes, slow query patterns, connection pool sizing), API Latency (synchronous bottlenecks, blocking I/O, serialization overhead), Memory & CPU (memory leaks, excessive allocations, CPU-bound operations, GC pressure), Concurrency (thread/worker pool sizing, async utilization, lock contention), Caching Effectiveness (cache hit ratios, cache key design, over/under-caching), Load Testing Readiness (benchmarks present, load test config, performance regression tests)
- **How to discover:** Read database queries, API handlers, serialization code, async patterns, caching implementation, test files for performance tests.

---

### APP_TYPE = "cli"

Agents tuned for command-line tools — emphasizes CLI UX, cross-platform, docs.

**Agent 1: CLI UX Specialist**
- **Output file:** `.analysis/01-cli-ux.md`
- **Prompt preamble:** "You are a CLI usability expert analyzing a command-line tool for user experience, discoverability, and ergonomics."
- **Categories:** Command Structure (subcommand hierarchy, naming conventions, discoverability), Help & Documentation (--help output quality, man pages, examples, error messages), Input & Output (stdin/stdout/stderr usage, piping support, output formatting, machine-readable output with --json), Progress & Feedback (progress bars for long operations, verbose/quiet modes, color output, interactive vs non-interactive detection), Configuration (config file support, environment variables, precedence rules, defaults), Error Handling (exit codes, actionable error messages, suggestions for typos, --debug flag)
- **How to discover:** Read main entry point, argument parsing, help strings, output formatting, config loading, error handling.

**Agent 2: Cross-Platform Engineer**
- **Output file:** `.analysis/02-cross-platform.md`
- **Prompt preamble:** "You are a cross-platform engineer analyzing a CLI tool for portability, installation, and distribution."
- **Categories:** Platform Compatibility (Windows/macOS/Linux differences, path handling, line endings, shell compatibility), Installation & Distribution (package manager support, binary distribution, install scripts, minimal dependencies), File System (path separators, temp directory, home directory, permissions), Shell Integration (completion scripts, aliases, shell detection), Testing (CI matrix for multiple OS, integration tests, snapshot tests)
- **How to discover:** Read build scripts, CI config, file path handling, OS-specific code, installation instructions.

**Agent 3: Security Engineer**
- **Output file:** `.analysis/03-security.md`
- **Prompt preamble:** "You are a security engineer analyzing a CLI tool for security issues. Authorized review."
- **Categories:** Input Validation (command injection via arguments, path traversal, unsafe deserialization), Secrets Handling (credential storage, keychain integration, config file permissions), File Operations (symlink attacks, TOCTOU races, temp file security), Network Security (TLS verification, certificate pinning, proxy support), Dependencies (supply chain, minimal dependency surface)
- **How to discover:** Read argument parsing, file I/O, network calls, credential handling, temp file usage.

**Agent 4: Software Architect**
- Same as server profile but adapted to CLI patterns.

**Agent 5: Complexity Analyst**
- Same as web profile above.

---

### APP_TYPE = "mobile"

Agents tuned for mobile apps — emphasizes mobile UX, performance, platform guidelines.

**Agent 1: Mobile UX Designer**
- **Output file:** `.analysis/01-mobile-ux.md`
- **Prompt preamble:** "You are a mobile UX designer analyzing a mobile application for usability, platform conventions, and user experience."
- **Categories:** Navigation Patterns (tab bars, drawers, stack navigation, deep linking), Touch Interactions (touch targets, gestures, haptic feedback, pull-to-refresh), Platform Conventions (iOS HIG / Material Design compliance, native feel), Offline Support (offline-first, data sync, conflict resolution, network state handling), Performance Perception (skeleton screens, optimistic updates, lazy loading), Accessibility (VoiceOver/TalkBack support, dynamic type, contrast)
- **How to discover:** Read navigation config, screen components, gesture handlers, network/sync code, accessibility props.

**Agent 2: Mobile Performance Engineer**
- **Output file:** `.analysis/02-mobile-performance.md`
- **Prompt preamble:** "You are a mobile performance engineer analyzing for battery, memory, network, and rendering efficiency."
- **Categories:** Rendering (list virtualization, re-render optimization, image loading/caching, animation frame rate), Battery & Network (background tasks, polling vs push, request batching, payload sizes), Memory (memory leaks, image memory, cache eviction), Startup Time (lazy loading, code splitting, splash screen duration), Bundle Size (tree shaking, dead code, asset optimization)
- **How to discover:** Read list components, image handling, network calls, background task config, bundle config.

**Agent 3: Security Engineer**
- Adapted for mobile: includes certificate pinning, secure storage (Keychain/Keystore), biometric auth, root/jailbreak detection.

**Agent 4: Software Architect**
- Same structure, adapted for mobile patterns (navigation architecture, state management, offline sync).

**Agent 5: Complexity Analyst**
- Same as web profile.

---

### APP_TYPE = "library"

Agents tuned for reusable libraries/packages — emphasizes API design, docs, compatibility.

**Agent 1: API Design Reviewer**
- **Output file:** `.analysis/01-api-design.md`
- **Prompt preamble:** "You are an API design expert analyzing a library's public interface for clarity, consistency, and developer experience."
- **Categories:** Public API Surface (naming conventions, consistency, discoverability, progressive disclosure), Type Safety (TypeScript/Python type hints, generic usage, strict mode), Error Handling (error types, error messages, recovery guidance), Defaults & Configuration (sensible defaults, configuration options, builder patterns), Versioning & Compatibility (semver compliance, breaking change risk, deprecation strategy)

**Agent 2: Documentation Reviewer**
- **Output file:** `.analysis/02-documentation.md`
- **Prompt preamble:** "You are a technical writer analyzing a library's documentation for completeness and clarity."
- **Categories:** README Quality (getting started, installation, basic examples), API Documentation (all public functions documented, parameter descriptions, return types, examples), Migration Guides (changelog, upgrade paths, breaking changes), Examples (runnable examples, edge cases, common patterns)

**Agent 3: Security Engineer**
- Focused on: supply chain, input validation, prototype pollution, unsafe operations.

**Agent 4: Compatibility Analyst**
- **Output file:** `.analysis/04-compatibility.md`
- **Prompt preamble:** "You are analyzing a library for compatibility, portability, and ecosystem integration."
- **Categories:** Runtime Compatibility (Node/browser/Deno, Python version support), Bundler Compatibility (ESM/CJS, tree-shaking, side effects), Peer Dependencies (version ranges, conflicts), Package Config (exports field, types, main/module entries)

**Agent 5: Complexity Analyst**
- Same as web profile.

---

## Step 3 — Collect results

After launching all agents, wait for them to complete (you will be notified as each background agent finishes).

Once ALL agents have completed:

1. Verify each expected `.analysis/*.md` file exists and has content (use Glob and Read)
2. Print a status table:
   ```
   Analysis Status (APP_TYPE: {type}):
   [done] 01-{name}.md       (N findings)
   [done] 02-{name}.md       (N findings)
   [done] 03-{name}.md       (N findings)  — or [skipped]
   [done] 04-{name}.md       (N findings)
   [done] 05-{name}.md       (N findings)
   [done] 06-{name}.md       (N findings)
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
| {Agent 1 dimension} | Good/Fair/Needs Work | N | N | one-liner |
| {Agent 2 dimension} | ... | ... | ... | ... |
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

---

## Step 5 — Present results

After the synthesis agent completes:

1. Read `.analysis/REPORT.md`
2. Print the Executive Summary and Scorecard table from the report
3. Print the Priority 1 items (just titles and effort)
4. Print compound wins (just titles)
5. Print file listing with line counts

---

## Step 6 — GSD Integration

Skip this step if SKIP_GSD is true.

Check if `~/.claude/commands/gsd/` exists. If it does:

1. Check if `.planning/PROJECT.md` exists (i.e., GSD project already initialized).
   - **If yes (brownfield/existing project):** Automatically invoke `/gsd:new-milestone` and reference `.analysis/REPORT.md` as the requirements source. Tell the user you are creating a new GSD milestone from the recommended phases.
   - **If no (greenfield):** Automatically invoke `/gsd:new-project` and reference `.analysis/REPORT.md` as the requirements source. Tell the user you are creating a GSD project from the recommended phases.

If GSD commands don't exist, say: "Full analysis available in `.analysis/REPORT.md`. Install GSD to auto-create a project from these phases." and stop.
