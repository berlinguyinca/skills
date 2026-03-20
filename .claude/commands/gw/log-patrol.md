---
name: log-patrol
description: Monitor production logs across deployment environments — detects errors, generates reports, creates GitHub issues with diagnosis plans. Use when analyzing production logs, tracking recurring errors, or correlating log errors with codebase locations
argument-hint: "[--add-source TYPE:CONN] [--remove-source IDX] [--list-sources] [--discover \"PROMPT\"] [--since DURATION] [--full] [--dry-run] [--skip-issues] [--repo owner/repo]"
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

**Model override:** All agents spawned by this skill MUST use `model: "sonnet"`. This applies to every Agent tool call — probe agents, fetch agents, classification agent, and correlation agents. The only exception is if a GSD model profile explicitly overrides it (see below).

Skip this step if you are inside a GSD project (`~/.config/opencode/.planning/` exists).

If `.planning/config.json` exists in the current or parent directories:
1. Try to resolve and read its JSON content using Bash/Grep
2. Extract `model_profile` (default: "balanced")
3. If a profile is found, use it for all agent spawns instead of Sonnet
4. Log: "Using GSD model profile: {profile}" in the first output message

This enables gw skills to inherit opencode's model preferences within managed projects.

---

## Step 1 — Parse arguments & config management

You are an orchestrator for production log monitoring and analysis. You fetch logs from multiple sources, detect errors, classify them, correlate with codebase, generate reports, and create GitHub issues with diagnosis plans. Follow these steps precisely.

**Config directory:** `.log-patrol/` (project-local, relative to current working directory)

Parse the arguments: "$ARGUMENTS"

- `--add-source TYPE:CONNECTION_STRING` — Add a log source. TYPE is one of: `ssh`, `cloudwatch`, `local`, `docker`. See source format below.
- `--remove-source INDEX_OR_NAME` — Remove a configured source by its numeric index or connection string.
- `--list-sources` — Show all configured sources and stop.
- `--discover "PROMPT"` — Auto-discover log sources from project context and active probing. The PROMPT describes the infrastructure (e.g., `"dockerized Python app with CloudWatch logging"`).
- `--since DURATION` — How far back to scan. Accepts: `1h`, `6h`, `24h`, `7d`, etc. Default: since last scan timestamp in state, or `24h` if no prior scan.
- `--full` — Ignore last-scan timestamp, scan full available history.
- `--dry-run` — Scan and report but do NOT create GitHub issues.
- `--skip-issues` — Skip GitHub issue creation entirely.
- `--repo owner/repo` — Target GitHub repo for issues. Default: auto-detected from `git remote get-url origin`.

**Source format examples:**
- `ssh:user@host:/var/log/app.log`
- `cloudwatch:log-group-name`
- `local:/path/to/file.log`
- `docker:container-name`

### Config management operations

**`--add-source`**: Create `.log-patrol/` if it doesn't exist. Read `.log-patrol/config.json` (or start with empty config). Add the source with an auto-incremented index, current ISO-8601 timestamp. Write back. Confirm and **stop**.

**`--remove-source`**: Read config, find source by index (numeric) or connection string match, remove it, write back. If not found, say so. Confirm and **stop**.

**`--list-sources`**: Read and display config. If no config file or empty sources array, say: "No sources configured. Use `/gw:log-patrol --add-source TYPE:CONNECTION` to add one, or `/gw:log-patrol --discover \"description\"` to auto-discover." and **stop**.

**Config file structure** (`.log-patrol/config.json`):
```json
{
  "sources": [
    { "index": 0, "type": "ssh", "connection": "user@host:/var/log/app.log", "added": "2026-03-20T10:00:00Z" }
  ],
  "custom_patterns": [],
  "default_since": "24h",
  "default_repo": ""
}
```

## Workflow routing

Based on arguments and detected state, the workflow may skip steps:

