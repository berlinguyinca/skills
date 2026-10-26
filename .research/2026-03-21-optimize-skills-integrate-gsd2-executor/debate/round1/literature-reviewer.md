---
persona: Literature Reviewer
round: 1
date: 2026-03-21
---

# Round 1 -- Position Statement: Literature Reviewer

## Position

The evidence base for optimizing gw-skills and integrating GSD-2 as a plan executor is structurally strong but empirically thin. The Plan-then-Execute (P-t-E) architecture -- the pattern GSD-2 implements natively -- is the most replicated finding in the LLM agent literature of 2024-2026, with independent confirmation from at least three research groups (arXiv 2509.08646, 2601.01743, 2506.12508). This convergence across independent teams using different benchmarks elevates P-t-E from "promising pattern" to "established best practice." The structural alignment between GSD-2's milestone/slice/task decomposition and the academically validated P-t-E paradigm is not coincidental -- it reflects genuine engineering convergence on a pattern that works. This gives us reasonable confidence that GSD-2 can serve as an executor, but I must flag that GSD-2 itself has zero independent benchmark evaluations. We are trusting architectural alignment, not empirical validation.

On skill optimization, the literature points clearly toward two high-confidence interventions: progressive disclosure (reducing token overhead by loading full instructions only on activation) and selective persona engagement in multi-agent debate. The iMAD study (arXiv 2511.11306) is particularly important here because it quantifies what practitioners have long suspected -- that full multi-agent debate wastes 80-95% of its tokens on cases where a single agent would have reached the same answer. The gw:research skill's 37-persona debate is operating in completely uncharted empirical territory; no study has examined debate dynamics at that scale. Extrapolating from 2-6 agent studies to 37 agents carries substantial uncertainty, and the conformity/echo-chamber failure modes documented in the debate failure literature (arXiv 2509.05396) likely amplify at scale.

The most significant gap in the evidence base is the complete absence of peer-reviewed studies on Markdown-based skill systems. Despite Claude Code's skill ecosystem growing from 50 to over 85,000 skills in under a year, the optimization guidance available is entirely practitioner-derived. We have reverse-engineering analyses and blog posts, but no controlled experiments measuring how skill structure affects activation rates, execution quality, or token efficiency. This means every optimization recommendation for skill authoring carries a "practitioner consensus, not empirical proof" caveat. I urge caution against over-engineering the integration layer until we have at least internal benchmarks validating that the translation from gw-skills output to GSD-2 state files preserves plan fidelity.

## Top Conclusions

1. **Plan-then-Execute is the validated architecture for GSD-2 integration** (Confidence: H)
   - **Evidence:** Three independent research groups confirm P-t-E superiority over reactive (ReAct) patterns for multi-step, tool-heavy tasks (arXiv 2509.08646, 2601.01743, 2506.12508). GSD-2's milestone/slice/task pipeline is a direct implementation of this pattern. AgentOrchestra's two-tier hierarchy (95.3% SimpleQA, 82.42% GAIA) validates the planner-executor separation that a gw-skills-to-GSD-2 bridge would instantiate. The consensus across different benchmarks, teams, and implementation languages constitutes the strongest evidence cluster in this review.

2. **Selective persona engagement could reduce gw:research token costs by 60-90% without meaningful quality loss** (Confidence: H)
   - **Evidence:** iMAD (arXiv 2511.11306) demonstrates that beneficial debate outcomes occur in only 4.9-19.1% of cases, and intelligent triggering based on uncertainty signals achieves 2-13.5% accuracy improvement while cutting tokens by 62-92%. The debate failure literature (arXiv 2509.05396) documents conformity effects and echo chambers that degrade quality in 3.4-14% of cases. However, all studies use 2-6 agents; extrapolation to 37 personas is unvalidated, which is the sole reason this is not rated at the highest possible confidence.

3. **Progressive disclosure is the highest-leverage skill optimization** (Confidence: H)
   - **Evidence:** Reverse engineering of Claude Code internals shows optimized descriptions improve activation rates from 20% to 90% (leehanchung.github.io deep dive). The 15,000-character token budget constraint is a hard architectural limit. The skill-compilation study (arXiv 2601.04748) confirms that single-agent skill systems match multi-agent performance for sequential tasks when skill packaging is efficient. This is high-confidence because the mechanism (token budget limits) is deterministic, not probabilistic.

4. **Verification gates are architecturally mandatory, not optional enhancements** (Confidence: H)
   - **Evidence:** Every production-grade framework reviewed -- GSD-2, AgentOrchestra, and the agent systems survey's recommended control loop (arXiv 2601.01743) -- includes post-execution verification. GSD-2's verification command enforcement with auto-fix retries is the specific implementation pattern. The systematic review (2601.01743) establishes that "verifiers define operational meaning" -- without verification, tool outputs have no guaranteed semantics. No counter-evidence exists in the literature; this is the closest thing to a unanimous finding.

