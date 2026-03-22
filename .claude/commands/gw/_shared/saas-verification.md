# SaaS Coherence Verification

Verification agent prompt for Phase 3.5 of gw:saas-idea.

---

Apply `superpowers:verification-before-completion` — launch a single **foreground** Agent (`subagent_type="general-purpose"`) that reads all deep-dive artifacts and checks cross-document coherence.

### Verification agent prompt

```
You are a quality assurance analyst. Your job is to verify coherence across SaaS idea deliverables before proceeding to final assembly.

Read the following files:
- `.saas-ideas/deep-dive/TECH-SPEC.md`
- `.saas-ideas/deep-dive/IMPLEMENTATION-PROMPTS.md`
- `.saas-ideas/deep-dive/BUSINESS-PLAN.md`

Run these 4 coherence checks and report results:

### Check 1: Mandatory Stack
Verify that ALL of the following appear in BOTH TECH-SPEC.md AND IMPLEMENTATION-PROMPTS.md:
- PostgreSQL (database)
- Google OAuth (auth)
- Stripe (payments)
- AWS (hosting)
- Terraform (infrastructure)
- codingandmore.net (domain)

### Check 2: Phase Alignment
Verify that the timeline phases/milestones in TECH-SPEC.md (Section 8: Timeline) align with the build phases in IMPLEMENTATION-PROMPTS.md (Section 2: Phase-by-Phase Build Prompts). Check that:
- The number of phases is consistent (or logically mapped)
- Phase descriptions cover the same scope
- No major feature appears in one document but is missing from the other

### Check 3: Budget Consistency
Verify that the BUDGET tier is applied consistently:
- Revenue projections in BUSINESS-PLAN.md match the budget tier assumptions
- Infrastructure costs in TECH-SPEC.md match the budget tier
- Team size assumptions are consistent across all documents
- Timeline estimates are calibrated to the budget tier

### Check 4: Idea Coherence
Verify that the idea name, description, and core value proposition are consistent across all three documents. No document should describe a fundamentally different product.

Write the verification report to `.saas-ideas/deep-dive/VERIFICATION.md` in this format:

```markdown
# Coherence Verification Report

**Date:** {today's date}
**Idea:** {idea name}

## Results

| Check | Status | Details |
|-------|--------|---------|
| Mandatory Stack | PASS/FAIL | {which items are present/missing in which files} |
| Phase Alignment | PASS/FAIL | {alignment summary or mismatches found} |
| Budget Consistency | PASS/FAIL | {consistency summary or contradictions found} |
| Idea Coherence | PASS/FAIL | {coherence summary or discrepancies found} |

## Summary
{overall assessment — all pass, or list of issues to address}
```
```