| Condition | Steps executed |
|-----------|----------------|
| Default (no flags) | 0 → 0.5 → 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9 |
| `--add/remove/list-sources` | 0 → 1 → config management → stop |
| `--discover "prompt"` | 0 → 0.5 → 1 → 1.5 (discover) → approval → save to config → stop |
| `--dry-run` | Full flow but Step 8 prints plan without executing |
| `--skip-issues` | Full flow but skip Step 8 entirely |
| Zero pattern matches in Step 4 | Steps 0–4 → clean report → Step 9 (skip 5–8) |
| All fetches fail in Step 3 | Steps 0–3 → stop with error summary |

**Approval gates** (stop and wait for user confirmation):
- After Step 2 (conditional) — If prerequisites fail for some source types, ask whether to continue with available sources or abort
- Before Step 8 (mandatory) — Present issue creation plan, require explicit `[y/n/edit]` confirmation

---

## Step 1.5 — Auto-Discovery (`--discover`)

Only execute this step when `--discover "PROMPT"` was provided.

### Phase A — Project file analysis (orchestrator, no agents)

Scan the project for infrastructure hints. Read/glob for these files and extract relevant information:

| File/Pattern | What to extract |
|-------------|-----------------|
| `docker-compose.yml` / `docker-compose.*.yml` | Service names, log driver config, volume mounts |
| `Dockerfile` / `*.dockerfile` | Base image (implies log paths), exposed ports |
| `*.tf` / `terraform/` | AWS resources (CloudWatch log groups, EC2 instances, ECS tasks, Lambda functions) |
| `.env` / `.env.*` | Host addresses, AWS regions, service URLs |
| `deploy/` / `scripts/` / `Makefile` | SSH targets, deployment hosts, rsync destinations |
| `ansible/` / `playbook*.yml` | Inventory hosts, log path configurations |
| `k8s/` / `kubernetes/` / `helm/` | Pod names, namespaces, container names |
| CI/CD configs (`.github/workflows/`, `Jenkinsfile`, `.gitlab-ci.yml`) | Deploy targets, environment variables |
| `CLAUDE.md` / `README.md` | Infrastructure descriptions, architecture notes |
| Logging configs (`log4j*.xml`, `logback.xml`, `logging.conf`, winston config) | Log file paths, log formats, rotation settings |

Combine findings with the user's PROMPT to build a list of **candidate sources** (type + connection string + confidence level: high/medium/low).

### Phase B — Active probing (parallel agents, 1 per target type)

For each distinct source type discovered, launch a background agent (`model: "sonnet"`) to verify and discover specific log paths:

| Source type | Probe action |
|-------------|-------------|
| SSH | `ssh user@host "find /var/log -name '*.log' -mmin -1440 2>/dev/null; ls -la /var/log/app/ 2>/dev/null; systemctl list-units --type=service --state=running 2>/dev/null"` |
| CloudWatch | `aws logs describe-log-groups --query 'logGroups[*].[logGroupName,storedBytes]' --output table` |
| Docker | `docker ps --format '{{.Names}} {{.Image}} {{.Status}}'` to list running containers |
| Local | `find . -name '*.log' -o -name '*.err' \| head -20; ls /var/log/ 2>/dev/null` |

Each probe agent returns discovered log files/streams with metadata (size, last modified, service association).

If a probe fails (e.g., ssh unreachable, aws not configured), note it as failed and continue with other probes.

### Phase C — Present findings for approval (approval gate)

Display results organized by discovery method, with recommendations marked:

```
Auto-Discovery Results:

  From project analysis:
    [docker-compose.yml] -> 3 services: web-api, worker, redis
    [terraform/main.tf]  -> CloudWatch log group: /ecs/my-app-prod
    [.env.production]    -> DEPLOY_HOST=deploy@prod1.example.com

  From active probing:
    SSH deploy@prod1.example.com:
      + /var/log/app/application.log (2.3 MB, modified 2 min ago)
      + /var/log/app/error.log (156 KB, modified 15 min ago)
      . /var/log/syslog (12 MB -- system log, probably not relevant)

    CloudWatch:
      + /ecs/my-app-prod (1.2 GB stored)
      . /aws/lambda/cron-handler (45 MB -- lambda, low relevance)

    Docker:
      + web-api (running, Up 3 days)
      + worker (running, Up 3 days)
      . redis (running -- infrastructure, probably not relevant)

  Recommended sources (select to save):
    [x] ssh:deploy@prod1.example.com:/var/log/app/application.log
    [x] ssh:deploy@prod1.example.com:/var/log/app/error.log
    [x] cloudwatch:/ecs/my-app-prod
    [x] docker:web-api
    [x] docker:worker
    [ ] docker:redis
    [ ] ssh:deploy@prod1.example.com:/var/log/syslog
    [ ] cloudwatch:/aws/lambda/cron-handler

Save selected sources? [y/edit/n]
```

