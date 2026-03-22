# Audit Deep Scan — Agent Prompt & Finding Format

## Agent Prompt Template

Launch 6 background agents in a SINGLE message, one per threat category. Each agent uses `subagent_type="general-purpose"` with `run_in_background=true`.

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

Write your findings to .audit/{NN}-{CATEGORY_SLUG}.md using the finding report format below.
```

## Category-Specific File Targets

| Category | Priority files |
|----------|---------------|
| Credential Theft | Entry points, env/config handlers, auth modules, browser integration code |
| Crypto Theft | Clipboard handlers, wallet integration code, financial modules, background workers |
| Data Exfiltration | Network modules, HTTP clients, logging utilities, analytics code, build scripts |
| Backdoors | Entry points, server setup, WebSocket handlers, dynamic imports, eval/exec calls |
| Supply Chain | `package.json` scripts, `setup.py`/`setup.cfg`, `Cargo.toml`/`build.rs`, `Makefile`, CI configs, prebuilt binaries |
| Persistence | Install scripts, post-install hooks, shell integration code, service definitions, cron-related code |

## Agent File Naming Convention

| Category | Output file |
|----------|------------|
| Credential Theft | `.audit/01-credential-theft.md` |
| Crypto Theft | `.audit/02-crypto-theft.md` |
| Data Exfiltration | `.audit/03-data-exfiltration.md` |
| Backdoors | `.audit/04-backdoors.md` |
| Supply Chain | `.audit/05-supply-chain.md` |
| Persistence | `.audit/06-persistence.md` |

---

## Finding Report Format

Each agent writes its output file in this format:

```markdown
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
