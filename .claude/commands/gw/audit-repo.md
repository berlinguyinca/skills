---
name: audit-repo
description: Security audit for GitHub repositories — analyzes code for malicious patterns, credential theft, crypto wallet attacks, backdoors, and supply chain risks before local use. Use when the user wants to audit a repo for security risks, malicious code, backdoors, or supply chain attacks.
argument-hint: "[<github-url>] [--deep] [--tools] [--refresh-threats] [--skip-pptx] [--skip-planning|--skip-gsd] [--publish] [--publish-repo <owner/repo>] [--publish-list] [--no-branch]"
---

## Step 0 — Preamble

Resolve the gw-skills repo path, then read and follow `$GW_REPO/.claude/commands/gw/_shared/preamble.md` for update check and GSD project detection:

```bash
GW_REPO="$(cd "$(readlink ~/.claude/commands/gw)/../../.." 2>/dev/null && pwd)" || GW_REPO="$HOME/.gw-skills"
```

GW_REPO persists for the duration of this skill run — do not re-resolve it in later steps.

---

## Step 0.5 — Branch Isolation

Set `SKILL_NAME="audit-repo"`.

Read and follow `$GW_REPO/.claude/commands/gw/_shared/branch-first.md` for branch creation.

---

## Step 1 — Parse arguments & acquire repo

You are an orchestrator for repository security auditing. You analyze code for malicious patterns, credential theft, crypto wallet attacks, backdoors, and supply chain risks before local use. Follow these steps precisely.

Parse the arguments: "$ARGUMENTS"

| Flag | Variable | Default | Notes |
|------|----------|---------|-------|
| positional `http…`, `git@…`, or `owner/repo` | REPO_URL | — | First arg that looks like a URL or `owner/repo` |
| `--deep` | DEEP_MODE | false | |
| `--tools` | TOOL_SCAN | false | |
| `--refresh-threats` | FORCE_REFRESH | false | |
| `--skip-pptx` | SKIP_PPTX | false | |
| `--skip-planning` / `--skip-gsd` | SKIP_PLANNING | false | |
| `--publish` | PUBLISH | false | |
| `--publish-repo <owner/repo>` | — | — | Persist to `~/.config/gw-skills/audit-repo.json`, confirm, and **stop** |
| `--publish-list` | — | — | Display configured publish repo + past publications, then **stop** |
| `--no-branch` | NO_BRANCH | false | Skip branch isolation (see Step 0.5) |
| `--hire` / `--fire` / `--roster` | — | — | Redirect: "Use `/gw:workforce`…" and **stop** |

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

Read and follow `$GW_REPO/.claude/commands/gw/_shared/audit-threat-intel.md` for the baseline cache structure, refresh logic, and WebSearch query templates.

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

Read and follow `$GW_REPO/.claude/commands/gw/_shared/audit-deep-scan.md` for the agent prompt template, category-specific file targets, and finding report format.

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

Read and follow `$GW_REPO/.claude/commands/gw/_shared/audit-synthesis-format.md` for the exact format of both output files (`.audit/REPORT.md` and `.audit/EXECUTIVE-SUMMARY.md`).

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

Read and follow `$GW_REPO/.claude/commands/gw/_shared/audit-pptx-slides.md` for slide structures, data file contents, execution commands, and output paths.

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

## Step 9.5 — Intent Commit & Auto-PR

Read and follow `$GW_REPO/.claude/commands/gw/_shared/intent-commit.md` to write and commit the `.gw-intent.md` file.

Then read and follow `$GW_REPO/.claude/commands/gw/_shared/auto-pr.md` to create a PR with the `agent_merge` label.

---

## Final — Session Summary

Read and follow `$GW_REPO/.claude/commands/gw/_shared/session-summary.md`.

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
