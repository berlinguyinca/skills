# Research Consensus

**Question:** How can gw-skills be optimized, and how to integrate GSD-2 as a plan executor?
**Date:** 2026-03-21
**Domain:** engineering
**Team:** 5 specialists, 2 debate rounds
**Mode:** PROJECT_CONTEXTUAL
**Disagreements examined:** 5

## Executive Summary

gw-skills should be optimized through three high-confidence interventions: (1) decompose the six oversized skill files (saas-idea at 2,117 lines, research at 1,192, compete at 971, review-app at 937, weekly-review at 869, audit-repo at 804) below the 500-line threshold using the existing `_shared/` pattern; (2) fix the preamble's GSD detection to recognize GSD-2's `.gsd/STATE.md` alongside GSD v1's `.planning/config.json`; and (3) rewrite skill descriptions with "USE WHEN" trigger patterns. GSD-2 integration should be approached as a **migration** of 47 existing GSD v1 references across 6 skills into a centralized `gw:gsd` bridge skill, using a Strategy pattern for per-skill customization. Autonomous execution via `gsd headless auto` must be gated behind the resolution of GSD-2's subagent instruction passthrough issue (executors do not receive CLAUDE.md). Confidence is High for optimization recommendations and Medium for GSD-2 integration.

## Consensus Findings

### Finding 1: Skill file decomposition is the highest-ROI immediate optimization
- **Conclusion:** Six of twelve skill files exceed the 500-line recommended maximum. Decomposing them using the proven `_shared/` pattern is the safest, highest-impact optimization available.
- **Confidence:** High
- **Supporting personas:** Software Architect, Backend Engineer, Literature Reviewer, Devil's Advocate, Domain Expert (unanimous)
- **Evidence:** Codebase line counts confirmed independently by SA, BE, and DE. Anthropic's official skill authoring best practices recommend <500 lines. The `_shared/` module pattern (7 existing modules, 370 lines total) demonstrates the decomposition approach works.
- **Caveat (DA):** Risk is low but not zero. An extraction taxonomy is needed: format templates and data tables are safe to extract; decision-shaping instructions and hard constraints should remain inline or be loaded at decision points.

### Finding 2: GSD-2 integration is a migration, not greenfield
- **Conclusion:** 47 GSD v1 references exist across 6 skills. The preamble already detects `.planning/config.json`. This is existing coupling that is broken for GSD-2 users, not new architecture.
- **Confidence:** High
- **Supporting personas:** Domain Expert (discovered), Software Architect (adopted R2), Backend Engineer (adopted R2), Literature Reviewer (adopted R2), Devil's Advocate (conceded R2)
- **Evidence:** DE audited all 12 skill files and counted 47 GSD-related references. Six skills offer `[g] GSD` output actions. `saas-idea` has a full Phase 5 autonomous execution pipeline.

### Finding 3: A centralized `gw:gsd` bridge skill using the Strategy pattern is the right integration architecture
- **Conclusion:** Build a single bridge skill that owns the GSD-2 protocol (detection, brownfield/greenfield routing, plan translation, invocation, error handling). Per-skill customization expressed as configuration payloads (source artifact path, phase mapping, context metadata). Excludes `saas-idea` Phase 5 auto-chain.
- **Confidence:** Medium-High
- **Supporting personas:** Domain Expert (proposed), Software Architect (adopted), Backend Engineer (adopted), Literature Reviewer (adopted)
- **Evidence:** The 5-step protocol (check GSD installation, detect brownfield/greenfield, invoke, handle errors, degrade gracefully) is identical across all 5 shallow integrations. Per-skill variance is limited to source artifact format and phase mapping semantics.

### Finding 4: GSD-2 autonomous execution is blocked by the subagent instruction passthrough gap
- **Conclusion:** GSD-2 executor agents do not inherit project-level CLAUDE.md instructions. This means gw-skills instructions would not reach the agents writing code. Plan generation (materializing instructions into plan artifacts) can proceed. Autonomous execution (`gsd headless auto`) must be gated.
- **Confidence:** High
- **Supporting personas:** Devil's Advocate (discovered), Software Architect (conceded R2), Literature Reviewer (upgraded to blocker R2), Domain Expert (partially conceded — blocked saas-idea Phase 5)
- **Evidence:** Documented GSD-2 issue where a 6-phase project produced code review findings that would have been prevented if executors had followed CLAUDE.md. Backend Engineer argues the plan-generation adapter sidesteps this because instructions are materialized into the plan itself.

