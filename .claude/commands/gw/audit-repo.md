---
name: audit-repo
description: Security audit for GitHub repositories — analyzes code for malicious patterns, credential theft, crypto wallet attacks, backdoors, and supply chain risks before local use
argument-hint: "[<github-url>] [--deep] [--tools] [--refresh-threats] [--skip-pptx] [--skip-planning|--skip-gsd] [--publish] [--publish-repo <owner/repo>] [--publish-list]"
---

## Step 0 — Preamble

Resolve the gw-skills repo path, then read and follow `$GW_REPO/.claude/commands/gw/_shared/preamble.md` for update check and GSD project detection:

```bash
GW_REPO="$(cd "$(readlink ~/.claude/commands/gw)/../../.." 2>/dev/null && pwd)" || GW_REPO="$HOME/.gw-skills"
```

GW_REPO persists for the duration of this skill run — do not re-resolve it in later steps.

---

## Step 1 — Parse arguments & acquire repo

You are an orchestrator for repository security auditing. You analyze code for malicious patterns, credential theft, crypto wallet attacks, backdoors, and supply chain risks before local use. Follow these steps precisely.

Parse the arguments: "$ARGUMENTS"
- If a positional argument is present that starts with `http`, `git@`, or matches the pattern `owner/repo` (no spaces, contains `/`), set REPO_URL to that value
- If `--deep` is present, set DEEP_MODE=true. Default: false
- If `--tools` is present, set TOOL_SCAN=true. Default: false
- If `--refresh-threats` is present, set FORCE_REFRESH=true. Default: false
- If `--skip-pptx` is present, set SKIP_PPTX=true. Default: false
- If `--skip-planning` or `--skip-gsd` is present, set SKIP_PLANNING=true. Default: false
- If `--publish` is present, set PUBLISH=true. Default: false
- If `--publish-repo <owner/repo>` is present: persist `{"publish_repo": "<owner/repo>"}` to `~/.config/gw-skills/audit-repo.json`, print "Publish target set to <owner/repo>." and stop
- If `--publish-list` is present: read `~/.config/gw-skills/audit-repo.json` and display the configured publish repo and a list of any past publications, then stop
- If `--hire`, `--fire`, or `--roster` is present: tell the user "Use `/gw:workforce` for persona management. Examples: `/gw:workforce --hire \"Name\" --background \"...\"`, `/gw:workforce --fire \"Name\"`, `/gw:workforce --roster`" and stop.

## Workflow routing

Based on arguments and detected state, the workflow may skip steps:

| Condition | Steps executed |
|-----------|----------------|
| Default (no flags) | 0 → 1 → 2 → 3 → (if not SAFE) 4 → 5 → 6 → 7 → 8 → 9 |
| `--deep` | 0 → 1 → 2 → skip 3 → 4 → 5 → 6 → 7 → 8 → 9 |

Note: `--deep` intentionally bypasses Step 3 (surface scan) and its approval gates — the user explicitly requested deep analysis.
| `--tools` | Adds Step 4b between Steps 4 and 5 |
| `--publish` | Adds publish sub-step in Step 8a |
| Surface scan = SAFE | 0 → 1 → 2 → 3 → offer deep scan or stop |
| `--publish-repo` / `--publish-list` | 0 → 1 → config management → stop |
| `--hire/--fire/--roster` | 0 → 1 → redirect to `/gw:workforce` → stop |

**Approval gates** (stop and wait for user confirmation):
- After Step 3 — if surface scan is SAFE, offer deep scan or stop
- After Step 6 — if verdict is CAUTION, user decides to proceed, deep scan, or abort
- After Step 6 — if verdict is DANGEROUS, user decides whether to delete cloned directory

---

### 1a. Check for existing audit

Check if `.audit/` directory exists in the current working directory. If it does, ask:

```
`.audit/` already exists from a prior audit. Refresh [r], view existing report [v], or delete and start fresh [d]?
```

- **[r]:** Proceed with a fresh audit, overwriting existing files
- **[v]:** Display `.audit/EXECUTIVE-SUMMARY.md` and `.audit/REPORT.md`, then stop
- **[d]:** `rm -rf .audit` and continue

After handling the above (or if `.audit/` did not exist), run: `mkdir -p .audit`

### 1b. Acquire repo