- `[y]` — Save all checked sources to `.log-patrol/config.json`
- `[edit]` — Let user toggle selections, then save
- `[n]` — Cancel without saving

After saving, print: "Saved {N} sources. Run `/gw:log-patrol` to start scanning or `/gw:log-patrol --list-sources` to review." and **stop**.

---

## Step 2 — Verify prerequisites

Check availability of tools needed for the configured source types. Run these checks:

| Source type | Check | Command |
|-------------|-------|---------|
| All | GitHub CLI | `gh auth status` |
| SSH | SSH client | `which ssh` |
| CloudWatch | AWS CLI | `aws sts get-caller-identity` |
| Docker | Docker | `docker info 2>/dev/null` |

Only check tools required by the sources in `.log-patrol/config.json`. If no config exists or sources array is empty, stop with: "No sources configured. Use `--add-source` or `--discover` first."

**If some checks fail:** Present which source types are unavailable and ask:
```
Prerequisites check:
  + SSH: available
  x CloudWatch: aws CLI not configured (aws sts get-caller-identity failed)
  + Docker: available
  + GitHub CLI: authenticated as USERNAME

2 of 3 source types available. Continue without CloudWatch sources? [y/n]
```
- `[y]` — Continue, skipping unavailable source types
- `[n]` — Abort

**If `gh auth status` fails** and `--skip-issues` was NOT set: warn that issue creation will not work. Ask whether to continue with `--skip-issues` implied, or abort.

**If ALL source checks fail:** Stop with error.

---

## Step 3 — Fetch logs from all sources

Launch **one background agent per source** (parallel, `model: "sonnet"`). Each agent fetches log content and writes it to `.log-patrol/raw/`.

Create `.log-patrol/raw/` directory: `mkdir -p .log-patrol/raw`

Compute the time window:
- If `--full` was set: fetch all available history
- If `--since DURATION` was set: parse duration (e.g., `24h` = 24 hours, `7d` = 7 days) and compute start timestamp
- Otherwise: read `.log-patrol/state.json` for `last_scan` timestamp. If exists, use it. If not, default to 24 hours ago.

### Fetch commands per source type

**SSH source** (`ssh:user@host:/path/to/file.log`):
```bash
# Parse connection: user@host and path
ssh user@host "cat /path/to/file.log" > .log-patrol/raw/source-INDEX.log
# If --since is set, use awk/sed to filter by timestamp if log format is recognized
# If file is very large (>50MB), tail the last 10000 lines instead
```

**CloudWatch source** (`cloudwatch:log-group-name`):
```bash
aws logs filter-log-events \
  --log-group-name "log-group-name" \
  --start-time START_EPOCH_MS \
  --output json \
  --query 'events[*].message' > .log-patrol/raw/source-INDEX.log
```
Note: `--start-time` requires epoch milliseconds. Convert the computed start timestamp.

**Local source** (`local:/path/to/file.log`):
```bash
cp /path/to/file.log .log-patrol/raw/source-INDEX.log
# If --since is set and file is large, filter by timestamp or tail
```

**Docker source** (`docker:container-name`):
```bash
docker logs container-name --since START_TIMESTAMP > .log-patrol/raw/source-INDEX.log 2>&1
```

Each agent should:
1. Fetch the log content using the appropriate command
2. Write to `.log-patrol/raw/source-{INDEX}.log` where INDEX is the source index from config
3. Report back: success with line count + byte size, or failure with error message

