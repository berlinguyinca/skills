---
name: log-patrol
description: Monitor production logs across deployment environments — detects errors, generates reports, creates GitHub issues with diagnosis plans. Use when analyzing production logs, tracking recurring errors, or correlating log errors with codebase locations
argument-hint: "[--add-source TYPE:CONN] [--remove-source IDX] [--list-sources] [--discover \"PROMPT\"] [--since DURATION] [--full] [--dry-run] [--skip-issues] [--repo owner/repo]"
---

## Step 0 — Preamble

Resolve the gw-skills repo path, then read and follow `$GW_REPO/.claude/commands/gw/_shared/preamble.md` for update check and GSD project detection:

```bash
GW_REPO="$(cd "$(readlink ~/.claude/commands/gw)/../../.." 2>/dev/null && pwd)" || GW_REPO="$HOME/.gw-skills"
```

GW_REPO persists for the duration of this skill run — do not re-resolve it in later steps.

---

## Step 1 — Parse arguments & config management

Note: This skill benefits from using Sonnet for agent spawns due to high-volume parallel log analysis. If no GSD model profile is active, prefer Sonnet.

You are an orchestrator for production log monitoring and analysis. You fetch logs from multiple sources, detect errors, classify them, correlate with codebase, generate reports, and create GitHub issues with diagnosis plans. Follow these steps precisely.

**Config directory:** `.log-patrol/` (project-local, relative to current working directory)

Parse the arguments: "$ARGUMENTS"

| Flag | Variable | Default | Notes |
|------|----------|---------|-------|
| `--add-source <TYPE:CONN>` | — | — | TYPE: `ssh`, `cloudwatch`, `local`, `docker`. See source format below. Save and **stop** |
| `--remove-source <IDX_OR_NAME>` | — | — | Remove by numeric index or connection string. Save and **stop** |
| `--list-sources` | — | — | Show all configured sources and **stop** |
| `--discover "PROMPT"` | — | — | Auto-discover log sources from project context and active probing, then **stop** |
| `--since <DURATION>` | SINCE | last scan / `24h` | Accepts: `1h`, `6h`, `24h`, `7d`, etc. |
| `--full` | FULL_SCAN | false | Ignore last-scan timestamp, scan full history |
| `--dry-run` | DRY_RUN | false | Scan and report but do NOT create GitHub issues |
| `--skip-issues` | SKIP_ISSUES | false | Skip GitHub issue creation entirely |
| `--repo <owner/repo>` | TARGET_REPO | auto-detected | Target GitHub repo for issues |

Read and follow `$GW_REPO/.claude/commands/gw/_shared/log-patrol-sources.md` for source format connection strings.

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

Read and follow `$GW_REPO/.claude/commands/gw/_shared/log-patrol-sources.md` for the file/pattern table and what to extract. Combine findings with the user's PROMPT to build a list of **candidate sources** (type + connection string + confidence level: high/medium/low).

### Phase B — Active probing (parallel agents, 1 per target type)

Read and follow `$GW_REPO/.claude/commands/gw/_shared/log-patrol-sources.md` for probe commands per source type. Launch a background agent (`model: "sonnet"`) per distinct source type to verify and discover specific log paths.

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

Read and follow `$GW_REPO/.claude/commands/gw/_shared/log-patrol-sources.md` for fetch commands per source type.

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

Read and follow `$GW_REPO/.claude/commands/gw/_shared/log-patrol-sources.md` for error detection patterns, case sensitivity rules, and classification tables.

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

### 5b–5d. Categorize, assess severity, detect trends
Read and follow `$GW_REPO/.claude/commands/gw/_shared/log-patrol-sources.md` for category list, severity criteria, and trend values.

### 5e. Match against known errors
Compare each unique error against `known_errors` in state.json using the error hash (SHA-256 of normalized error message — stripped of timestamps, IDs, and variable data). If a match exists, mark it as `known` with its existing `error_id` and `github_issue` number.

Read and follow `$GW_REPO/.claude/commands/gw/_shared/log-patrol-issue-template.md` for the classification.json output schema. The agent writes its output to `.log-patrol/classification.json`.

Print a classification summary:
```
Classification complete: 93 raw matches -> 8 unique errors
  CRITICAL: 1  |  HIGH: 3  |  MEDIUM: 3  |  LOW: 1
  New: 5  |  Known: 3 (with existing issues)
```

**Graceful degradation:** If the classification agent fails, fall back to a pattern-scan-only report. Use the raw pattern matches grouped by category as the classification; read `$GW_REPO/.claude/commands/gw/_shared/log-patrol-sources.md` for fallback severity mapping. Note in the report that AI classification was unavailable.

---

## Step 6 — Codebase correlation (parallel agents)

For each CRITICAL and HIGH severity error from classification, launch a **background agent** (`model: "sonnet"`) to find related code in the current project.

Each correlation agent should:

1. **Extract identifiers** from the error: class names, method names, function names, file paths in stack traces, error codes
2. **Search the codebase** using Grep and Glob for exact matches, error message strings, exception handlers, and configuration references
3. **Build a correlation table** using the schema from `$GW_REPO/.claude/commands/gw/_shared/log-patrol-issue-template.md`

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
- Body: use template from `$GW_REPO/.claude/commands/gw/_shared/log-patrol-issue-template.md`

**Known error (exists in known_errors with a github_issue number):** Plan to UPDATE the existing issue with a comment using the update template from `$GW_REPO/.claude/commands/gw/_shared/log-patrol-issue-template.md`.

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

Use the issue body template from `$GW_REPO/.claude/commands/gw/_shared/log-patrol-issue-template.md`.

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

Read and follow `$GW_REPO/.claude/commands/gw/_shared/log-patrol-issue-template.md` for label creation commands if `gh issue create` fails due to missing labels.

---

## Step 9 — Update state

Write/update `.log-patrol/state.json` with results from this run.

**State file structure** (`.log-patrol/state.json`): top-level keys `last_scan` (ISO-8601), `last_scan_timestamps` (object keyed by source index), `known_errors` (object keyed by sha256 hash, each entry: `error_id`, `title`, `github_issue`, `first_seen`, `last_seen`, `total_occurrences`, `severity`, `status`), `scan_history` (array of run summaries with `timestamp`, `sources_scanned`, `sources_failed`, `raw_matches`, `unique_errors`, `issues_created`, `issues_updated`, `issues_failed`).

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

Read and follow `$GW_REPO/.claude/commands/gw/_shared/session-summary.md`.

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