**If REPO_URL is set:**
1. Validate URL format — accept GitHub URLs, `owner/repo` shorthand (expand to `https://github.com/owner/repo`), GitLab, Bitbucket, or any valid git URL
2. Create temp directory: `AUDIT_DIR=$(mktemp -d)`
3. If `TOOL_SCAN=true` and trufflehog is available (`command -v trufflehog`), clone with full history: `git clone <url> "$AUDIT_DIR/repo"`
4. Otherwise, shallow clone: `git clone --depth 1 <url> "$AUDIT_DIR/repo"`
5. If clone fails, show the error and suggest checking the URL and access permissions, then stop
6. Set `REPO_DIR="$AUDIT_DIR/repo"` and `CLONED=true`
7. Extract REPO_NAME and REPO_OWNER from the URL for reporting

**If no REPO_URL:**
1. Verify current directory is a git repo: `git rev-parse --git-dir 2>/dev/null`
2. If not a git repo, ask: "This directory is not a git repository. Provide a GitHub URL, or continue analyzing this directory anyway? [url/continue]"
   - If user provides a URL, set REPO_URL and follow the REPO_URL branch above
   - If continue: proceed with current directory, note "no commit hash available" in the report
3. Set `REPO_DIR="."` and `CLONED=false`
4. Set REPO_NAME from directory name

**In both cases:**
- Record `COMMIT_HASH=$(git -C "$REPO_DIR" rev-parse HEAD 2>/dev/null)` (empty if not a git repo)
- Detect languages present by globbing for: `*.py`, `*.js`, `*.ts`, `*.rb`, `*.go`, `*.rs`, `*.java`, `*.cs`, `*.php`, `*.sh`, `*.bash`, `*.ps1`, `Dockerfile`, `*.tf`
- Count files excluding `.git`, `node_modules`, `vendor`, `dist`, `build`, `__pycache__`: store as FILE_COUNT

Print a brief acquisition summary:
```
Repository: {REPO_NAME} ({COMMIT_HASH or "no commit hash"})
Languages: {detected languages}
Files: {FILE_COUNT}
```

---

## Step 2 — Threat intelligence refresh

**Cache location:** `~/.config/gw-skills/threat-intel.json`