### Finding 5: Budget enforcement is missing critical infrastructure
- **Conclusion:** No current gw-skill implements step count limits, cost caps, or runtime limits for parallel subagent dispatch. This must be addressed before any autonomous execution path.
- **Confidence:** High
- **Supporting personas:** Backend Engineer (discovered), Software Architect (adopted R2), Domain Expert (acknowledged)
- **Evidence:** Research Step 4 and review-app Step 2 launch N parallel agents with no ceiling on token consumption. GSD-2's budget ceilings provide a pattern but have a known metering bug (#1943, 35% cost inflation).

### Finding 6: Selective persona engagement is directionally correct but needs measurement
- **Conclusion:** The iMAD study shows beneficial debate occurs in only 4.9-19.1% of cases with 2-6 agents, suggesting massive token waste in full debate. However, gw-skills already implement team selection (typically 5 personas per run, not all 37). The optimization opportunity is uncertainty-based debate triggering: skip debate entirely for low-uncertainty questions.
- **Confidence:** Medium
- **Supporting personas:** Literature Reviewer (proposed), Domain Expert (adopted R2), Devil's Advocate (correctly noted team-assembly already selects subsets)
- **Evidence:** iMAD (arXiv 2511.11306) shows 62-92% token reduction. However, extrapolation from 2-6 agents to larger teams crosses a complexity boundary (pairwise interactions scale from O(15) to O(666)). The DA correctly identified that the 37-persona number is the roster, not the per-run dispatch count.

## Contested Findings

### Whether bridge work should proceed before empirical validation of the subagent instruction gap
- **Position A:** Proceed with plan-generation bridge (plan-handoff mode only, no autonomous execution) — supported by SA, BE, DE, LR
- **Position B:** Block all bridge work until the instruction gap is empirically tested — supported by DA
- **Resolution:** The supervisor sides with Position A with a modification: the bridge skill should be built in supervised mode (plan generation only), but a 2-hour empirical test of the instruction gap should run in parallel. If the test reveals that plan-materialized instructions are also lost, the bridge is blocked. This gives the DA's concern its due diligence without serializing all work behind it.

### Context window saturation risk
- **Position A:** Context saturation is a theoretical concern that should not block work — implied by SA, BE, DE
- **Position B:** Measure combined token payload before building anything — DA (strongly advocated)
- **Resolution:** The DA is correct that no one measured the actual token payload. This measurement should be a Week 1 task (30 minutes of effort) that runs in parallel with decomposition work. It does not block decomposition (which reduces the payload) but should gate the bridge skill.

### Optimal autonomy level for GSD-2 execution
- **Position A:** Gate autonomy behind specific conditions (instruction passthrough fix, proof-of-concept, budget enforcement, kill criteria) — SA, BE, DE
- **Position B:** Do not trust autonomous mode at all given 54+ bugs and silent data loss history — DA
- **Resolution:** The supervisor sides with Position A. GSD-2's bug history reflects active development, not fundamental unreliability. However, the gate conditions are non-negotiable and include the DA's excellent recommendation to define kill criteria upfront.

## Key Uncertainties

- **GSD-2 plan format schema stability:** The exact `.gsd/ROADMAP.md` structure is not documented as a stable API. Breaking changes could invalidate the bridge. Mitigation: pin to a known version, centralize all format assumptions.
- **Token budget at scale:** Whether 10+ gw-skills descriptions collectively approach the 2% context window budget has not been measured. Whether adding GSD-2 state files pushes past degradation thresholds is unknown.
- **37-persona debate dynamics:** No study has examined multi-agent debate at this scale. Conformity effects and echo chambers may amplify. The team-assembly module already mitigates by selecting 5 personas per run.
- **`.claude/commands/` to `.claude/skills/` migration:** Unlocks `context: fork`, dynamic context injection (`!command`), and model overrides, but is blocked by the symlink install mechanism and `gw:` prefix mandate. Breaking-change risk is non-trivial.

## Recommendations

### Tier 1: High Confidence (act on these)

1. **Decompose the six oversized skill files.** Extract format templates, data/reference tables, and phase-specific execution instructions into `_shared/` or skill-specific reference files. Keep decision-shaping instructions and hard constraints inline. Target: every skill under 500 lines. Start with `saas-idea.md` (2,117 lines). Estimated effort: 1-2 weeks.

2. **Fix preamble GSD detection for v2.** Add `.gsd/STATE.md` detection alongside `.planning/config.json`. Version-aware: check GSD-2 first, fall back to v1. This is a 5-10 line change with zero risk. Estimated effort: 30 minutes.

3. **Rewrite all skill descriptions with "USE WHEN" trigger patterns.** Add explicit activation triggers to every skill's YAML description. Format: `"<capability>. Use when <trigger1>, <trigger2>, <trigger3>."` Estimated effort: 2-3 hours.

4. **Measure context window token payload.** Load a representative skill invocation (saas-idea with full context) and measure remaining usable tokens. This establishes the baseline for all optimization and integration decisions. Estimated effort: 30 minutes.