5. **The GSD-2 integration translation layer is an unquantified risk** (Confidence: M)
   - **Evidence:** No literature addresses the fidelity cost of translating between agent framework state formats. GSD-2's headless mode (`gsd headless [cmd]`, `gsd headless query`) provides the programmatic interface, and its `.gsd/` file-based state management is conceptually compatible with Markdown-based skill outputs. However, the plan decomposition semantics of gw-skills (research findings, design specs) and GSD-2 (mechanically-verifiable tasks with "iron rule" context constraints) are structurally different. The translation from "research recommendation" to "mechanically-verifiable task" is a non-trivial semantic transformation with no empirical guidance on error rates.

## Uncertainties

- **37-persona debate dynamics are entirely uncharacterized.** All multi-agent debate studies use 2-6 agents. The scaling behavior of conformity effects, echo chambers, and information aggregation at 37 agents is unknown. It is plausible that the marginal value of additional personas follows a steep diminishing-returns curve, but we have no data to locate the inflection point.

- **Markdown skill optimization lacks controlled experiments.** The 20%-to-90% activation rate improvement from optimized descriptions is a single practitioner's observation, not a controlled study. We do not know whether this finding replicates across different skill types, complexity levels, or user populations.

- **GSD-2's crash recovery claims are unverified.** The lock-file-based crash recovery and session forensics are documented features, but no independent testing or stress-testing results exist. For long-running plan executions (the primary integration use case), reliability under failure conditions is critical and untested.

- **Optimal autonomy level for the integrated system is context-dependent.** GSD-2 advocates "walk away" full autonomy, while the agent systems survey emphasizes human-in-the-loop verification for high-stakes operations. The literature has not converged on decision criteria for choosing between these modes.

- **PromptAgent-style automated optimization for skill instructions is theoretically promising but empirically untested for complex, multi-step agent instructions.** MCTS-based prompt optimization (ICLR 2024) has been validated only for task-specific prompts, not for the kind of rich procedural instructions found in gw-skills SKILL.md files.

## Recommendations

1. **Implement a `gw:execute` bridge skill as a minimal viable integration.** This skill should translate gw-skills plan outputs into GSD-2's `.gsd/PROJECT.md` and `.gsd/ROADMAP.md` format, invoke `gsd headless auto`, and monitor via `gsd headless query`. Start with a single, well-defined plan type (e.g., implementation plans from gw:design) rather than attempting to handle all skill outputs simultaneously. Measure translation fidelity before scaling.

2. **Add uncertainty-based triggering to gw:research persona dispatch.** Before engaging all 37 personas, run a lightweight pre-assessment to classify the question's domain complexity and identify which persona clusters are relevant. This is the single highest-ROI optimization available, with strong evidence supporting 60-90% token reduction. Implement in phases: first measure current per-persona token usage and contribution quality, then introduce selective engagement.

3. **Restructure all gw-skills for progressive disclosure.** Audit every SKILL.md file against the 15,000-character budget. Move detailed instructions, reference materials, and scripts into subdirectories (scripts/, references/, assets/). Ensure the skill description surfaces only trigger metadata and a concise capability summary. This is a low-risk, high-confidence optimization with a deterministic mechanism.

4. **Add verification gates to every artifact-producing skill.** Before any skill declares completion, it should validate: (a) output format conformance, (b) all claimed tool invocations actually executed, and (c) output does not contain hallucinated references or citations. Model this on GSD-2's verification command enforcement pattern.

5. **Establish internal benchmarks before optimizing further.** The literature gap is severe -- we have no empirical baselines for skill activation rates, execution quality, or token efficiency in the current system. Before implementing optimizations, measure the current state. Without baselines, we cannot distinguish real improvements from noise.

## Risks

- **Over-engineering the integration layer.** The temptation to build a comprehensive gw-skills-to-GSD-2 bridge covering all plan types simultaneously is high. The absence of empirical data on translation fidelity means a large upfront investment could produce a brittle system. A minimal, single-plan-type prototype is the evidence-appropriate approach.

- **Conformity amplification at 37-persona scale.** Reducing persona count (via selective engagement) is recommended on token-efficiency grounds, but it also mitigates an under-appreciated quality risk. The debate failure literature shows that larger agent groups can amplify incorrect consensus through social proof dynamics. Running 37 personas without selective filtering may be actively degrading output quality in some cases, not just wasting tokens.

- **GSD-2 version coupling.** Integrating tightly with GSD-2's `.gsd/` state format and headless CLI creates a dependency on a tool with no stability guarantees, no semantic versioning commitment visible in the repository, and no independent maintenance community. Breaking changes in GSD-2 would cascade into the integration layer.

- **Losing the "fresh context" advantage.** GSD-2's "iron rule" (one task per 200k-token context window) is architecturally sound, but if the translation from gw-skills plans produces tasks that are too coarse-grained, execution quality will degrade. The plan translator must respect GSD-2's context constraints, which requires understanding both the source semantics (gw-skills) and the target constraints (GSD-2) -- a non-trivial design challenge.

- **Premature optimization of skill instructions.** Applying PromptAgent-style automated optimization to SKILL.md files sounds appealing but is untested for complex procedural instructions. Automated optimization could produce instructions that score well on proxy metrics while degrading real-world skill behavior in ways that are hard to detect without comprehensive integration tests.