**Cache structure:**
```json
{
  "last_updated": "2026-03-19",
  "ttl_days": 7,
  "categories": {
    "credential_theft": {
      "patterns": ["process\\.env\\.[A-Z_]{4,}.*(?:fetch|http|axios|request)", "readFileSync.*(?:\\.ssh|id_rsa|id_ed25519|authorized_keys)", "keychain.*find-generic-password", "Security\\.itemCopyAttributesAndData", "chrome.*Login Data.*sqlite", "browser.*cookies.*sqlite"],
      "keywords": ["keychain", "credential_store", "browser_cookie", "ssh_key", "aws_credentials", "gcloud_credentials", "kubectl_config"],
      "recent_techniques": [
        {
          "name": "env var exfiltration via postinstall",
          "source": "https://socket.dev/blog/malicious-npm-packages",
          "date": "2026-01-01",
          "indicators": ["postinstall", "process.env", "fetch(", "http.request("]
        }
      ]
    },
    "crypto_theft": {
      "patterns": ["[13][a-km-zA-HJ-NP-Z1-9]{25,34}", "0x[a-fA-F0-9]{40}", "clipboard.*(?:replace|write|set).*(?:[13][a-km-zA-HJ-NP-Z1-9]{25,34}|0x[a-fA-F0-9]{40})", "(?:seed|mnemonic|phrase).*(?:read|steal|send|upload)", "\\.wallet\\b.*read"],
      "keywords": ["clipboard_replace", "wallet_steal", "seed_phrase", "mining_pool", "xmrig", "monero", "cryptonight"],
      "recent_techniques": [
        {
          "name": "clipboard hijack for crypto address substitution",
          "source": "https://blog.malwarebytes.com/",
          "date": "2026-01-01",
          "indicators": ["setInterval", "clipboard", "replace", "BTC", "ETH"]
        }
      ]
    },
    "data_exfiltration": {
      "patterns": ["(?:fetch|axios|http\\.request|curl|wget).*(?:pastebin\\.com|requestbin|webhook\\.site|burpcollaborator|ngrok\\.io|pipedream\\.net)", "btoa\\(|Buffer\\.from\\(.*base64|base64\\.b64encode.*decode.*eval", "dns\\.lookup.*(?:btoa|encodeURI|base64)", "screenshot.*(?:upload|send|post)", "keylog"],
      "keywords": ["exfiltrate", "data_theft", "phone_home", "beacon", "c2_server", "command_control"],
      "recent_techniques": [
        {
          "name": "DNS tunneling for data exfiltration",
          "source": "https://unit42.paloaltonetworks.com/",
          "date": "2026-01-01",
          "indicators": ["dns.lookup", "encode", "subdomain"]
        }
      ]
    },
    "backdoors": {
      "patterns": ["/bin/sh\\s+-i", "bash\\s+-c\\s+'exec bash", "nc\\s+.*\\s+-e\\s+/bin", "python.*socket.*subprocess", "eval\\((?:Buffer\\.from|atob|decode)\\(", "Function\\(['\"]return\\s+eval", "WebSocket.*(?:exec|spawn|eval)", "import\\(.*https?://"],
      "keywords": ["reverse_shell", "bind_shell", "netcat_listener", "meterpreter", "cobalt_strike", "beacon_payload"],
      "recent_techniques": [
        {
          "name": "dynamic import from remote URL",
          "source": "https://security.snyk.io/",
          "date": "2026-01-01",
          "indicators": ["import(", "https://", "eval("]
        }
      ]
    },
    "supply_chain": {
      "patterns": ["\"preinstall\"\\s*:", "\"postinstall\"\\s*:", "cmdclass.*install.*run", "build\\.rs.*Command.*new.*curl", "build\\.rs.*Command.*new.*wget"],
      "keywords": ["malicious_package", "typosquatting", "dependency_confusion", "protestware", "sabotage"],
      "recent_techniques": [
        {
          "name": "postinstall script with network call",
          "source": "https://socket.dev/",
          "date": "2026-01-01",
          "indicators": ["postinstall", "curl", "wget", "fetch"]
        },
        {
          "name": "known malicious package names",
          "source": "https://github.com/nicowillis/npm-malicious-packages",
          "date": "2026-01-01",
          "indicators": ["node-ipc", "colors@1.4.44-liberty-2", "event-source-polyfill@1.0.31", "ua-parser-js@0.7.29", "coa@2.0.3", "rc@1.2.9"]
        }
      ]
    },
    "persistence": {
      "patterns": ["crontab\\s+-[le]", "launchctl.*load", "plistlib.*dump.*LaunchAgents", "echo.*>>.*(?:\\.bashrc|\\.zshrc|\\.profile|\\.bash_profile)", "systemctl.*enable.*--now", "(?:HKCU|HKLM).*\\\\Run\\b"],
      "keywords": ["crontab_write", "launchagent_plist", "shell_profile_inject", "systemd_service", "registry_run_key", "startup_folder"],
      "recent_techniques": [
        {
          "name": "LaunchAgent plist for macOS persistence",
          "source": "https://objective-see.org/blog.html",
          "date": "2026-01-01",
          "indicators": ["LaunchAgents", "plistlib", "com.apple.launchd", "RunAtLoad"]
        }
      ]
    }
  }
}
```

**Refresh logic:**

| Condition | Action |
|-----------|--------|
| Cache file does not exist | Create with bundled baseline patterns above, then run WebSearch for all 6 categories |
| `--refresh-threats` is set (FORCE_REFRESH=true) | Run WebSearch for all 6 categories regardless of cache age |
| Cache exists and is >7 days old | Run WebSearch for all 6 categories |
| Cache exists and is fresh (<7 days) | Surface scan: use as-is. Deep scan: run WebSearch only for categories relevant to detected languages |

**WebSearch query templates per category** (substitute `{category}`, `{language}`, `{ecosystem}`, `{year}` as appropriate):
- `"latest {category} malware GitHub {year}"`
- `"malicious {language} package {ecosystem} discovered {year}"`
- `"{category} attack technique open source supply chain"`

For each result found, extract new patterns, keywords, and technique entries. **Merge into cache — do not remove existing entries.** Threat patterns accumulate over time; removing them would create blind spots.

After refresh (or confirming cache is fresh), print:
```
Threat intel: {N} patterns loaded across 6 categories (cache from {last_updated})
```

---

## Step 3 — Surface scan

Fast pattern matching using Grep and Glob. No agents — the orchestrator runs this directly.

### Pre-scan checks

Run all checks in parallel:

