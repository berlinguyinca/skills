---
persona: Devil's Advocate
question: How can gw-skills be optimized and how to integrate gsd-2 as plan executor
domain: engineering
date: 2026-03-21
depth: lightweight
sources_count: 12
---

# Research Findings: Devil's Advocate

## Executive Summary

Integrating GSD-2 as a plan executor for gw-skills introduces significant risks around context bloat, cascading failure propagation, state corruption, and architectural coupling to a tool with 54+ open bugs including data loss issues. The optimization of gw-skills faces a fundamental tension: adding more skills and capabilities increases the very context window overhead that degrades agent performance, while multi-agent orchestration compounds individual error rates exponentially rather than linearly.

## Key Findings

### Finding 1: GSD-2 Has Active Data Loss and State Corruption Bugs

GSD-2's GitHub issue tracker shows 54+ open issues as of March 2026, with multiple critical bugs involving data loss, dirty state propagation, and merge failures. Issue #1985 documents milestone merge failures when `syncWorktreeStateBack` dirties tracked `.gsd/` root files before squash merge. Issue #1944 shows step-mode loop exits leaving dirty session state that blocks subsequent `/gsd auto` runs. Issue #1943 reveals the idle watchdog creates duplicate metrics entries, inflating reported costs by 35%. Issue #1935 shows `cleanupQuickBranch` is never called, leaving orphaned branches. The v2.41.0 release itself was a batch of 70+ fixes addressing "silent data loss in auto-mode," including hallucination guards for agents completing with zero tool calls and empty merge guards for unanchored changes -- suggesting these failure modes were discovered in production.

- **Source:** https://github.com/gsd-build/gsd-2/issues
- **Confidence:** High

### Finding 2: Context Window Bloat Is a Structural Risk for Skill-Heavy Systems

Research from Anthropic and independent benchmarks shows that tool definitions alone can consume 55,000-134,000 tokens (27-67% of a 200K context window) before any work begins. Scalekit benchmarks found MCP costing 4-32x more tokens than CLI alternatives for identical operations. For gw-skills with 8+ skills and 37 personas, every additional skill file loaded into context directly reduces the agent's working memory for actual task execution. One documented case showed three MCP servers consuming 143,000 of 200,000 tokens, leaving only 57K for conversation and reasoning. The gw-skills approach of Markdown instruction files works today at small scale, but adding GSD-2 integration instructions, persona definitions, and execution plan context will push toward these documented limits.

- **Source:** https://agenteer.com/blog/the-two-context-bloat-problems-every-ai-agent-builder-must-understand/
- **Source:** https://www.apideck.com/blog/mcp-server-eating-context-window-cli-alternative
- **Confidence:** High

### Finding 3: Multi-Agent Error Compounding Makes Reliability Exponentially Harder

If an AI agent achieves 85% accuracy per action, a 10-step workflow only succeeds approximately 20% of the time due to error compounding. Even at 98% per-agent success, overall system success degrades to 90% or lower in multi-agent pipelines. The "17x error trap" describes how poorly structured multi-agent systems experience multiplicative error growth. Galileo AI research found that cascading failures propagate through agent networks faster than incident response can contain them, with a single compromised agent poisoning 87% of downstream decision-making within 4 hours. For gw-skills + GSD-2, every handoff between the skill layer and the execution layer is a compounding error boundary.

- **Source:** https://towardsdatascience.com/why-your-multi-agent-system-is-failing-escaping-the-17x-error-trap-of-the-bag-of-agents/
- **Source:** https://galileo.ai/blog/multi-agent-ai-failures-prevention
- **Confidence:** High

### Finding 4: GSD-2 Subagents Do Not Inherit Project Instructions -- A Critical Architecture Gap

A documented GSD-2 issue reveals that subagents (gsd-executor, gsd-planner, gsd-phase-researcher) do not receive project-level instructions from CLAUDE.md. After a 6-phase project, code review found security issues and quality gaps that would have been prevented if executor agents had followed project instructions. The orchestrator passes only GSD framework files to subagents, completely missing project-specific configuration. Subagents also cannot discover `.agents/skills/` directories. This means gw-skills instructions would likely NOT be visible to GSD-2's execution agents, rendering the integration partially or wholly ineffective at the point where it matters most -- actual code generation.

- **Source:** https://github.com/gsd-build/gsd-2/issues (Issue #671 referenced in search results)
- **Confidence:** High

### Finding 5: The "Dumb RAG" and "Brittle Connector" Failure Modes Apply to Skill Integration

Composio's 2026 AI Agent Report identifies three root causes of agent pilot failures: Dumb RAG (overwhelming context with irrelevant information), Brittle Connectors (naive API integrations that break on edge cases), and Polling Tax (architectural mismatch). The gw-skills + GSD-2 integration risks the first two: loading all skill definitions when only a subset is needed (Dumb RAG equivalent), and relying on file-based IPC and slash commands that may break across version updates or environment differences (Brittle Connector equivalent). The report estimates $500K+ in engineering burn for organizations that build custom integration plumbing rather than using established protocols.

