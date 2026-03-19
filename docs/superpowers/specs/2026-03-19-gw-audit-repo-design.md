# gw:audit-repo — Security Audit Skill Design

**Date:** 2026-03-19
**Status:** Approved
**Skill prefix:** gw:

## Skill File Frontmatter

```yaml
---
name: audit-repo
description: Security audit for GitHub repositories — analyzes code for malicious patterns, credential theft, crypto wallet attacks, backdoors, and supply chain risks before local use
argument-hint: "[<github-url>] [--deep] [--tools] [--refresh-threats] [--skip-pptx] [--skip-gsd] [--publish] [--publish-repo <owner/repo>] [--publish-list]"
---
```

## Overview

A security audit skill that analyzes GitHub repositories for malicious code before local use. Clones a repo (or analyzes the current directory), runs a tiered analysis across 6 threat categories, produces a traffic-light verdict with confidence score, and generates dual executive/technical reports and presentations.

Self-updating threat intelligence ensures the skill stays relevant as attack techniques evolve.

## Interface

```
/gw:audit-repo [<github-url>] [--deep] [--tools] [--refresh-threats] [--skip-pptx] [--skip-gsd]
               [--publish] [--publish-repo <owner/repo>] [--publish-list]
```

### Arguments

| Flag | Description | Default |
|------|-------------|---------|
| `<github-url>` | Clone this repo to a temp dir and analyze it | Analyze current directory |
| `--deep` | Skip surface scan, go straight to full deep analysis | Tiered (surface first) |
| `--tools` | Also run external security tools if available | Off |
| `--refresh-threats` | Force-refresh cached threat intelligence | Use cache if <7 days |
| `--skip-pptx` | Skip PowerPoint generation | Generate both decks |
| `--skip-gsd` | Skip GSD integration | Auto-detect |
| `--publish` | Push findings to configured GitHub repo | Off |
| `--publish-repo <owner/repo>` | Configure publish target (persisted) | None |
| `--publish-list` | Show configured publish repo and past publications | |

### Workflow Routing

| Condition | Steps executed |
|-----------|----------------|
| Default (no flags) | 0 → 1 → 2 → 3 → (if not SAFE) 4 → 5 → 6 → 7 → 8 → 9 |
| `--deep` | 0 → 1 → 2 → skip 3 → 4 → 5 → 6 → 7 → 8 → 9 |
| `--tools` | adds Step 4b between 4 and 5 |
| `--publish` | adds publish sub-step in Step 8a |
| Surface scan = SAFE | 0 → 1 → 2 → 3 → offer deep scan or stop |
| `--publish-repo` / `--publish-list` | 0 → 1 → config management → stop |
| `--hire/--fire/--roster` | 0 → 1 → redirect to `/gw:workforce` → stop |

**Approval gates** (stop and wait for user confirmation):
- After Step 3 — if surface scan is SAFE, offer deep scan or stop
- After Step 6 — if verdict is CAUTION, user decides to proceed, deep scan, or abort
- After Step 6 — if verdict is DANGEROUS, user decides whether to delete cloned directory

## Steps

### Step 0 — Update check

Resolve the gw-skills repo directory and run its update check script:

```bash
GW_REPO="$(cd "$(readlink ~/.claude/commands/gw)/../../.." 2>/dev/null && pwd)" || GW_REPO="$HOME/.gw-skills"
bash "$GW_REPO/check-update.sh" 2>/dev/null || true
```

If the output contains `UPDATE_AVAILABLE`, tell the user how many commits behind they are and ask: "gw-skills has updates available. Run /gw:update to install them, or continue?" If they want to update, invoke `/gw:update` and stop. Otherwise continue. If the script is missing or fails, skip silently.

### Step 1 — Parse arguments & acquire repo

Parse the arguments: "$ARGUMENTS"
- If `<github-url>` is present (positional, starts with `http`, `git@`, or matches `owner/repo`), set REPO_URL
- If `--deep` is present, set DEEP_MODE=true
- If `--tools` is present, set TOOL_SCAN=true
- If `--refresh-threats` is present, set FORCE_REFRESH=true
- If `--skip-pptx` is present, set SKIP_PPTX=true
- If `--skip-gsd` is present, set SKIP_GSD=true
- If `--publish` is present, set PUBLISH=true
- If `--publish-repo <owner/repo>` is present, persist to config and stop
- If `--publish-list` is present, show config and stop
- If `--hire`, `--fire`, or `--roster` is present: tell the user "Use `/gw:workforce` for persona management." and stop.