**File count:** Count files in `REPO_DIR` excluding `.git`, `node_modules`, `vendor`, `dist`, `build`, `__pycache__`. If FILE_COUNT >10,000, warn:
```
Warning: {FILE_COUNT} files found. This is a large repository and scanning may be slow.
Continue [enter], or abort [a]?
```

**Binary file detection:** Glob for `**/*.so`, `**/*.dll`, `**/*.dylib`, `**/*.wasm`, `**/*.exe` inside REPO_DIR. For each binary found, check whether it is expected given the detected languages (e.g., a `.dll` in a pure JavaScript project is unexpected). Flag unexpected binaries as SUSPICIOUS in the supply chain category.

**Git submodules:** Check for `.gitmodules` in REPO_DIR. If present, warn:
```
Warning: This repo has git submodules that were not cloned.
Submodules could contain additional malicious code not yet analyzed.
Run with full clone to include them? [y/n]
```

**GitHub Actions:** Glob for `.github/workflows/*.yml` in REPO_DIR. For each workflow file found, grep for `uses:` directives. Flag any action reference that:
- Comes from an organization other than `actions/`, `github/`, or `aws-actions/`
- Uses a mutable ref (branch name) instead of a pinned commit SHA
Mark flagged actions as SUSPICIOUS in the supply chain category.

### Surface scan — 6 categories

Run all category scans in parallel:

| Category | Scan method |
|----------|-------------|
| Credential Theft | Grep for: `process\.env` combined with `fetch\|http\|axios\|request` in same file; `keychain`; `credential_store`; `browser.*cookie`; `ssh.*key.*read`; literal paths `\.aws/credentials`, `\.ssh/id_rsa`, `\.ssh/id_ed25519` |
| Crypto Theft | Grep for: BTC address regex `[13][a-km-zA-HJ-NP-Z1-9]{25,34}`; ETH address regex `0x[a-fA-F0-9]{40}`; `clipboard.*replace\|clipboard.*write\|clipboard.*set`; `wallet.*file`; `seed.*phrase`; mining pool keywords: `xmrig`, `cryptonight`, `stratum+tcp` |
| Data Exfiltration | Grep for: outbound calls to suspicious domains (`pastebin\.com`, `requestbin`, `webhook\.site`, `burpcollaborator`, `ngrok\.io`, `pipedream\.net`); base64+eval patterns (`btoa\|b64encode.*eval`); `dns.*lookup` with encoded payload; keywords `screenshot`, `keylog` |
| Backdoors | Grep for: `/bin/sh\s+-i`; `bash.*exec bash`; `nc.*-e.*/bin`; `eval(` followed by `Buffer.from\|atob\|decode`; `Function(` with string arg; `WebSocket` to unknown host; `import(` with `http` URL |
| Supply Chain | Grep `package.json` for `"preinstall"` and `"postinstall"` keys; grep `setup.py`/`setup.cfg` for `cmdclass` with install override; grep `Cargo.toml`/`build.rs` for network calls; compare all dependency names from `package.json`, `requirements.txt`, `pyproject.toml`, `Cargo.toml`, `Gemfile` against the known-malicious package list in threat intel cache |
| Persistence | Grep for: `crontab\s+-[le]`; `launchctl.*load`; `LaunchAgent`; `echo.*>>.*\.bashrc\|\.zshrc\|\.profile`; `systemctl.*enable`; `HKCU.*Run\|HKLM.*Run` |

### Additional checks

Run in parallel with the 6-category scan:

- **Suspicious filenames:** Glob for files whose names contain `backdoor`, `exploit`, `payload`, `keylog`, or `stealer` (case-insensitive). Flag all matches as SUSPICIOUS.
- **Obfuscation signals:** Grep for lines >5000 characters; grep for files with heavy hex escaping (`\\x[0-9a-fA-F]{2}` appearing >20 times); grep for heavy char-code patterns (`String.fromCharCode` or `chr(` appearing >10 times). Flag as SUSPICIOUS.
- **Hidden files:** Glob for files/directories starting with `.` in REPO_DIR root (excluding `.git`, `.github`, `.gitignore`, `.gitmodules`, `.gitattributes`, `.editorconfig`, `.prettierrc`, `.eslintrc`, `.env.example`). Flag unexpected hidden entries for manual review.

### Surface scan verdict

