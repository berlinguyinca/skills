### Option 2: Report

Launch a single foreground synthesis agent (`subagent_type="general-purpose"`) that reads all artifacts:
- `{RESEARCH_DIR}/agents/*.md`
- `{RESEARCH_DIR}/debate/round1/*.md`
- `{RESEARCH_DIR}/debate/round2/*.md`
- `{RESEARCH_DIR}/CONSENSUS.md`

Writes `{RESEARCH_DIR}/REPORT.md`:

```markdown
# Research Report

**Question:** {RESEARCH_QUESTION}
**Date:** {date}
**Domain:** {RESEARCH_DOMAIN}
**Team:** {N} specialists, 2 debate rounds, {N} total sources
**Depth:** {lightweight|deep}
**Mode:** {PROJECT_CONTEXTUAL|STANDALONE}

## Executive Summary

{3-5 sentences summarizing the answer, confidence, and key recommendations}

## Background

{Why this question matters, what context drove the investigation}

## Methodology

### Research Team

| Persona | Background | Search Skills | Sources Found |
|---------|-----------|---------------|---------------|
| {name} | {background} | {search_skills} | {N} |

### Research Process

1. Parallel source investigation across {N} specialists
2. Structured debate (3 rounds with devil's advocate)
3. Supervisor synthesis and consensus building

## Findings

### Consensus Findings

{Detailed write-up of each finding with evidence, organized by confidence}

### Contested Findings

{Each disagreement with both sides presented fairly, supervisor resolution}

## Analysis

### Strengths of Evidence

{Where the evidence is strong and why}

### Weaknesses and Gaps

{Where the evidence is weak, missing, or conflicting}

### Devil's Advocate Assessment

{Summary of challenges raised, which conclusions survived, which were weakened}

## Recommendations

### Immediate Actions (High Confidence)

1. {Recommendation with full rationale and supporting evidence}

### Consider (Moderate Confidence)

1. {Recommendation}

### Investigate Further (Low Confidence)

1. {What needs more research and why}

## Appendices

### A. Source Index

{Complete table of all sources across all personas with URLs}

### B. Debate Transcript Summary

{Key exchanges from the debate rounds}
```

After writing REPORT.md, check if `pandoc` is available:
```bash
command -v pandoc
```

If pandoc exists, offer: "Convert report to .docx? [y/n]"
If yes:
```bash
pandoc "{RESEARCH_DIR}/REPORT.md" -o "{RESEARCH_DIR}/REPORT.docx" --reference-doc=/dev/null 2>/dev/null || pandoc "{RESEARCH_DIR}/REPORT.md" -o "{RESEARCH_DIR}/REPORT.docx"
```

Tell the user where the file(s) were saved.