- **Source:** https://composio.dev/blog/why-ai-agent-pilots-fail-2026-integration-roadmap
- **Confidence:** Medium

### Finding 6: GSD-2 Is a Standalone CLI That Left Claude Code -- Coupling Risk

GSD-2 v2 explicitly moved away from Claude Code slash commands to become a standalone CLI built on the Pi SDK. The v1-to-v2 comparison table shows this was a deliberate architectural divergence: v1 was Claude Code slash commands, v2 is a separate runtime with its own state machine, context management, and git strategy. Integrating it back as a plan executor for Claude Code skills creates an impedance mismatch -- gw-skills are Markdown files consumed by Claude Code, while GSD-2 manages its own `.gsd/` state directory, worktree isolation, and dispatch system. This dual-state-machine architecture (Claude Code's context + GSD-2's `.gsd/` state) creates competing sources of truth for what has been done, what needs doing, and where work happens on disk.

- **Source:** https://github.com/gsd-build/gsd-2
- **Confidence:** High

### Finding 7: 40%+ of Agentic AI Projects Will Be Cancelled by 2027

Gartner predicts more than 40% of agentic AI projects will be cancelled by end of 2027 due to escalating costs, unclear business value, or unexpected risks. The gap between a working demo and a reliable production system is where projects fail. For gw-skills, the risk is investing substantial engineering effort into GSD-2 integration only to discover that the orchestration overhead exceeds the productivity gains, particularly given GSD-2's own instability and the fundamental context window constraints.

- **Source:** https://medium.com/@Micheal-Lanham/why-ai-agents-didnt-take-over-in-2025-and-what-changes-everything-in-2026-9393a5bb68e8
- **Confidence:** Medium

### Finding 8: Security Risks of Agent-to-Agent Lateral Movement

Multi-agent architectures introduce lateral movement as a new attack category where compromised agents escalate permissions or pass malicious instructions downstream. Prompt injection in upstream content (documents, webpages) can trigger unreviewed action chains that propagate across agent boundaries. For a gw-skills + GSD-2 pipeline, a malicious instruction in a fetched document could potentially propagate from a research skill through planning into GSD-2's autonomous execution mode, where `/gsd auto` operates with minimal human oversight by design.

- **Source:** https://securityboulevard.com/2026/03/a-guide-to-agentic-ai-risks-in-2026/
- **Confidence:** Medium

### Finding 9: GSD-2's Infinite Loop Problem Is Not Fully Resolved

GitHub Issue #456 documents infinite looping in GSD-2 where it repeatedly asks the same questions. While GSD-2 has a sliding-window stuck detector, the existence of this issue alongside tool-call-loop detection bugs (Issue #1961, where JSON.stringify causes false-positive loop detection) suggests the loop detection mechanism itself is unreliable. In autonomous mode, undetected loops burn tokens and money silently.

- **Source:** https://github.com/gsd-build/gsd-2/issues/456
- **Confidence:** Medium

### Finding 10: Claude Code Sub-Agent Name Inference Overrides Custom Instructions

A documented Claude Code behavior shows that sub-agent names trigger inference of pre-defined behaviors, silently overriding carefully crafted instructions. If you name an agent "code-reviewer," Claude applies generic code review rules instead of your custom instructions. The workaround requires using non-descriptive names. This affects any gw-skills persona system that relies on meaningful agent names -- the 37 default personas may trigger unintended behavior overrides in Claude Code's sub-agent system.

- **Source:** https://www.arsturn.com/blog/fixing-common-claude-code-sub-agent-problems
- **Confidence:** Medium

## Areas of Consensus

1. **Context window management is the primary bottleneck** for agent tool systems. Every source agrees that naive loading of tool definitions and skill files degrades performance. Progressive disclosure and lazy loading are universally recommended.

2. **Multi-agent error compounding is a fundamental mathematical problem**, not an implementation bug. Multiple independent sources confirm that chaining agents multiplies failure rates rather than adding them.

3. **The integration layer fails before the AI does.** Composio, Gartner, and practitioner reports all agree that agent failures are infrastructure failures, not model capability failures. The "plumbing" between systems is where projects die.

4. **Autonomous execution without guardrails is dangerous.** GSD-2's own v2.41.0 release notes documenting silent data loss fixes, and the broader industry's emphasis on human-in-the-loop controls, confirm that "walk away and return to completed work" remains aspirational rather than reliable.

## Areas of Disagreement

1. **Standalone CLI vs. integrated skill system.** GSD-2 chose to leave Claude Code for a standalone runtime; gw-skills chose to stay within Claude Code as Markdown files. These are opposing architectural bets. Integrating them forces a reconciliation of fundamentally different philosophies about where orchestration state should live.

2. **More skills vs. fewer, better skills.** Some sources advocate for comprehensive skill libraries; the context bloat research argues forcefully for minimal, on-demand loading. The gw-skills project with 8+ skills and 37 personas sits on the "more" side of this tension.