Tally all matches across all checks. Classify each match as:
- **DANGEROUS:** Confirmed malicious pattern (e.g., reverse shell, known malicious package name, hardcoded crypto address with clipboard replacement)
- **SUSPICIOUS:** Pattern matches but could be legitimate

Determine verdict:
- 0 matches across all categories → **SAFE**
- Any DANGEROUS match → **DANGEROUS** — auto-proceed to Step 4
- Only SUSPICIOUS matches → **CAUTION** — auto-proceed to Step 4

**If SAFE after surface scan:**

```
Surface Scan: SAFE (0 suspicious patterns detected)

Scanned {FILE_COUNT} files across {N} languages.
No known malicious patterns found in surface scan.

Run deep analysis for thorough review [d], or accept surface result [enter]?
```

**APPROVAL GATE — Stop and wait for user decision.**

- If user chooses deep scan → proceed to Step 4
- If user presses enter → skip to Step 5 (synthesis with surface-only data)

**If CAUTION or DANGEROUS:** Print a summary table and auto-proceed to Step 4:

```
Surface Scan: {CAUTION|DANGEROUS} — {N} matches found

| Category | File | Pattern | Severity |
|----------|------|---------|----------|
| {category} | {file:line} | {pattern matched} | {SUSPICIOUS|DANGEROUS} |
...

Proceeding to deep scan...
```

If `--deep` was set, skip Step 3 entirely and go straight to Step 4.

---

## Step 4 — Deep scan (parallel agents)

Launch 6 background agents in a SINGLE message, one per threat category. Each agent uses `subagent_type="general-purpose"` with `run_in_background=true`.

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
| Supply Chain | `package.json` scripts, `setup.py`/`setup.cfg`, `Cargo.toml`/`build.rs`, `Makefile`, CI configs, prebuilt binaries |
| Persistence | Install scripts, post-install hooks, shell integration code, service definitions, cron-related code |

**Agent file naming convention:**

| Category | Output file |
|----------|------------|
| Credential Theft | `.audit/01-credential-theft.md` |
| Crypto Theft | `.audit/02-crypto-theft.md` |
| Data Exfiltration | `.audit/03-data-exfiltration.md` |
| Backdoors | `.audit/04-backdoors.md` |
| Supply Chain | `.audit/05-supply-chain.md` |
| Persistence | `.audit/06-persistence.md` |

After all background agents complete, verify each expected file exists. Print a status table:

```
Deep Scan Status:
  [done] 01-credential-theft.md    (0 critical, 2 suspicious, 3 info)
  [done] 02-crypto-theft.md        (0 critical, 0 suspicious, 0 info — clean)
  [done] 03-data-exfiltration.md   (1 critical, 1 suspicious, 0 info)
  [done] 04-backdoors.md           (0 critical, 1 suspicious, 2 info)
  [done] 05-supply-chain.md        (0 critical, 3 suspicious, 1 info)
  [FAILED] 06-persistence.md       (agent error)
```

For any `[FAILED]` entries, offer: "Retry failed scan? [y/n]" — if yes, re-launch only the failed agents. Maximum 2 retries per failed agent. After 2 failures, continue with available reports and note the gap in the synthesis.

### Step 4b — Tool scan (--tools only)

Run available external security tools. Each tool is optional — check availability before running. Run all available tools in parallel.

| Tool | Availability check | Command | What it finds |
|------|--------------------|---------|---------------|
| semgrep | `command -v semgrep` | `semgrep --config auto --json "$REPO_DIR"` | Static analysis findings with severity and rule ID |
| trufflehog | `command -v trufflehog` | `trufflehog git "file://$REPO_DIR" --json` | Leaked secrets in git history |
| npm audit | `test -f "$REPO_DIR/package-lock.json"` | `cd "$REPO_DIR" && npm audit --json` | Known vulnerable npm dependencies |
| pip-audit | `command -v pip-audit` | `pip-audit -r "$REPO_DIR/requirements.txt" -f json` | Known vulnerable Python packages |
| cargo-audit | `command -v cargo-audit` | `cd "$REPO_DIR" && cargo audit --json` | Known vulnerable Rust crates |
| bundler-audit | `command -v bundler-audit` | `cd "$REPO_DIR" && bundler-audit check --format json` | Known vulnerable Ruby gems |

For each tool that runs:
1. Parse JSON output
2. Map findings to the appropriate threat category
3. Write to `.audit/tools-{tool-name}.md`

For each unavailable tool, note: "{tool} not installed — install for deeper analysis."