After all agents complete, print a fetch summary:
```
Log fetch complete:
  [0] ssh:user@host:/var/log/app.log      -- 4,231 lines (1.2 MB)
  [1] cloudwatch:/ecs/my-app-prod         -- 12,847 lines (3.4 MB)
  [2] docker:web-api                      -- FAILED: container not running
  Total: 17,078 lines from 2/3 sources
```

If ALL fetches fail, stop with an error summary explaining each failure.

---

## Step 4 — Pattern scan (fast grep)

Run grep-based pattern matching directly (no agents) on all fetched log files in `.log-patrol/raw/`.

### Error detection patterns

| Category | Patterns |
|----------|----------|
| Explicit errors | `\bERROR\b`, `\bFATAL\b`, `\bCRITICAL\b` |
| Exceptions | `\bException\b`, `\bTraceback\b`, `\bpanic:\b` |
| HTTP 5xx | `\bHTTP[/ ][12]\.[01].\s+5[0-9]{2}\b` or `\b5[0-9]{2}\b` with HTTP context (e.g., near `GET`, `POST`, `HTTP`) |
| Memory | `\bOOM\b`, `\bOutOfMemory\b`, `\bsegfault\b`, `\bSIGKILL\b` |
| Timeouts | `\btimeout\b`, `\bdeadlock\b`, `\bconnection refused\b` |
| Disk/IO | `\bNo space left\b`, `\bDisk full\b`, `\bI/O error\b` |
| Custom | User-defined patterns from `config.json` `custom_patterns` array |

For each pattern, grep across all raw log files. Use case-insensitive matching for timeout/deadlock patterns but case-sensitive for ERROR/FATAL/CRITICAL.

Collect all matching lines with their source file, line number, and matched category. Deduplicate exact duplicate lines.

Print a scan summary:
```
Pattern scan: 93 matches across 6 categories
  Explicit errors:  42
  Exceptions:       23
  HTTP 5xx:         14
  Timeouts:          8
  Memory:            4
  Custom:            2
```

**If zero matches:** Generate a clean report (Step 7), update state (Step 9), print "No errors detected in the scanned period." and stop — skip Steps 5–8.

---

## Step 5 — AI classification (foreground agent)

Launch a **single foreground agent** (`model: "sonnet"`) to analyze and classify the pattern matches from Step 4.

Provide the agent with:
- All matched log lines (grouped by source)
- The pattern categories they matched
- Any existing `known_errors` from `.log-patrol/state.json` (for dedup against previous runs)

The agent must:

### 5a. Deduplicate
Group similar error messages together. Two errors are "similar" if they:
- Have the same exception type/error code
- Differ only in timestamps, request IDs, user IDs, or other variable data
- Originate from the same code path (same stack trace structure)

### 5b. Categorize each unique error
Assign one category: `Application Error`, `Infrastructure Error`, `Dependency Error`, `Configuration Error`, `Performance Error`, `Security Event`

### 5c. Assess severity
Assign severity: `CRITICAL`, `HIGH`, `MEDIUM`, `LOW`

Criteria:
- **CRITICAL**: Data loss, security breach, complete service outage, OOM kills
- **HIGH**: Partial outage, persistent errors affecting users, failing dependencies
- **MEDIUM**: Intermittent errors, degraded performance, non-critical timeouts
- **LOW**: Occasional warnings, deprecation notices, minor configuration issues

### 5d. Detect trends
For each error, assess trend based on timestamps: `increasing`, `decreasing`, `steady`, `periodic`, `new` (first time seen)

### 5e. Match against known errors
Compare each unique error against `known_errors` in state.json using the error hash (SHA-256 of normalized error message — stripped of timestamps, IDs, and variable data). If a match exists, mark it as `known` with its existing `error_id` and `github_issue` number.