#### 1a. Check for existing audit

Check if `.audit/` directory exists. If it does, ask: "`.audit/` already exists from a prior audit. Refresh [r], view existing report [v], or delete and start fresh [d]?" Handle accordingly.

Run `mkdir -p .audit`

#### 1b. Acquire repo

**If `REPO_URL` is provided:**
1. Validate URL format (GitHub URL, `owner/repo` shorthand, or any valid git URL — GitLab, Bitbucket, etc. are supported)
2. Create temp directory: `AUDIT_DIR=$(mktemp -d)`
3. Clone: `git clone --depth 1 <url> "$AUDIT_DIR/repo"` (shallow clone — no need for full history unless --tools includes trufflehog)
4. If `--tools` is set and trufflehog is available, clone with full history instead (trufflehog needs git history for secret scanning)
5. Set `REPO_DIR="$AUDIT_DIR/repo"` and `CLONED=true`
6. Extract repo name and owner from the URL for reporting

**If no URL:**
1. Verify current directory is a git repo: `git rev-parse --git-dir 2>/dev/null`
2. If not a git repo, ask: "This directory is not a git repository. Provide a GitHub URL, or continue analyzing this directory anyway?"
3. Set `REPO_DIR="."` and `CLONED=false`

**In both cases:**
- Record `COMMIT_HASH=$(git -C "$REPO_DIR" rev-parse HEAD 2>/dev/null)`
- Record `REPO_NAME` from git remote or directory name
- Auto-detect languages present (same detection as review-app Step 1b)
- Count files for sizing

### Step 2 — Threat intelligence refresh

**Cache location:** `~/.config/gw-skills/threat-intel.json`

**Cache structure:**
```json
{
  "last_updated": "2026-03-19",
  "ttl_days": 7,
  "categories": {
    "credential_theft": {
      "patterns": ["list of regex patterns"],
      "keywords": ["list of keywords to grep for"],
      "recent_techniques": [
        {
          "name": "technique name",
          "source": "URL",
          "date": "YYYY-MM-DD",
          "indicators": ["code patterns that indicate this technique"]
        }
      ]
    },
    "crypto_theft": { "...same structure..." },
    "data_exfiltration": { "...same structure..." },
    "backdoors": { "...same structure..." },
    "supply_chain": { "...same structure..." },
    "persistence": { "...same structure..." }
  }
}
```

**Refresh logic:**
- If cache does not exist → create with bundled baseline patterns + run WebSearch for all 6 categories
- If `--refresh-threats` → force WebSearch for all 6 categories regardless of age
- If cache is >7 days old → refresh all categories
- If cache is fresh → use as-is (surface scan) or refresh only the categories relevant to detected languages (deep scan)

**WebSearch queries per category:**
- `"latest {category} malware GitHub {current_year}"`
- `"malicious {language} package {ecosystem} discovered {current_year}"`
- `"{category} attack technique open source supply chain"`

Merge new findings into cache. Do not remove old patterns — threat patterns accumulate.

**Bundled baseline patterns (hardcoded in skill):** A minimal set of known-dangerous patterns that work without any cache. Includes: common reverse shell signatures, base64-encoded `eval` patterns, known malicious npm/PyPI package names, common exfiltration domains, crypto address regex patterns.

### Step 3 — Surface scan

Fast pattern matching using Grep and Glob. No agents — the orchestrator runs this directly.

**Pre-scan checks:**
- **File count:** Count files excluding `.git`, `node_modules`, `vendor`, `dist`, `build`, `__pycache__`. If >10,000 files, warn user and offer to continue or abort.
- **Binary files:** Glob for executables, `.so`, `.dll`, `.dylib`, `.wasm`, `.exe` files. Flag unexpected binaries (e.g., compiled executables in a JavaScript project) as SUSPICIOUS in the supply chain category.
- **Git submodules:** Check for `.gitmodules`. If present, warn: "This repo has git submodules that were not cloned. Submodules could contain additional code. Run with full clone to include them? [y/n]"
- **GitHub Actions:** Check `.github/workflows/*.yml` for `uses:` directives referencing non-verified or non-standard actions. Flag actions from unknown orgs as SUSPICIOUS in the supply chain category.