---

## Step 5 — Synthesis

Launch a single foreground agent (`subagent_type="general-purpose"`) that reads all findings and produces the verdict.

**Synthesis agent reads:**
- `.audit/01-credential-theft.md` through `.audit/06-persistence.md` (all that exist)
- `.audit/tools-*.md` (if any)
- Surface scan results (passed via prompt)

**Confidence scoring:**
- Each CRITICAL finding: +20–30% toward DANGEROUS
- Each SUSPICIOUS finding: +5–10%
- Confidence capped at 99%
- **SAFE:** 0 CRITICAL, ≤2 SUSPICIOUS, confidence ≥80% in clean result
- **CAUTION:** 1+ SUSPICIOUS without confirmed CRITICAL
- **DANGEROUS:** 1+ CRITICAL with confirmed malicious intent

**The synthesis agent writes two files:**

**`.audit/REPORT.md`** (technical report):
```markdown
# Security Audit Report

**Repository:** {name}
**URL:** {url or "local directory"}
**Commit:** {hash or "N/A"}
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

(Full details of every CRITICAL finding with code evidence, file path, line numbers)

## Suspicious Findings

(Full details of every SUSPICIOUS finding with benign and malicious interpretations)

## Tool Scan Results

(If --tools was used: per-tool findings mapped to threat categories)

## Threat Intelligence

Patterns checked: {N} across {N} categories
Cache freshness: {last_updated date}
New techniques discovered this run: {list or "none"}

## Methodology

- Surface scan: {N} patterns checked across {FILE_COUNT} files
- Deep scan: 6 specialist agents, {N} files read
- External tools: {list or "none"}
```

**`.audit/EXECUTIVE-SUMMARY.md`** (non-technical summary):
```markdown
# Security Audit — {Repository Name}

**Date:** {date}
**Verdict:** {SAFE|CAUTION|DANGEROUS}
**Confidence:** {N}%

## Summary

{3–5 sentences in plain English: what was found, how serious it is, what the recommendation is. No code, no file paths, no jargon.}

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

---

## Step 6 — Present verdict

Display the verdict prominently to the user.

**If SAFE:**
```
VERDICT: SAFE (confidence: {N}%)

{Repo name} — No malicious patterns detected.
Scanned {FILE_COUNT} files, 6 threat categories, {N} patterns checked.

This repo appears clean. Proceed to use it.

Run gw:review-app for quality analysis [r], or done [d]?
```

**If CAUTION:**
```
VERDICT: CAUTION (confidence: {N}%)

{Repo name} — {N} suspicious patterns found.

| File | Category | Concern |
|------|----------|---------|
| {path:line} | {category} | {brief description} |

Review these findings before using this repo.
Full technical report: .audit/REPORT.md

Proceed anyway [p], run deeper scan [d] (if not already done), or abort [a]?
```

**APPROVAL GATE — Stop and wait for user decision.**

- **[p]:** Continue to Step 7
- **[d]:** If deep scan not yet run, run it now (go back to Step 4), then re-synthesize and re-present verdict
- **[a]:** If CLONED=true, offer to delete cloned directory, then stop

**If DANGEROUS:**
```
VERDICT: DANGEROUS (confidence: {N}%)

{Repo name} — {N} critical findings with confirmed malicious intent.

| File | Category | Evidence |
|------|----------|---------|
| {path:line} | {category} | {brief evidence summary} |

