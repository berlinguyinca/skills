# SaaS Idea Debate

Debate round templates for Phase 2.5 of gw:saas-idea.

---

### Round 1 — Position Statements

```bash
mkdir -p .saas-ideas/debate/round1 .saas-ideas/debate/round2
```

Launch all team agents in parallel (`run_in_background=true`). Each agent reads `.saas-ideas/SHORTLIST.md` (top 5 ideas) and writes their position to `.saas-ideas/debate/round1/{PERSONA_SLUG}.md`.

Agent prompt template:

```
You are {PERSONA_NAME}, a specialist with the following profile:
- Background: {PERSONA_BACKGROUND}
- Perspective: {PERSONA_PERSPECTIVE}
- Priorities: {PERSONA_PRIORITIES}
- Debate style: {PERSONA_DEBATE_STYLE}

## Context

You are evaluating SaaS ideas from a shortlist.

## Your Task

1. Read the SaaS idea shortlist at `.saas-ideas/SHORTLIST.md` (focus on the top 5 ideas).
2. From your specialist perspective, which idea would you pursue and why?
3. Flag red flags on any ideas — risks others might miss.
4. Provide a feasibility and risk assessment for your top pick.

## Output

Write your position to: `.saas-ideas/debate/round1/{PERSONA_SLUG}.md`

Use this format:

---
persona: {PERSONA_NAME}
round: 1
date: {TODAY_DATE}
---

# Round 1 — Position Statement: {PERSONA_NAME}

## My Pick: #{N} — {Idea Name}

**Why (from my perspective):** {explanation}

## Red Flags

- **#{N} {Idea Name}:** {concern from this persona's perspective}

## Feasibility & Risk Assessment

- **Technical feasibility:** {assessment}
- **Market risk:** {assessment}
- **Revenue timeline:** {assessment}
```

---

### Round 2 — Cross-Examination

The supervisor (orchestrator) reads all Round 1 positions. Identifies the top 3 disagreements — ideas where agents strongly disagree. The devil's advocate challenges the strongest consensus.

Launch all team agents again in parallel (`run_in_background=true`) with:
- Their persona details
- All colleagues' Round 1 positions (concatenated)
- The identified disagreements
- A devil's advocate challenge targeting THIS persona's stance

Each writes to `.saas-ideas/debate/round2/{PERSONA_SLUG}.md`:

```
---
persona: {PERSONA_NAME}
round: 2
date: {TODAY_DATE}
---

# Round 2 — Cross-Examination: {PERSONA_NAME}

## Response to Disagreements

{Respond to each identified disagreement — hold, concede, or refine}

## Response to Devil's Advocate Challenge

{Rebuttal or concession}

## Mind Changes

- {What changed, if anything}

## Updated Pick (if changed)

{State updated pick or "Unchanged"}
```

---

### Round 3 — Supervisor Synthesis

A single foreground agent reads ALL Round 1 + Round 2 files and writes `.saas-ideas/CONSENSUS.md`:

```markdown
# Idea Debate Consensus

**Date:** {date}
**Team:** {N} specialists, 2 debate rounds
**Shortlist evaluated:** Top 5 ideas from SHORTLIST.md

## Consensus Recommendation

**Idea:** #{N} — {Idea Name}
**Consensus strength:** {N}/{N} specialists agree
**Why:** {synthesis of arguments}

## Risk-Adjusted Ranking

| Rank | Idea | Original Score | Debate Adjustment | Key Insight |
|------|------|---------------|-------------------|-------------|
| 1 | {name} | X.X | +/- Y | {what the debate revealed} |
| 2 | {name} | X.X | +/- Y | {insight} |
| ... | ... | ... | ... | ... |

## What Would Change the Recommendation

- {condition that would shift the consensus}

## Dissenting Views

- {persona}: {their disagreement and why it matters}
```

### Present results

Show the debate consensus alongside the shortlist. If the debate consensus #1 differs from the scoring #1, highlight the discrepancy. The debate consensus #1 becomes the default selection (overriding the scoring #1 for the recommendation).