3. **Autonomy level.** GSD-2's `/gsd auto` mode assumes high autonomy is desirable. The security and reliability literature argues for tighter human-in-the-loop controls. The right balance depends on risk tolerance the project has not explicitly defined.

## Practical Implications

1. **Before integrating GSD-2, audit its open issue list for blockers.** The subagent instruction passthrough gap (Issue #671 pattern) alone could render the integration ineffective -- gw-skills instructions may never reach the agents writing code.

2. **Implement progressive skill loading.** With 8+ skills and 37 personas, the project is approaching the context bloat threshold. Skills should load on-demand, not at session initialization. Anthropic's own Tool Search pattern (reducing upfront loading to ~500 tokens) is the proven mitigation.

3. **Define explicit error boundaries between gw-skills and GSD-2.** Every handoff is an error compounding point. Build verification gates at each boundary, not just at the end of execution.

4. **Avoid dual state machines.** If GSD-2 manages state in `.gsd/` and Claude Code manages state via conversation context, conflicts will arise. Choose one source of truth.

5. **Budget for GSD-2's instability.** With 54+ open issues and active data loss bugs, plan for integration maintenance overhead, not just initial implementation effort.

6. **Test persona name inference.** Verify that the 37 default persona names do not trigger Claude Code's sub-agent name inference behavior, which silently overrides custom instructions.

7. **Do not trust autonomous mode for critical paths.** GSD-2's own changelog reveals repeated fixes for silent data loss in auto-mode. Treat `/gsd auto` as experimental, not production-ready, regardless of marketing claims.

## Knowledge Gaps

1. **No public benchmarks exist for GSD-2's actual success rate** on multi-milestone autonomous runs. Claims of "walk away and return to completed work" are not backed by published reliability data.

2. **The interaction between Claude Code's native skill system and GSD-2's dispatch system is untested.** No documentation or community reports describe this specific integration pattern.

3. **Token consumption of the combined gw-skills + GSD-2 context payload is unknown.** The `.gsd/` state files (ROADMAP.md, PLAN.md, CONTEXT.md, STATE.md) plus gw-skill definitions plus persona instructions could easily exceed 100K tokens before any task work begins.

4. **GSD-2's compatibility with the current Claude Code version is unclear.** GSD-2 v2 uses the Pi SDK, not Claude Code's native APIs. Version coupling risks are unquantified.

5. **No cost modeling exists for the combined system.** GSD-2 already has a cost-inflating bug (#1943, 35% overcount). Combined with gw-skills' multi-agent debate (37 personas), the token economics of the integrated system are entirely uncharted.

## Sources

| # | Title | URL | Type | Retrieved |
|---|-------|-----|------|-----------|
| 1 | GSD-2 GitHub Repository | https://github.com/gsd-build/gsd-2 | Repository | 2026-03-21 |
| 2 | GSD-2 Open Issues | https://github.com/gsd-build/gsd-2/issues | Issue Tracker | 2026-03-21 |
| 3 | GSD-2 Infinite Looping Issue #456 | https://github.com/gsd-build/gsd-2/issues/456 | Issue | 2026-03-21 |
| 4 | Why AI Agent Pilots Fail (Composio) | https://composio.dev/blog/why-ai-agent-pilots-fail-2026-integration-roadmap | Industry Report | 2026-03-21 |
| 5 | The Two Context Bloat Problems (Agenteer) | https://agenteer.com/blog/the-two-context-bloat-problems-every-ai-agent-builder-must-understand/ | Technical Article | 2026-03-21 |
| 6 | MCP Server Eating Context Window (Apideck) | https://www.apideck.com/blog/mcp-server-eating-context-window-cli-alternative | Benchmark/Analysis | 2026-03-21 |
| 7 | Why Multi-Agent Systems Fail: 17x Error Trap (TDS) | https://towardsdatascience.com/why-your-multi-agent-system-is-failing-escaping-the-17x-error-trap-of-the-bag-of-agents/ | Research Article | 2026-03-21 |
| 8 | Multi-Agent AI Failures Prevention (Galileo) | https://galileo.ai/blog/multi-agent-ai-failures-prevention | Research | 2026-03-21 |
| 9 | Agentic AI Risks 2026 (Security Boulevard) | https://securityboulevard.com/2026/03/a-guide-to-agentic-ai-risks-in-2026/ | Security Analysis | 2026-03-21 |
| 10 | Fixing Claude Code Sub-Agent Problems (Arsturn) | https://www.arsturn.com/blog/fixing-common-claude-code-sub-agent-problems | Technical Guide | 2026-03-21 |
| 11 | Why AI Agents Didn't Take Over in 2025 (Medium) | https://medium.com/@Micheal-Lanham/why-ai-agents-didnt-take-over-in-2025-and-what-changes-everything-in-2026-9393a5bb68e8 | Analysis | 2026-03-21 |
| 12 | 2025 Overpromised AI Agents, 2026 Demands Engineering (Medium) | https://medium.com/generative-ai-revolution-ai-native-transformation/2025-overpromised-ai-agents-2026-demands-agentic-engineering-5fbf914a9106 | Analysis | 2026-03-21 |