**Per-category surface checks:**

| Category | Surface scan method |
|----------|-------------------|
| Credential Theft | Grep for: `process.env` + outbound HTTP in same file, `keychain`, `credential_store`, `browser.*cookie`, `ssh.*key.*read`, known credential file paths (`~/.aws/credentials`, `~/.ssh/id_rsa`) |
| Crypto Theft | Grep for: crypto address regex patterns (BTC/ETH/SOL), `clipboard.*replace`, `wallet.*file`, `seed.*phrase`, mining pool domains |
| Data Exfiltration | Grep for: `curl\|wget\|fetch\|http\.request` to non-standard domains, base64-encoded strings >100 chars, `dns.*lookup` with encoded payloads, `screenshot`, `keylog` |
| Backdoors | Grep for: `eval\|exec\|Function\|spawn` with string concatenation or encoded input, reverse shell patterns, WebSocket connections to unknown hosts, dynamic `import()` from URLs |
| Supply Chain | Check: postinstall/preinstall scripts in package.json, setup.py `cmdclass` overrides, Cargo build scripts with network calls. Typosquatting check: compare dependency names against popular packages (npm top-1000, PyPI top-500, crates.io top-500 — lists bundled in skill baseline, refreshed with threat intel cache). Flag names with Levenshtein distance ≤2 from a popular package as SUSPICIOUS. Supported ecosystems: npm (package.json), PyPI (requirements.txt, pyproject.toml), crates.io (Cargo.toml), RubyGems (Gemfile). |
| Persistence | Grep for: `crontab`, `launchd`, `LaunchAgent`, `.bashrc\|.zshrc\|.profile` write patterns, `systemd.*service`, PATH manipulation |

**Surface scan also checks:**
- Files with suspicious names: `backdoor`, `exploit`, `payload`, `keylog`, `stealer`
- Obfuscation signals: files with >80% non-ASCII characters, extremely long single lines (>5000 chars), heavy use of char codes or hex escapes
- Hidden files/directories that shouldn't be in a normal project

**Surface verdict:**
- 0 matches across all categories → **SAFE** (offer deep scan or stop)
- 1+ matches → **CAUTION** or **DANGEROUS** depending on pattern severity → auto-proceed to deep scan

**If SAFE after surface scan:**
```
Surface Scan: SAFE (0 suspicious patterns detected)

Scanned {N} files across {N} languages.
No known malicious patterns found in surface scan.

Run deep analysis for thorough review [d], or accept surface result [enter]?
```

If user chooses deep scan → proceed to Step 4. If enter → skip to Step 5 (synthesis with surface-only data).

### Step 4 — Deep scan (parallel agents)

Launch 6 background agents in a SINGLE message, one per threat category. Each agent is `subagent_type="general-purpose"` with `run_in_background=true`.

**Agent prompt template:**

```
You are a {CATEGORY_NAME} security analyst performing a deep audit of a repository.

Repository: {REPO_NAME}
Languages: {DETECTED_LANGUAGES}
Working directory: {REPO_DIR}

## Threat Intelligence

{CACHED_THREAT_INTEL_FOR_THIS_CATEGORY}

## Your Task

1. If threat intel cache is >7 days old for your category, WebSearch for the latest {CATEGORY_NAME} attack techniques targeting {DETECTED_LANGUAGES} projects. Note any new patterns found.

2. Read files that are most likely to contain {CATEGORY_NAME} threats:
   {CATEGORY_SPECIFIC_FILE_TARGETS}

3. For each file, analyze:
   - What the code actually does (trace the logic, don't just pattern-match)
   - Whether outbound connections exist and where they go
   - Whether data is collected and where it's sent
   - Whether obfuscation is used and what it hides
   - Whether the behavior matches what the project claims to do (README vs reality)

4. For each finding, classify as:
   - CRITICAL: Confirmed malicious intent (evidence of deliberate harm)
   - SUSPICIOUS: Pattern matches but could be legitimate (explain both interpretations)
   - INFO: Worth noting but likely benign

## Rules

- READ the actual code — do not just grep for patterns
- Trace data flows: where does collected data GO?
- Compare README claims vs actual behavior — mismatches are red flags
- Decode any obfuscated strings (base64, hex, char codes) and report what they contain
- Check if network calls go to legitimate domains or suspicious ones
- Cite specific file paths with line numbers for every finding
- If you find NOTHING suspicious, say so explicitly — a clean report is valuable

## Output

Write your findings to .audit/{NN}-{CATEGORY_SLUG}.md in this format:

# {Category Name} Audit

**Date:** {today's date}
**Repository:** {REPO_NAME}
**Commit:** {COMMIT_HASH}
**Severity Summary:** {N} critical, {N} suspicious, {N} info

## Findings

### [CRITICAL] {Finding title}
**Files:** `path/to/file:42`
**Code:** (relevant snippet)
**Behavior:** {what this code actually does}
**Evidence:** {why this is malicious, not just suspicious}
**Risk:** {what happens if this runs on your machine}

### [SUSPICIOUS] {Finding title}
**Files:** `path/to/file:88`
**Code:** (relevant snippet)
**Behavior:** {what this code does}
**Benign interpretation:** {why it might be legitimate}
**Malicious interpretation:** {why it might be harmful}
**Recommendation:** {what to check manually}

---
**Category Verdict:** {Clean / Suspicious / Dangerous}
```

