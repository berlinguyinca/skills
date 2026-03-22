# Audit Synthesis — Report Format

The synthesis agent writes two files after reading all category reports.

## `.audit/REPORT.md` (technical report)

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

## `.audit/EXECUTIVE-SUMMARY.md` (non-technical summary)

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
