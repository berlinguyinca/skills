---
persona: Literature Reviewer
question: How can gw-skills be optimized and how to integrate gsd-2 as plan executor
domain: engineering
date: 2026-03-21
depth: lightweight
sources_count: 12
---

# Research Findings: Literature Reviewer

## Executive Summary

Academic literature from 2024-2026 converges on three themes directly relevant to gw-skills optimization: (1) the Plan-then-Execute (P-t-E) architecture is the dominant pattern for reliable LLM agent systems, and GSD-2 already implements this pattern natively; (2) skill-based single-agent systems can match multi-agent performance while reducing token overhead by 60-90%; and (3) multi-agent debate improves reasoning quality but requires intelligent triggering to avoid wasteful token consumption. GSD-2's architecture -- with its milestone/slice/task decomposition, fresh context windows per task, and headless execution mode -- is structurally well-suited to serve as a plan executor for gw-skills research and design outputs.

## Key Findings

### Finding 1: Plan-then-Execute Is the Dominant Reliable Agent Architecture

The P-t-E pattern -- where a planner produces a complete structured plan before any execution begins -- consistently outperforms reactive (ReAct) patterns for multi-step tasks. The executor receives individual steps and invokes tools to accomplish subtasks. Critically, the executor can be a simpler, cheaper component than the planner, enabling cost-effective scaling. This pattern maps directly to GSD-2's architecture: the planning phase scouts the codebase and decomposes work into mechanically-verifiable tasks, while execution runs each task in a fresh context window with pre-inlined files.

- **Source:** https://arxiv.org/abs/2509.08646 (Architecting Resilient LLM Agents: A Guide to Secure Plan-and-Execute Systems)
- **Confidence:** High

### Finding 2: GSD-2 Implements a Mature Plan-Execute-Verify Pipeline