**Category-specific file targets:**

| Category | Priority files |
|----------|---------------|
| Credential Theft | Entry points, env/config handlers, auth modules, browser integration code |
| Crypto Theft | Clipboard handlers, wallet integration code, financial modules, background workers |
| Data Exfiltration | Network modules, HTTP clients, logging utilities, analytics code, build scripts |
| Backdoors | Entry points, server setup, WebSocket handlers, dynamic imports, eval/exec calls |
| Supply Chain | package.json scripts, setup.py/setup.cfg, Cargo build.rs, Makefile, CI configs, prebuilt binaries |
| Persistence | Install scripts, post-install hooks, shell integration code, service definitions, cron-related code |

### Step 4b — Tool scan (--tools only)

Run available external security tools. Each tool is optional — check availability before running.

| Tool | Check | Command | Parses |
|------|-------|---------|--------|
| semgrep | `command -v semgrep` | `semgrep --config auto --json "$REPO_DIR"` | JSON findings with severity and rule ID |
| trufflehog | `command -v trufflehog` | `trufflehog git "file://$REPO_DIR" --json` | Leaked secrets in git history |
| npm audit | `test -f "$REPO_DIR/package-lock.json"` | `cd "$REPO_DIR" && npm audit --json` | Known vulnerable dependencies |
| pip-audit | `command -v pip-audit` | `pip-audit -r "$REPO_DIR/requirements.txt" -f json` | Known vulnerable Python packages |
| cargo-audit | `command -v cargo-audit` | `cd "$REPO_DIR" && cargo audit --json` | Known vulnerable Rust crates |
| bundler-audit | `command -v bundler-audit` | `cd "$REPO_DIR" && bundler-audit check --format json` | Known vulnerable Ruby gems |

For each tool that runs:
1. Parse JSON output
2. Map findings to the 6 threat categories
3. Write to `.audit/tools-{tool-name}.md`
4. Note which tools were unavailable: "semgrep not installed — install for deeper static analysis"

### Step 5 — Synthesis

Launch a single foreground Agent (`subagent_type="general-purpose"`) that reads all findings and produces the verdict.

**Synthesis agent reads:**
- `.audit/[0-9]*-*.md` (all category reports)
- `.audit/tools-*.md` (tool reports, if any)
- Surface scan results (passed via prompt)

**Writes two files:**

**`.audit/REPORT.md`** (technical):
```markdown
# Security Audit Report

**Repository:** {name}
**URL:** {url}
**Commit:** {hash}
**Date:** {date}
**Languages:** {list}
**Verdict:** {SAFE|CAUTION|DANGEROUS} (confidence: {N}%)

## Threat Breakdown

| Category | Critical | Suspicious | Info | Status |
|----------|----------|------------|------|--------|
| Credential Theft | N | N | N | Clean/Suspicious/Dangerous |
| Crypto Theft | N | N | N | ... |
| Data Exfiltration | N | N | N | ... |
| Backdoors | N | N | N | ... |
| Supply Chain | N | N | N | ... |
| Persistence | N | N | N | ... |

## Critical Findings

(Full details of every CRITICAL finding with code evidence)

## Suspicious Findings

(Full details of every SUSPICIOUS finding with both interpretations)

## Tool Scan Results

(If --tools was used)

## Threat Intelligence

Patterns checked: {N} across {N} categories
Cache freshness: {date}
New techniques discovered: {list or "none"}

## Methodology

- Surface scan: {N} patterns checked across {N} files
- Deep scan: 6 specialist agents, {N} files read
- External tools: {list or "none"}
```