DO NOT USE THIS REPO.
Full technical report: .audit/REPORT.md
```

If CLONED=true, ask: "Delete cloned directory now? [y/n]"
- If yes: `rm -rf "$AUDIT_DIR"`

**APPROVAL GATE — Stop and wait for user decision before proceeding to Step 7.**

---

## Step 7 — PPTX generation

Skip if SKIP_PPTX is true.

### 7a. Build JSON data file

Write `/tmp/audit_repo_presentation_data.json` with all data extracted from `.audit/REPORT.md`, `.audit/EXECUTIVE-SUMMARY.md`, and the raw findings from category audit files. Include: verdict, confidence, repo name, commit hash, date, languages, file count, finding counts per category, all CRITICAL findings, all SUSPICIOUS findings, risk assessment table, tool scan summary.

### 7b. Write and execute Python script

Write `/tmp/audit_repo_presentation.py` — reads the JSON data file and generates two `.pptx` files.

**Design system** (canonical gw-skills palette):
```
PRIMARY      = RGBColor(0x2C, 0x3E, 0x50)  # dark blue-gray — titles, headers
SECONDARY    = RGBColor(0x34, 0x49, 0x5E)  # medium blue-gray — body text
ACCENT       = RGBColor(0x34, 0x98, 0xDB)  # bright blue — highlights, KPIs
SUCCESS      = RGBColor(0x27, 0xAE, 0x60)  # green — SAFE verdict, clean categories
DANGER       = RGBColor(0xE7, 0x4C, 0x3C)  # red — DANGEROUS verdict, critical findings
WARNING      = RGBColor(0xF3, 0x9C, 0x12)  # amber — CAUTION verdict, suspicious findings
MUTED        = RGBColor(0x95, 0xA5, 0xA6)  # gray — captions, labels
BG_WHITE     = RGBColor(0xFF, 0xFF, 0xFF)
BG_LIGHT     = RGBColor(0xF8, 0xF9, 0xFA)
```

Font: Calibri throughout. Slide dimensions: 16:9 widescreen (13.333" x 7.5"). Accent bar: 0.06" wide ACCENT strip at left edge of every slide.

Verdict badge color: SUCCESS for SAFE, WARNING for CAUTION, DANGER for DANGEROUS.

**Executive deck** (max 6 slides):

| # | Slide | Content |
|---|-------|---------|
| 1 | Title | Repo name, "Security Audit", date, verdict badge (color-coded) |
| 2 | Verdict | Traffic-light visual (green/amber/red), confidence KPI card, recommendation in plain English |
| 3 | Risk Assessment | 4-quadrant grid: Credential Safety, Financial Risk, Data Privacy, System Integrity — each colored by level (green/amber/red) |
| 4 | Threat Summary | 6-category bar chart — green for clean, amber for suspicious, red for dangerous |
| 5 | Recommendation | Clear action statement, next steps in plain language |
| 6 | Closing | "Full report: .audit/REPORT.md", date, "Generated by gw:audit-repo" |

**Technical deck** (up to 30 slides):

| # | Slide | Content |
|---|-------|---------|
| 1 | Title | Repo name, "Technical Security Audit", date, commit hash, verdict badge |
| 2 | Scan Overview | Files scanned, languages detected, patterns checked, tools run, cache freshness KPI cards |
| 3 | Threat Breakdown | 6-category table with finding counts per severity (critical/suspicious/info) |
| 4+ | Critical Findings | One slide per CRITICAL finding: file path, code snippet, behavior explanation, evidence, risk |
| N-4 | Suspicious Findings | Condensed table: file, pattern, benign vs malicious interpretation |
| N-3 | Tool Scan Results | Per-tool findings if --tools was used; "No external tools run" if not |
| N-2 | Threat Intelligence | Patterns checked, recent techniques discovered this run, cache info |
| N-1 | Methodology | Surface scan stats, deep scan agent coverage, tool coverage |
| N | Closing | Verdict, confidence, recommendation, "Generated by gw:audit-repo" |

**Execution:**
```bash
mkdir -p docs/gw
uv run --with python-pptx python /tmp/audit_repo_presentation.py
```

Fallback: `python3 -m pip install python-pptx && python3 /tmp/audit_repo_presentation.py`

If both fail: "PowerPoint generation failed — python-pptx is required. Install it with `pip install python-pptx` or use `--skip-pptx` to skip presentation generation." Do not generate an HTML fallback.

**Output paths:**
- `docs/gw/audit-executive-{repo-name}-{YYYY-MM-DD}.pptx`
- `docs/gw/audit-technical-{repo-name}-{YYYY-MM-DD}.pptx`

Tell the user where both files were saved.

---

## Step 8 — Post-audit actions

### 8a. Publish findings (`--publish`)

Skip if PUBLISH is false.

1. Read `~/.config/gw-skills/audit-repo.json` for `publish_repo`
2. If not configured, tell user: "No publish repo configured. Run `/gw:audit-repo --publish-repo owner/repo` to set one." and skip publish
3. Clone the publish repo to a temp directory: `git clone https://github.com/{publish_repo} "$PUBLISH_DIR"`
4. Create directory: `$PUBLISH_DIR/findings/{owner}/{repo}/`
5. Write files:
   - `metadata.json` — repo URL, commit hash, audit date, verdict, confidence, languages, category summary counts
   - `findings.json` — all findings with severity, category, indicators (anonymized: no local paths)
   - `summary.md` — copy of `.audit/EXECUTIVE-SUMMARY.md`
   - `threat-patterns.json` — patterns extracted during this audit for community consumption