The agent writes its output to `.log-patrol/classification.json`:
```json
{
  "scan_timestamp": "ISO-8601",
  "unique_errors": [
    {
      "error_id": "err-001",
      "hash": "sha256-of-normalized-message",
      "title": "NullPointerException in UserService.getProfile()",
      "category": "Application Error",
      "severity": "HIGH",
      "trend": "increasing",
      "occurrences": 42,
      "first_occurrence": "ISO-8601",
      "last_occurrence": "ISO-8601",
      "sample_lines": ["line1", "line2", "line3"],
      "sources": [0, 1],
      "known": false,
      "existing_issue": null
    }
  ],
  "summary": {
    "total_raw_matches": 93,
    "unique_errors": 8,
    "by_severity": { "CRITICAL": 1, "HIGH": 3, "MEDIUM": 3, "LOW": 1 },
    "by_category": { "Application Error": 4, "Infrastructure Error": 2, "Dependency Error": 1, "Performance Error": 1 },
    "new_errors": 5,
    "known_errors": 3
  }
}
```

Print a classification summary:
```
Classification complete: 93 raw matches -> 8 unique errors
  CRITICAL: 1  |  HIGH: 3  |  MEDIUM: 3  |  LOW: 1
  New: 5  |  Known: 3 (with existing issues)
```

**Graceful degradation:** If the classification agent fails, fall back to a pattern-scan-only report. Use the raw pattern matches grouped by category as the classification, assign severity based on category (Exceptions/Memory → HIGH, HTTP 5xx/Timeouts → MEDIUM, others → LOW), and note in the report that AI classification was unavailable.

---

## Step 6 — Codebase correlation (parallel agents)

For each CRITICAL and HIGH severity error from classification, launch a **background agent** (`model: "sonnet"`) to find related code in the current project.

Each correlation agent should:

1. **Extract identifiers** from the error: class names, method names, function names, file paths mentioned in stack traces, error codes
2. **Search the codebase** using Grep and Glob for:
   - Exact class/method/function name matches
   - Error message string literals
   - Related exception handlers (try/catch blocks)
   - Configuration references (if Configuration Error)
3. **Build a correlation table** for the error:

```json
{
  "error_id": "err-001",
  "related_files": [
    {
      "file": "src/services/UserService.java",
      "line": 142,
      "relevance": "Exception origin — getProfile() method",
      "snippet": "User user = userRepository.findById(id).orElseThrow(...);"
    },
    {
      "file": "src/config/DatabaseConfig.java",
      "line": 38,
      "relevance": "Connection pool configuration",
      "snippet": "maxPoolSize = env.getProperty(\"db.pool.max\", 10);"
    }
  ],
  "diagnosis": {
    "root_cause_hypothesis": "Null user profile returned when user exists in auth but not in profile database (data inconsistency)",
    "affected_code_paths": ["UserService.getProfile() -> UserRepository.findById()", "ProfileController.show() -> UserService.getProfile()"],
    "suggested_fix": "Add null check with graceful fallback or ensure profile creation is atomic with user registration",
    "verification_steps": [
      "Check if user IDs in auth table have matching profile entries",
      "Review user registration flow for race conditions",
      "Add integration test for profile lookup with missing profile"
    ]
  }
}
```

After all correlation agents complete, merge results. Print summary:
```
Codebase correlation:
  err-001 (CRITICAL) NullPointerException in UserService -> 2 related files
  err-002 (HIGH) Connection timeout to Redis            -> 3 related files
  err-003 (HIGH) OutOfMemoryError in BatchProcessor     -> 1 related file
  err-004 (HIGH) 503 from payment gateway               -> 0 related files (external dependency)
```

**Graceful degradation:** If a correlation agent fails for a specific error, skip correlation for that error and note "correlation unavailable" in the report. Continue with other errors.

---

## Step 7 — Generate report

Write a comprehensive report to `.log-patrol/reports/YYYY-MM-DD-HHMMSS.md` (use current timestamp).

Create the reports directory if needed: `mkdir -p .log-patrol/reports`

### Report structure