**`.audit/EXECUTIVE-SUMMARY.md`**:
```markdown
# Security Audit — {Repository Name}

**Date:** {date}
**Verdict:** {SAFE|CAUTION|DANGEROUS}
**Confidence:** {N}%

## Summary

{3-5 sentences in plain English: what was found, how serious it is, what the recommendation is. No code, no file paths, no jargon.}

## Risk Assessment

| Risk Area | Level | Key Concern |
|-----------|-------|-------------|
| Credential Safety | Low/Medium/High | {one-liner} |
| Financial Risk | Low/Medium/High | {one-liner} |
| Data Privacy | Low/Medium/High | {one-liner} |
| System Integrity | Low/Medium/High | {one-liner} |

## Recommendation

{Clear action: "Safe to use", "Review findings before using", or "Do not use — delete immediately"}

## What Was Checked

{Brief methodology in plain English — N files scanned, N threat categories, N patterns checked}
```

**Confidence scoring:**
- Each CRITICAL finding: +20-30% toward DANGEROUS
- Each SUSPICIOUS finding: +5-10%
- Confidence capped at 99%
- SAFE: 0 CRITICAL, ≤2 SUSPICIOUS, confidence ≥80% in clean result
- CAUTION: 1+ SUSPICIOUS without confirmed CRITICAL
- DANGEROUS: 1+ CRITICAL with confirmed malicious intent

### Step 6 — Present verdict

Display the verdict prominently:

**If SAFE:**
```
VERDICT: SAFE (confidence: {N}%)

{Repo name} — No malicious patterns detected.
Scanned {N} files, {N} threat categories, {N} patterns checked.

This repo appears clean. Proceed to use it.

Run gw:review-app for quality analysis [r], or done [d]?
```

**If CAUTION:**
```
VERDICT: CAUTION (confidence: {N}%)

{Repo name} — {N} suspicious patterns found.

{Table of suspicious findings — file, category, concern}

Review these findings before using this repo.
Proceed anyway [p], run deep scan [d] (if not already done), or abort [a]?
```

**APPROVAL GATE — Stop and wait for user decision.**

**If DANGEROUS:**
```
VERDICT: DANGEROUS (confidence: {N}%)

{Repo name} — {N} critical findings with confirmed malicious intent.

{Table of critical findings — file, category, evidence summary}

DO NOT USE THIS REPO.

{If CLONED: "Delete cloned directory now [y/n]?"}
```

If user confirms deletion: `rm -rf "$AUDIT_DIR"`

### Step 7 — PPTX generation

Skip if `--skip-pptx` is true.

**Design system:** Canonical gw-skills palette (9 colors, Calibri, 16:9, accent bar).

Generate two decks following the weekly-review dual-deck pattern:

**Executive deck** (max 6 slides):

| # | Slide | Content |
|---|-------|---------|
| 1 | Title | Repo name, "Security Audit", date, verdict badge (colored: green/amber/red) |
| 2 | Verdict | Traffic-light visual, confidence KPI card, recommendation in plain English |
| 3 | Risk Assessment | 4-quadrant risk grid (credential, financial, data privacy, system integrity) with color-coded levels |
| 4 | Threat Summary | 6-category bar chart — green for clean, amber for suspicious, red for dangerous |
| 5 | Recommendation | Clear action statement, next steps |
| 6 | Closing | "Full report: .audit/REPORT.md", date, "Generated by gw:audit-repo" |

**Technical deck** (up to 30 slides):

