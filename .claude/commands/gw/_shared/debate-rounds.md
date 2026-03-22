## Step 5 — Structured Debate

Three rounds with the assembled team.

### Round 1 — Position Statements

Launch all team agents in parallel (`run_in_background=true`). Each agent gets a prompt with:
- Their persona details (name, background, perspective, priorities, debate_style)
- The research question and domain
- Instruction to read their own research file from `{RESEARCH_DIR}/agents/{PERSONA_SLUG}.md`
- Tasks: formulate a position on the research question, identify top 3-5 conclusions, flag uncertainties, propose recommendations
- Output to `{RESEARCH_DIR}/debate/round1/{PERSONA_SLUG}.md`

Agent prompt template:

```
You are {PERSONA_NAME}, a specialist with the following profile:
- Background: {PERSONA_BACKGROUND}
- Perspective: {PERSONA_PERSPECTIVE}
- Priorities: {PERSONA_PRIORITIES}
- Debate style: {PERSONA_DEBATE_STYLE}

## Research Question

{RESEARCH_QUESTION}

## Your Research

Read your research findings at: `{RESEARCH_DIR}/agents/{PERSONA_SLUG}.md`

## Your Task

Based on your research findings and specialist perspective:

1. Formulate your **position** on the research question — what is the answer or best approach?
2. Identify your **top 3-5 conclusions** ranked by confidence and importance.
3. Flag **uncertainties** — where your evidence is weak or conflicting.
4. Propose **concrete recommendations** — what should be done based on your findings?
5. Identify **risks** — what could go wrong if your recommendations are followed?

## Output

Write your position to: `{RESEARCH_DIR}/debate/round1/{PERSONA_SLUG}.md`

Use this format:

---
persona: {PERSONA_NAME}
round: 1
date: {TODAY_DATE}
---

# Round 1 — Position Statement: {PERSONA_NAME}

## Position

{Your overall position on the research question — 2-3 paragraphs}

## Top Conclusions

1. **{Conclusion}** (Confidence: {High|Medium|Low})
   - **Evidence:** {supporting evidence from your research}

2. **{Conclusion}** (Confidence: {High|Medium|Low})
   - **Evidence:** {supporting evidence}

3. **{Conclusion}** (Confidence: {High|Medium|Low})
   - **Evidence:** {supporting evidence}

(up to 5 conclusions)

## Uncertainties

- {Area of uncertainty and why}

## Recommendations

1. {Concrete recommendation with rationale}
2. {Concrete recommendation with rationale}

## Risks

- {Risk if recommendations are followed, and mitigation}
```

After all agents complete, verify each file exists at `{RESEARCH_DIR}/debate/round1/{PERSONA_SLUG}.md`.

### Round 2 — Cross-Examination & Devil's Advocate

The supervisor (orchestrator itself, acting as a foreground step) reads all Round 1 positions. Identifies:
- Top 3-5 **disagreements** — areas where personas reached different conclusions
- Top 2-3 **blind spots** — things only one persona mentioned that others overlooked
- For the Devil's Advocate specifically: the strongest consensus point to challenge

Then launch all team agents again in parallel (`run_in_background=true`) with a prompt containing:
- Their persona details
- All colleagues' Round 1 positions (concatenated)
- The identified disagreements and blind spots
- A specific devil's advocate challenge targeting THIS persona's Round 1 stance
- Tasks: respond to disagreements, defend or update position, engage with the devil's advocate challenge
- Output to `{RESEARCH_DIR}/debate/round2/{PERSONA_SLUG}.md`

Agent prompt template:

```
You are {PERSONA_NAME}, a specialist with the following profile:
- Background: {PERSONA_BACKGROUND}
- Perspective: {PERSONA_PERSPECTIVE}
- Priorities: {PERSONA_PRIORITIES}
- Debate style: {PERSONA_DEBATE_STYLE}

## Research Question

{RESEARCH_QUESTION}

## Your Round 1 Position

(Your Round 1 file content is included below for reference.)

{ROUND1_POSITION}

## Your Colleagues' Round 1 Positions

{CONCATENATED_ROUND1_POSITIONS_OF_ALL_OTHER_PERSONAS}

## Key Disagreements Identified by the Supervisor

{NUMBERED_LIST_OF_TOP_3_TO_5_DISAGREEMENTS}

## Blind Spots Identified

{NUMBERED_LIST_OF_BLIND_SPOTS}

## Devil's Advocate Challenge (for you specifically)

{TARGETED_CHALLENGE_ARGUING_AGAINST_THIS_PERSONAS_ROUND1_STANCE}

## Your Task

1. Respond to the key disagreements above. Do you hold your position or update it? Be specific.
2. Address the devil's advocate challenge directed at you. Rebut, concede, or refine your stance.
3. Respond to the blind spots — did you overlook something important?
4. Note if any colleague made an argument that genuinely changed your thinking (and explain how).
5. If you are updating your conclusions or recommendations, state the updated versions explicitly.

## Output

Write your response to: `{RESEARCH_DIR}/debate/round2/{PERSONA_SLUG}.md`

Use this format:

---
persona: {PERSONA_NAME}
round: 2
date: {TODAY_DATE}
---

# Round 2 — Cross-Examination: {PERSONA_NAME}

## Response to Disagreements

### Disagreement 1: {Topic}
{Your response — hold, concede, or refine}

### Disagreement 2: {Topic}
{Your response}

(continue for each disagreement)

## Response to Devil's Advocate Challenge

{Your rebuttal or concession}

## Blind Spots Addressed

- {What you missed and how it changes your analysis}

## Mind Changes

- {Conclusion or recommendation you updated, and why} (or "None — I hold my Round 1 position.")

## Updated Conclusions (if changed)

(List only if your conclusions changed from Round 1; otherwise write "Unchanged.")
```

### Round 3 — Supervisor Synthesis

A single foreground supervisor agent reads ALL Round 1 + Round 2 files and the original research files, then writes `{RESEARCH_DIR}/CONSENSUS.md`:

```markdown
# Research Consensus

**Question:** {RESEARCH_QUESTION}
**Date:** {date}
**Domain:** {RESEARCH_DOMAIN}
**Team:** {N} specialists, 2 debate rounds
**Mode:** {PROJECT_CONTEXTUAL|STANDALONE}
**Disagreements examined:** {N}

## Executive Summary

{3-5 sentences: the answer to the research question, confidence level, key caveats}

## Consensus Findings

### Finding 1: {Title}
- **Conclusion:** {what the team agrees on}
- **Confidence:** {High|Medium|Low}
- **Supporting personas:** {who agreed}
- **Evidence:** {key sources}

### Finding 2: {Title}
(same format)

(continue for all consensus findings)

## Contested Findings

### {Topic}
- **Position A:** {view} — supported by {personas}
- **Position B:** {view} — supported by {personas}
- **Resolution:** {supervisor's assessment of which position is stronger, and why}

## Key Uncertainties

- {What remains unknown, and what additional research would help}

## Recommendations

### Tier 1: High Confidence (act on these)
1. {Recommendation with rationale}
2. {Recommendation}

### Tier 2: Moderate Confidence (consider these)
1. {Recommendation}

### Tier 3: Speculative (investigate further)
1. {Recommendation}

## Devil's Advocate Summary

{What the Devil's Advocate challenged, what survived scrutiny, what didn't}

## Supervisor's Assessment

{Narrative synthesis: the answer to the research question, how confident we should be,
what would change the answer, and what to do next. Explicitly notes where the supervisor
overruled minority positions and why.}
```

Present a brief summary of the consensus to the user before proceeding.