GSD-2 (https://github.com/gsd-build/gsd-2) is a TypeScript-based CLI built on the Pi SDK that decomposes projects into Milestones > Slices > Tasks, where each task must fit within one 200k-token context window (the "iron rule"). Its execution pipeline flows: Plan (with research) > Execute (per task) > Complete > Reassess Roadmap > Next Slice > Validate Milestone. Key integration-relevant features include: headless mode for CI/cron automation (`gsd headless [cmd]`), JSON state queries (`gsd headless query`), file-based state management in `.gsd/` directories, git worktree isolation per milestone, crash recovery with session forensics, and verification command enforcement with auto-fix retries.

- **Source:** https://github.com/gsd-build/gsd-2
- **Confidence:** High

### Finding 3: Skill-Based Single Agents Can Replace Multi-Agent Systems for Sequential Tasks

A January 2026 study demonstrates that compiling multi-agent systems into single-agent skill libraries reduces communication overhead, cutting latency and token usage substantially. The key condition: tasks that decompose into sequential or semi-independent subtasks are well-served by skill-based single agents. Multi-agent architectures remain preferable only when genuine parallelization across specialized domains is needed or real-time inter-agent negotiation directly impacts outcomes. This finding validates gw-skills' approach of packaging capabilities as modular Markdown instructions consumed by a single Claude Code agent.

- **Source:** https://arxiv.org/pdf/2601.04748 (When Single-Agent with Skills Replace Multi-Agent Systems and When They Fail)
- **Confidence:** Medium (preprint, not yet peer-reviewed at a top venue)

### Finding 4: Hierarchical Multi-Agent Frameworks Excel at Complex Decomposition

AgentOrchestra achieved state-of-the-art results (95.3% on SimpleQA, 82.42% on GAIA) using a two-tier hierarchy where a planning agent decomposes tasks and delegates to specialized sub-agents (Deep Researcher, Browser Use, Deep Analyzer). The framework maintains a global perspective, aggregating feedback and monitoring progress. This pattern aligns with how gw:research dispatches 37 personas for multi-agent investigation -- the hierarchical coordination with role specialization is academically validated as superior to flat architectures.

- **Source:** https://arxiv.org/html/2506.12508v1 (AgentOrchestra: A Hierarchical Multi-Agent Framework)
- **Confidence:** High

### Finding 5: Intelligent Multi-Agent Debate Reduces Token Waste by Up to 92%

iMAD (Intelligent Multi-Agent Debate) demonstrates that full-debate systems consume 3-5x more tokens than single-agent approaches while providing only 1.5-5.3% accuracy gains. Beneficial debate outcomes occur in only 4.9-19.1% of cases. iMAD's selective triggering -- debating only when uncertainty signals warrant it -- achieves 2-13.5% accuracy improvements while reducing token usage by 62-92%. This has direct implications for gw:research's 37-persona debate: selective engagement based on uncertainty detection would dramatically reduce cost while preserving quality.

- **Source:** https://arxiv.org/html/2511.11306v1 (iMAD: Intelligent Multi-Agent Debate for Efficient and Accurate LLM Inference)
- **Confidence:** High

### Finding 6: Progressive Disclosure Is the Key Skill Optimization Strategy

Analysis of Claude Code's skill architecture reveals that skills are prompt-based context modifiers using dynamic prompt injection. Optimized descriptions improve activation rates from 20% to 90%. The critical optimization principle is progressive disclosure: showing minimal metadata initially, revealing full instructions only after selection. Token budget limits skill descriptions to approximately 15,000 characters. Supporting resources should be organized in separate directories (scripts/, references/, assets/) rather than embedded in SKILL.md.

- **Source:** https://leehanchung.github.io/blogs/2025/10/26/claude-skills-deep-dive/
- **Confidence:** High (first-principles reverse engineering of Claude Code internals)

### Finding 7: Comprehensive Agent Systems Require Verification-as-Semantics

A systematic review of AI agent architectures (2601.01743) establishes that tool correctness is not optional -- verifiers define operational meaning by checking outputs before downstream actions. The recommended minimal control loop is: retrieve context > plan > act via tools > verify > update memory > repeat. Planning must be separated from execution with permission gating. This validates GSD-2's verification command enforcement and auto-fix retry mechanism as architecturally sound, and suggests gw-skills should adopt similar verification gates.

- **Source:** https://arxiv.org/html/2601.01743v1 (AI Agent Systems: Architectures, Applications, and Evaluation)
- **Confidence:** High

### Finding 8: Prompt Optimization via Search Achieves Expert-Level Quality

PromptAgent (ICLR 2024) uses Monte Carlo Tree Search to automatically discover expert-level prompts, consistently outperforming handcrafted baselines across 12 tasks. The method treats prompt optimization as strategic planning through the space of possible instructions. This suggests gw-skills' Markdown instructions could benefit from systematic optimization rather than manual iteration -- particularly the preamble and shared instruction files that are consumed across multiple skills.

- **Source:** https://openreview.net/forum?id=22pyNMuIoa (PromptAgent: Strategic Planning with Language Models Enables Expert-level Prompt Optimization, ICLR 2024)
- **Confidence:** High (peer-reviewed at top venue)

## Areas of Consensus

1. **Plan-then-Execute superiority**: Multiple independent research groups confirm P-t-E architectures outperform reactive patterns for multi-step, tool-heavy tasks. This is the strongest consensus finding (sources: 2509.08646, 2601.01743, 2506.12508).

2. **Modular decomposition**: All surveyed frameworks -- GSD-2, AgentOrchestra, the Agent Transformer abstraction -- converge on hierarchical task decomposition as essential for managing complexity.

3. **Fresh context per unit**: Both GSD-2's "iron rule" (one task per context window) and the academic literature's emphasis on context management independently arrive at the same conclusion: accumulated context degrades performance.

4. **Verification gates are mandatory**: Every production-grade framework reviewed includes post-execution verification. This is not a nice-to-have -- it is architecturally fundamental.

5. **Skill-based architectures are viable**: Both Claude Code's skill ecosystem growth (50 to 85,000+ skills in under a year) and academic research validate modular instruction packaging as an effective agent augmentation strategy.

## Areas of Disagreement

1. **Single-agent vs. multi-agent**: The literature is split. The skill-compilation paper (2601.04748) argues single agents with skills suffice for most tasks, while AgentOrchestra (2506.12508) demonstrates multi-agent superiority on complex benchmarks. The resolution likely depends on task complexity and parallelizability.

2. **Debate utility**: Standard multi-agent debate papers (2305.14325) claim broad benefits, while iMAD (2511.11306) and failure-mode analyses (2509.05396) show debate is harmful in 3.4-14% of cases due to conformity effects and echo chambers. The field has not converged on when debate helps vs. hurts.

3. **Autonomy level**: GSD-2 advocates "walk away" full autonomy with crash recovery, while the agent systems survey (2601.01743) emphasizes human-in-the-loop verification for high-stakes operations. The optimal autonomy level remains context-dependent.

## Practical Implications

### For gw-skills Optimization

1. **Adopt progressive disclosure in all skills**: Restructure SKILL.md files to provide minimal trigger metadata upfront, with detailed instructions loaded only on activation. Keep descriptions under 15,000 characters.

2. **Implement selective persona engagement in gw:research**: Rather than running all 37 personas, use uncertainty-based triggering (per iMAD) to engage only relevant personas. This could reduce token costs by 60-90% while maintaining quality.

3. **Add verification gates to skill outputs**: Every skill that produces artifacts (code, plans, reports) should include a verification step before completion -- validating output format, checking for hallucinations, and confirming tool calls were actually executed.

4. **Optimize shared preamble and instruction files**: The _shared/ directory files (preamble.md, team-assembly.md, branch-first.md, etc.) are consumed across multiple skills and represent high-leverage optimization targets. Consider automated prompt optimization techniques (per PromptAgent).

5. **Structure skills for context efficiency**: Separate reference materials from core instructions. Use directory-based resource organization (scripts/, references/) to enable selective loading.

### For GSD-2 Integration as Plan Executor

1. **Bridge via headless mode**: GSD-2's `gsd headless [cmd]` provides the programmatic interface needed. A gw-skill could generate a `.gsd/PROJECT.md` and `.gsd/ROADMAP.md`, then invoke `gsd headless auto` to execute the plan autonomously.

2. **Use JSON state queries for monitoring**: `gsd headless query` returns instant JSON snapshots of state, next dispatch, and costs -- ideal for a gw-skill to monitor execution progress without spawning an LLM session.

3. **Map gw:research output to GSD-2 roadmap format**: Research findings from the 37-persona debate could be converted into GSD-2's milestone/slice/task hierarchy, with each research recommendation becoming a mechanically-verifiable task.

4. **Leverage git worktree isolation**: GSD-2's per-milestone worktree strategy prevents cross-contamination between execution units. A gw:worktree skill already exists and could be aligned with GSD-2's branch strategy.

5. **Exploit crash recovery**: GSD-2's lock-file-based crash recovery and session forensics mean long-running plan executions can survive interruptions -- important for complex multi-skill workflows.

6. **Consider a `gw:execute` skill**: Create a new skill that translates gw-skills plan outputs (from gw:research, design specs, implementation plans) into GSD-2 `.gsd/` state files and triggers headless execution, with status monitoring and result collection.

## Knowledge Gaps

1. **No empirical studies on Markdown-based skill systems**: Despite 85,000+ Claude Code skills in the wild, there are zero peer-reviewed studies measuring the effectiveness of different skill authoring patterns. All optimization guidance is based on practitioner experience, not controlled experiments.

2. **GSD-2 lacks academic validation**: While architecturally sound and aligned with P-t-E best practices, GSD-2 has not been evaluated against academic benchmarks (SWE-bench, WebArena, etc.). Its crash recovery and autonomous execution claims lack independent verification.

3. **Multi-agent debate scaling**: Research on debate with 37 personas (as in gw:research) does not exist. Studies typically use 2-6 agents. The dynamics of conformity, echo chambers, and token waste at 37-agent scale are entirely uncharacterized.

4. **Integration overhead**: No literature addresses the cost of translating between different agent framework state formats (e.g., gw-skills Markdown plans to GSD-2 `.gsd/` state files). The overhead of this translation layer is unknown.

5. **Long-horizon skill chaining**: Academic work focuses on single-task or short-chain execution. The pattern of research > design > plan > execute across multiple skills over hours or days lacks empirical study.

6. **Prompt optimization for agent instructions**: PromptAgent optimizes task-specific prompts, but whether MCTS-based optimization works for complex, multi-step agent instructions (like skill files) has not been tested.

## Sources

| # | Title | URL | Type | Retrieved |
|---|-------|-----|------|-----------|
| 1 | GSD-2: Autonomous Agent Development System | https://github.com/gsd-build/gsd-2 | GitHub Repository | 2026-03-21 |
| 2 | Architecting Resilient LLM Agents: Secure Plan-and-Execute | https://arxiv.org/abs/2509.08646 | arXiv preprint | 2026-03-21 |
| 3 | AgentOrchestra: Hierarchical Multi-Agent Framework | https://arxiv.org/html/2506.12508v1 | arXiv preprint | 2026-03-21 |
| 4 | When Single-Agent with Skills Replace Multi-Agent Systems | https://arxiv.org/pdf/2601.04748 | arXiv preprint | 2026-03-21 |
| 5 | iMAD: Intelligent Multi-Agent Debate | https://arxiv.org/html/2511.11306v1 | arXiv preprint | 2026-03-21 |
| 6 | AI Agent Systems: Architectures, Applications, and Evaluation | https://arxiv.org/html/2601.01743v1 | arXiv preprint | 2026-03-21 |
| 7 | PromptAgent: Strategic Planning for Expert-level Prompt Optimization | https://openreview.net/forum?id=22pyNMuIoa | ICLR 2024 (peer-reviewed) | 2026-03-21 |
| 8 | Claude Agent Skills: A First Principles Deep Dive | https://leehanchung.github.io/blogs/2025/10/26/claude-skills-deep-dive/ | Technical blog | 2026-03-21 |
| 9 | Improving Factuality and Reasoning through Multiagent Debate | https://arxiv.org/abs/2305.14325 | arXiv preprint | 2026-03-21 |
| 10 | Difficulty-Aware Agent Orchestration in LLM-Powered Workflows | https://arxiv.org/html/2509.11079v1 | arXiv preprint | 2026-03-21 |
| 11 | Gradientsys: Multi-Agent LLM Scheduler with ReAct Orchestration | https://arxiv.org/html/2507.06520v1 | arXiv preprint | 2026-03-21 |
| 12 | Talk Isn't Always Cheap: Failure Modes in Multi-Agent Debate | https://arxiv.org/pdf/2509.05396 | arXiv preprint | 2026-03-21 |