```markdown
# Log Patrol Report — YYYY-MM-DD HH:MM:SS

## Scan Summary
- **Period:** {start} to {end}
- **Sources scanned:** {N} of {total} ({list failures if any})
- **Raw matches:** {count}
- **Unique errors:** {count}

## Severity Breakdown
| Severity | Count | Trend |
|----------|-------|-------|
| CRITICAL | N     | ...   |
| HIGH     | N     | ...   |
| MEDIUM   | N     | ...   |
| LOW      | N     | ...   |

## Errors by Severity

### CRITICAL

#### err-XXX: {title}
- **Category:** {category}
- **Occurrences:** {count} ({trend})
- **Sources:** {source list}
- **First seen:** {timestamp}
- **Last seen:** {timestamp}
- **Status:** {new | known — issue #N}

**Sample log lines:**
\```
{2-3 representative log lines}
\```

**Related code:**
| File | Line | Relevance |
|------|------|-----------|
| path | N    | description |

**Diagnosis:**
- **Root cause hypothesis:** {text}
- **Affected code paths:** {list}
- **Suggested fix:** {text}
- **Verification steps:**
  1. {step}
  2. {step}

### HIGH
{same structure per error}

### MEDIUM
{same structure, abbreviated — no diagnosis section}

### LOW
{same structure, abbreviated — no diagnosis section}

## GitHub Issues
| Error | Action | Issue |
|-------|--------|-------|
| err-XXX | CREATE | (pending) |
| err-YYY | UPDATE | #42 |

## Scan Metadata
- **Config:** {N} sources configured
- **Classification:** {AI | pattern-only fallback}
- **Correlation:** {completed for N errors | partial | skipped}
```

Display the report to the user after writing it. For large reports, show the Scan Summary and Severity Breakdown, then the CRITICAL and HIGH errors in full, and summarize MEDIUM/LOW counts.

---

## Step 8 — GitHub issue management (approval gate)

**This step is skipped if `--skip-issues` was set.**
**If `--dry-run` was set:** Display the issue creation plan below but do NOT execute any `gh` commands. Print "Dry run — no issues created." and proceed to Step 9.

### 8a. Prepare issue plan

Determine the target repo:
1. If `--repo owner/repo` was provided, use it
2. Else if `default_repo` is set in config.json, use it
3. Else auto-detect: `git remote get-url origin` and parse `owner/repo`
4. If none available, skip issue creation with warning

For each unique error from classification:

**New error (not in known_errors):** Plan to CREATE a new issue:
- Title: `[{SEVERITY}] {error title}`
- Labels: `bug`, `log-patrol`, lowercase severity (e.g., `critical`, `high`)
- Body: error metadata + sample lines + codebase correlation table + full diagnosis plan

**Known error (exists in known_errors with a github_issue number):** Plan to UPDATE the existing issue with a comment:
- Comment: "Log Patrol detected {N} new occurrences since last scan ({timestamp}). Trend: {trend}."
- Include new sample lines if different from previous

### 8b. Present plan for approval (mandatory gate)

```
GitHub Issue Plan (target: owner/repo):

  CREATE:
    [CRITICAL] NullPointerException in UserService   -> labels: bug, log-patrol, critical
    [HIGH] Connection timeout to Redis               -> labels: bug, log-patrol, high
    [HIGH] OutOfMemoryError in BatchProcessor         -> labels: bug, log-patrol, high

  UPDATE:
    [MEDIUM] Slow query warning (issue #42)          -> add comment with 12 new occurrences
    [MEDIUM] Rate limit exceeded (issue #38)          -> add comment with 3 new occurrences

  SKIP (LOW severity):
    [LOW] Deprecation warning in legacy module       -> no issue (LOW)

Proceed? [y/n/edit]
```

- `[y]` — Execute all planned actions
- `[n]` — Skip issue creation entirely, proceed to Step 9
- `[edit]` — Let user modify the plan (remove items, change severity, etc.)

### 8c. Execute issue operations

For new issues, create with `gh`:
```bash
gh issue create --repo owner/repo \
  --title "[SEVERITY] Error title" \
  --label "bug,log-patrol,severity" \
  --body "ISSUE_BODY"
```

The issue body should include:

