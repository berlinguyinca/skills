## Synthesis Agent — REPORT.md Format

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
| {Specialist 1 dimension} | Good/Fair/Needs Work | N | N | one-liner |
| {Specialist 2 dimension} | ... | ... | ... | ... |
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

{SAAS_SYNTHESIS_SECTIONS}

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

### SaaS synthesis additions

When APP_TYPE is `saas`, replace `{SAAS_SYNTHESIS_SECTIONS}` with:

```
## Revenue Opportunities
Findings that represent monetization or growth opportunities.
Prioritize by estimated revenue impact (high/medium/low).

## Go-to-Market Readiness
- Self-serve readiness: onboarding, pricing page, payment flow
- Enterprise readiness: SSO, compliance, multi-tenancy, audit logging
- What is blocking each channel?
```

For non-saas APP_TYPEs, omit `{SAAS_SYNTHESIS_SECTIONS}` entirely.

---

## Update Synthesis Report (Step 5h)

Launch a foreground Agent (`subagent_type="general-purpose"`) to update the report:

```
You are updating the analysis report after fixes were applied.

Read .analysis/REPORT.md and all .analysis/fixes/*-fix-summary.md files.

Update REPORT.md:
1. Add a "## Fixes Applied" section after the Scorecard, listing each fix with status (PASS/FAIL/REVERTED)
2. In Priority 1 and Priority 2 sections, mark fixed items with [FIXED] prefix on their title
3. Update the Scorecard health ratings if fixes improved a dimension (e.g., Security went from "Needs Work" to "Fair")
4. Update the Executive Summary to reflect fixes applied (e.g., "X of Y critical issues were automatically resolved")
5. If .analysis/fixes/simplification-summary.md exists, add a "## Simplifications Applied" section after "Fixes Applied" listing each simplification with affected files
6. If .analysis/fixes/coverage-enforcement-summary.md exists, add a "## Tests Generated" section with coverage delta (before/after percentage) and list of generated test files

Write the updated report back to .analysis/REPORT.md
```