| # | Slide | Content |
|---|-------|---------|
| 1 | Title | Repo name, "Technical Security Audit", date, commit hash, verdict badge |
| 2 | Scan Overview | Files scanned, languages detected, patterns checked, tools run, cache freshness |
| 3 | Threat Breakdown | 6-category table with finding counts per severity |
| 4+ | Critical Findings | One slide per CRITICAL: file path, code snippet, behavior explanation, evidence, risk |
| N-4 | Suspicious Findings | Condensed table: file, pattern, benign vs malicious interpretation |
| N-3 | Tool Scan Results | Per-tool findings (if --tools was used) |
| N-2 | Threat Intelligence | Patterns checked, recent techniques discovered, cache info |
| N-1 | Methodology | Surface scan stats, deep scan agent coverage, tool coverage |
| N | Closing | Verdict, confidence, recommendation, "Generated by gw:audit-repo" |

**Output paths:**
- `docs/gw/audit-executive-{repo-name}-{YYYY-MM-DD}.pptx`
- `docs/gw/audit-technical-{repo-name}-{YYYY-MM-DD}.pptx`

**Execution:**
```bash
mkdir -p docs/gw
uv run --with python-pptx python /tmp/audit_repo_presentation.py
```
Fallback: `python3 -m pip install python-pptx && python3 /tmp/audit_repo_presentation.py`
If both fail: "PowerPoint generation failed — python-pptx is required. Install it with `pip install python-pptx` or use `--skip-pptx` to skip."

### Step 8 — Post-audit actions

**8a. Publish findings (`--publish`)**

If `--publish` is set:
1. Read config from `~/.config/gw-skills/audit-repo.json` for `publish_repo`
2. If not configured, tell user: "No publish repo configured. Run `/gw:audit-repo --publish-repo owner/repo` to set one."
3. Clone the publish repo to a temp directory
4. Create directory: `findings/{owner}/{repo}/`
5. Write files:
   - `metadata.json` — repo URL, commit hash, audit date, verdict, confidence, languages, category summary
   - `findings.json` — all findings with severity, category, indicators (anonymized: no local paths)
   - `summary.md` — human-readable executive summary
   - `threat-patterns.json` — extracted patterns for others to consume
6. Commit and push: `git add findings/ && git commit -m "audit: {owner}/{repo} — {verdict}" && git push`
7. If same repo+commit already published, ask: "Findings for this commit already published. Overwrite? [y/n]"

**8b. GSD integration**

Skip if `--skip-gsd` is true or verdict is SAFE.

If verdict is CAUTION or DANGEROUS and GSD is installed:
- Create a GSD milestone/project with remediation phases from the findings
- Each CRITICAL finding becomes a phase
- SUSPICIOUS findings are grouped into a review phase

**8c. Offer gw:review-app**

If verdict is SAFE, offer: "Run `/gw:review-app` for code quality analysis?"

### Step 9 — Cleanup

If `CLONED=true`:
- If verdict is DANGEROUS and user already deleted → done
- Otherwise ask: "Keep the cloned repo at `{AUDIT_DIR}` or delete it? [keep/delete]"
- If delete: `rm -rf "$AUDIT_DIR"`
- If keep: print the path for reference

Print final summary:
```
Audit complete:
  Repository: {name} ({commit hash})
  Verdict: {SAFE|CAUTION|DANGEROUS} ({confidence}%)
  Reports: .audit/REPORT.md, .audit/EXECUTIVE-SUMMARY.md
  Presentations: docs/gw/audit-executive-{name}-{date}.pptx, docs/gw/audit-technical-{name}-{date}.pptx
  Published: {yes — to owner/repo | no}
```

## Error Handling

- **Git clone fails:** show error, suggest checking URL and access permissions
- **Rate-limited WebSearch during threat intel refresh:** use cached patterns, note "threat intel may be stale"
- **Deep scan agent fails:** note as `[FAILED]` in status, synthesize with available reports. Max 2 retries per failed agent.
- **External tool fails:** note failure, continue with other tools and agent analysis
- **python-pptx unavailable:** suggest install or `--skip-pptx`
- **Publish repo clone/push fails:** show error, suggest checking permissions. Findings are still saved locally.
- **GSD not installed:** inform user, continue without GSD
- **Not a git repo (no URL, current dir):** allow analysis but note "no commit hash available"
- **Temp directory cleanup on failure:** If the skill fails mid-execution and `CLONED=true`, clean up `AUDIT_DIR` before exiting. Wrap the main workflow in a cleanup guard.
- **WebSearch-derived threat patterns:** Patterns from web searches are best-effort and may produce false positives. The bundled baseline patterns are the reliability floor.
- **Never force-push or use destructive git operations without asking**