```markdown
## Error Details
- **Error ID:** err-XXX
- **Category:** {category}
- **Severity:** {severity}
- **First detected:** {timestamp}
- **Occurrences:** {count}
- **Trend:** {trend}
- **Sources:** {source list}

## Sample Log Lines
\```
{3-5 representative lines}
\```

## Codebase Correlation
| File | Line | Relevance |
|------|------|-----------|
| path | N    | description |

## Diagnosis Plan
### Root Cause Hypothesis
{hypothesis}

### Affected Code Paths
{list of code paths}

### Suggested Fix
{description}

### Verification Steps
1. {step}
2. {step}
3. {step}

---
*Generated by log-patrol*
```

For known issues, add a comment:
```bash
gh issue comment ISSUE_NUMBER --repo owner/repo \
  --body "COMMENT_BODY"
```

Capture the issue number from `gh issue create` output. Record each created/updated issue.

**Graceful degradation:** If `gh issue create` or `gh issue comment` fails for a specific error, log the failure and continue with remaining issues. Report failures at the end.

Print execution summary:
```
GitHub issues:
  Created: #51 [CRITICAL] NullPointerException in UserService
  Created: #52 [HIGH] Connection timeout to Redis
  Created: #53 [HIGH] OutOfMemoryError in BatchProcessor
  Updated: #42 [MEDIUM] Slow query warning (comment added)
  Failed:  #38 [MEDIUM] Rate limit exceeded (gh error: ...)
```

Ensure newly created labels (`log-patrol`, severity labels) exist. If `gh issue create` fails due to missing labels, create them first:
```bash
gh label create "log-patrol" --repo owner/repo --description "Auto-detected by log-patrol" --color "d93f0b" 2>/dev/null || true
gh label create "critical" --repo owner/repo --color "b60205" 2>/dev/null || true
gh label create "high" --repo owner/repo --color "d93f0b" 2>/dev/null || true
gh label create "medium" --repo owner/repo --color "fbca04" 2>/dev/null || true
gh label create "low" --repo owner/repo --color "0e8a16" 2>/dev/null || true
```

---

## Step 9 — Update state

Write/update `.log-patrol/state.json` with results from this run.

**State file structure** (`.log-patrol/state.json`):
```json
{
  "last_scan": "ISO-8601",
  "last_scan_timestamps": {
    "0": "ISO-8601",
    "1": "ISO-8601"
  },
  "known_errors": {
    "<sha256-hash>": {
      "error_id": "err-001",
      "title": "NullPointerException in UserService",
      "github_issue": 51,
      "first_seen": "ISO-8601",
      "last_seen": "ISO-8601",
      "total_occurrences": 142,
      "severity": "HIGH",
      "status": "open"
    }
  },
  "scan_history": [
    {
      "timestamp": "ISO-8601",
      "sources_scanned": 3,
      "sources_failed": 1,
      "raw_matches": 93,
      "unique_errors": 8,
      "issues_created": 3,
      "issues_updated": 1,
      "issues_failed": 1
    }
  ]
}
```

Update logic:
1. **`last_scan`**: Set to current timestamp
2. **`last_scan_timestamps`**: Set per-source timestamps for successful fetches
3. **`known_errors`**: For each error from classification:
   - If hash exists: update `last_seen`, increment `total_occurrences`, update `severity` if changed
   - If hash is new: add entry with `first_seen`, `last_seen`, `total_occurrences` from this scan, `github_issue` from Step 8
4. **`scan_history`**: Append entry for this run

Print state update confirmation:
```
State updated:
  Known errors: 8 (5 new, 3 updated)
  Scan history: 4 runs total
  Next scan will check from: {current timestamp}
```

---

## Graceful degradation summary

| Failure | Behavior |
|---------|----------|
| Individual source fetch fails | Skip that source, continue with others |
| Missing tool (aws, docker) | Skip those source types with warning |
| Classification agent fails | Fall back to pattern-scan-only report |
| Correlation agent fails for one error | Skip correlation for that error, note in report |
| `gh issue create` fails | Continue with remaining issues, record failure |
| `gh auth status` fails (without --skip-issues) | Warn, offer to continue with --skip-issues implied |
| All source fetches fail | Stop with error summary |
| No config / no sources | Stop with setup instructions |