6. Commit and push:
   ```bash
   cd "$PUBLISH_DIR"
   git add findings/
   git commit -m "audit: {owner}/{repo} — {verdict} ({YYYY-MM-DD})"
   git push
   ```
7. If the same repo+commit combination already exists in findings, ask: "Findings for this commit already published. Overwrite? [y/n]"
8. If push fails, show the error and suggest checking repository permissions. Findings are still saved locally in `.audit/`.

### 8b. Implementation planning

Skip if SKIP_PLANNING is true or verdict is SAFE.

If verdict is CAUTION or DANGEROUS, present remediation options:

```
Security findings require remediation. How would you like to proceed?
  [p] Superpowers — invoke superpowers:writing-plans for remediation (recommended)
  [g] GSD — create remediation project/milestone
  [d] Done — handle remediation manually
```

**If [p] (default/recommended):** Tell the user: "Invoking superpowers:writing-plans. The plan will use `.audit/REPORT.md` as the requirements source. Each CRITICAL finding becomes a remediation phase." Then invoke the Skill tool: `Skill(skill="superpowers:writing-plans")`.

**If [g]:** Check if `~/.claude/commands/gsd/` exists. If it does:
- **Brownfield** (`.planning/PROJECT.md` exists): invoke `/gsd:new-milestone` referencing `.audit/REPORT.md` as the requirements source. Each CRITICAL finding becomes a remediation phase. SUSPICIOUS findings are grouped into a review phase.
- **Greenfield** (no `.planning/PROJECT.md`): invoke `/gsd:new-project` referencing `.audit/REPORT.md`.
If GSD commands don't exist, say: "GSD not installed. Use [p] Superpowers instead, or find the full audit in `.audit/REPORT.md`."

**If [d]:** Say "Full audit available in `.audit/REPORT.md`." and continue.

### 8c. Offer gw:review-app

If verdict is SAFE and the user hasn't already been prompted (in Step 6), offer: "This repo is clean. Run `/gw:review-app` for code quality analysis?"

---

## Step 9 — Cleanup

If `CLONED=true`:
- If verdict was DANGEROUS and user already deleted the directory → done
- Otherwise ask: "Keep the cloned repo at `{AUDIT_DIR}` or delete it? [keep/delete]"
  - If delete: `rm -rf "$AUDIT_DIR"`
  - If keep: print the path so the user has it for reference

Print final summary:
```
Audit complete:
  Repository:    {REPO_NAME} ({COMMIT_HASH or "no commit hash"})
  Verdict:       {SAFE|CAUTION|DANGEROUS} ({confidence}%)
  Reports:       .audit/REPORT.md
                 .audit/EXECUTIVE-SUMMARY.md
  Presentations: docs/gw/audit-executive-{repo-name}-{date}.pptx
                 docs/gw/audit-technical-{repo-name}-{date}.pptx
  Published:     {yes — to owner/repo | no}
```

---

## Error handling

- **Git clone fails:** Show error message, suggest checking the URL and access permissions
- **Rate-limited WebSearch during threat intel refresh:** Use cached patterns, note "threat intel may be stale — run with --refresh-threats when rate limit clears"
- **Deep scan agent fails:** Note as `[FAILED]` in status, synthesize with available reports. Maximum 2 retries per failed agent.
- **External tool fails:** Note failure, continue with remaining tools and agent analysis
- **python-pptx unavailable:** Suggest `pip install python-pptx` or `--skip-pptx`
- **Publish repo clone/push fails:** Show error, suggest checking permissions. Findings remain in `.audit/`.
- **GSD not installed:** Inform user, suggest superpowers:writing-plans as the primary alternative, continue without GSD
- **Not a git repo (current dir, no URL):** Allow analysis but note "no commit hash available" throughout the report
- **CLONED=true and skill fails mid-execution:** Offer to clean up `AUDIT_DIR` before exiting — never leave orphaned temp directories silently
- **WebSearch-derived threat patterns produce false positives:** Bundled baseline patterns are the reliability floor. Patterns from web searches are best-effort — the agent must READ the code, not just match patterns
- **Never force-push or use destructive git operations without asking**