### Tier 2: Moderate Confidence (consider these)

5. **Build `gw:gsd` bridge skill in supervised mode.** Strategy pattern: bridge owns the GSD-2 protocol, skills provide configuration payloads. Replaces `[g] GSD` action in 5 skills (excludes saas-idea Phase 5). Supervised mode only — no autonomous execution. Estimated effort: 1-2 weeks.

6. **Add budget enforcement via `_shared/budget-guard.md`.** Hard caps: max subagent count (default 10), per-agent timeout (default 5 min), per-skill timeout (default 30 min). Prerequisite for any autonomous execution path. Estimated effort: 3-5 days.

7. **Instrument gw:research for per-persona token measurement.** Log per-persona token consumption and contribution quality (does output appear in consensus?). Run 5-10 representative tasks to establish baseline. Use data to design uncertainty-based debate triggering. Estimated effort: 1 week.

### Tier 3: Speculative (investigate further)

8. **Evaluate `.claude/skills/` directory migration.** Prototype in a branch. Test `/gw:` prefix compatibility with skills directory. Measure preamble tool call savings from dynamic context injection. Ship only when breaking-change risk is fully characterized.

9. **GSD-2 autonomous execution (gated).** Only proceed if: (a) subagent instruction passthrough is fixed or mitigated, (b) proof-of-concept achieves >80% task completion, (c) budget enforcement is operational, (d) kill criteria are defined. If any gate fails, defer indefinitely.

10. **Uncertainty-based debate triggering for gw:research.** After measurement baseline exists (Tier 2 item 7), implement a lightweight pre-assessment that classifies question complexity and skips debate for low-uncertainty questions. Conservative threshold with fallback to full debate.

## Devil's Advocate Summary

The Devil's Advocate was the most influential voice in this debate, forcing three significant concessions:

1. **Subagent instruction gap elevated from risk to blocker.** The DA's finding that GSD-2 executors don't receive CLAUDE.md caused the SA, LR, and DE to gate autonomous execution. The SA split the integration into Phase A (plan generation, unblocked) and Phase B (autonomous execution, gated). This was the debate's most consequential shift.

2. **"Zero risk" decomposition claim challenged.** The DA's extraction taxonomy (decision-shaping instructions vs. format templates) survived scrutiny and was adopted by the group. While decomposition consensus held, the DA's insistence on specificity improved the recommendation quality.

3. **iMAD extrapolation corrected.** The DA challenged the LR's 60-90% savings claim as an unvalidated extrapolation across a complexity boundary (6 agents to 37). The LR conceded and corrected the recommendation to "measure first, then optimize." The DA also correctly identified that team-assembly already selects subsets, partially mitigating the concern.

**What the DA challenged that did NOT survive:** The DA's recommendation to block ALL GSD-2 integration (including plan generation) until the instruction gap is tested was overruled. Four personas argued that plan-generation materializes instructions into the plan artifact itself, sidestepping the passthrough issue. The DA could not demonstrate that the plan-generation adapter pattern specifically is affected by the gap. The supervisor concurs: plan generation can proceed while the instruction gap is tested in parallel.

## Supervisor's Assessment

The answer to the research question has two parts:

**On optimization:** The gw-skills system has grown organically past its structural boundaries. The six oversized skill files are the primary bottleneck — not because they prevent functionality, but because they degrade instruction-following quality and consume disproportionate context window budget. The optimization path is clear, low-risk, and unanimously supported: decompose using the existing `_shared/` pattern, fix the broken GSD detection, and improve skill descriptions. These are maintenance tasks, not feature work, and should be prioritized as such.

**On GSD-2 integration:** This is fundamentally a migration from GSD v1 (slash commands in Claude Code's conversation context) to GSD-2 (standalone CLI with its own state machine). The 47 existing GSD v1 references are already broken for GSD-2 users. A centralized bridge skill using the Strategy pattern is the right architecture, and plan-generation mode can proceed safely. However, autonomous execution faces a structural blocker (subagent instruction passthrough) and an operational gap (no budget enforcement). These must be resolved before autonomous execution is viable. The recommended sequencing is: optimize first (Tier 1), build the supervised bridge (Tier 2), then gate autonomous execution behind falsifiable conditions (Tier 3).

The supervisor overruled the Devil's Advocate's recommendation to block all integration work, because the migration must happen regardless — the existing GSD v1 references are broken today. However, the supervisor adopted the DA's gate conditions for autonomous execution and the DA's recommendation to define kill criteria upfront. The DA's most valuable contribution was elevating the subagent instruction gap from a footnote to a blocking concern, which fundamentally reshaped the integration timeline.

Confidence: **High** for optimization, **Medium** for integration. The gap between these reflects the difference between optimizing a system we control (gw-skills) and integrating with a system we don't (GSD-2).
