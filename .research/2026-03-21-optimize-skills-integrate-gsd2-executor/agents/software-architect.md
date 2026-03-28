---
persona: Software Architect
question: How can gw-skills be optimized and how to integrate gsd-2 as plan executor
domain: engineering
date: 2026-03-21
depth: lightweight
sources_count: 10
---

# Research Findings: Software Architect

## Executive Summary

gw-skills can be meaningfully optimized through three vectors: (1) skill metadata and description tuning for better activation rates, (2) progressive disclosure to keep SKILL.md bodies lean, and (3) completion of the v1.1 shared-pattern extraction already on the roadmap. GSD-2 is a standalone CLI plan executor built on the Pi SDK that uses a file-system-driven state machine (`.gsd/STATE.md`) with hierarchical Milestone/Slice/Task decomposition, fresh 200k-token contexts per task, and git worktree isolation -- making it a natural complement to gw-skills' existing `gw:worktree execute` manifest system, though integration requires a deliberate bridge layer to translate gw-skill output artifacts into GSD-2's `.gsd/` planning format.

## Key Findings

### Finding 1: Skill Description Quality Is the Primary Activation Bottleneck

Claude uses pure LLM reasoning -- not embeddings or keyword matching -- to decide which skills to load. Testing across 200+ prompts shows that baseline descriptions achieve only ~20% activation, while descriptions with explicit "USE WHEN" trigger patterns reach 50%, and adding input/output examples pushes activation to 72-90%. The gw-skills currently have solid descriptions (e.g., research.md's "Multi-persona research with structured debate, parallel source investigation...") but lack explicit trigger conditions in the description field itself.

- **Source:** https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices
- **Confidence:** High

### Finding 2: SKILL.md Body Size Should Stay Under 500 Lines with Progressive Disclosure

Anthropic's official guidance states SKILL.md bodies should stay under 500 lines for optimal performance, with additional content split into separate files referenced from SKILL.md. At startup, only metadata (name + description) is pre-loaded; SKILL.md is read only when triggered. The gw-skills already use a `_shared/` directory pattern for preamble, branch-first, team-assembly, pptx-design, test-runner, intent-commit, and auto-pr modules. However, the main skill files themselves (e.g., research.md, review-app.md) may exceed this threshold -- review-app.md alone has extensive argument parsing and multi-step workflows that could benefit from further decomposition.

- **Source:** https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices
- **Confidence:** High

### Finding 3: GSD-2 Operates as a File-System State Machine, Not Prompt Injection

GSD-2 (v2.41.0+) is fundamentally different from the original GSD prompt framework. It is a standalone CLI (`npm install -g gsd-pi`) that controls agent execution through `.gsd/STATE.md` on the filesystem. The hierarchy is Milestone (4-10 slices) -> Slice (1-7 tasks) -> Task (must fit one context window). Each task gets a fresh 200k-token session pre-loaded with curated artifacts (task plans, prior summaries, dependency summaries, roadmap excerpts), eliminating context degradation from long sessions. Auto mode (`/gsd auto`) provides fully autonomous execution with crash recovery, cost tracking, and verification gates.

- **Source:** https://github.com/gsd-build/gsd-2
- **Confidence:** High

### Finding 4: GSD-2's Planning Format Aligns with gw-skills' Existing Manifest System

gw-skills' `gw:worktree execute <manifest-path>` already implements dependency-wave parallel execution: it parses a JSON manifest with features, acceptance tests, and dependency graphs, creates worktrees, dispatches agents, and merges results per wave. GSD-2 uses markdown-based planning files (ROADMAP.md, CONTEXT.md, slice plans) with a similar hierarchical decomposition. The integration path would involve translating gw-skill research/review output into GSD-2's `.gsd/` planning structure, then invoking `gsd headless` for autonomous execution.

- **Source:** https://github.com/gsd-build/gsd-2 and review of `/Users/wohlgemuth/skills/.claude/commands/gw/worktree.md` Step 5
- **Confidence:** Medium

### Finding 5: GSD-2's Headless Mode Enables Script-Level Integration

`gsd headless [cmd]` runs without a TUI, auto-responds to interactive prompts, detects completion, and exits with structured codes (0=complete, 1=error, 2=blocked). `gsd headless query` provides instant JSON state snapshots without spawning LLM sessions. This makes GSD-2 invocable from a gw-skill as a subprocess, with the skill polling state via `gsd headless query` and reading results from `.gsd/` artifacts. This is the cleanest integration surface.

- **Source:** https://github.com/gsd-build/gsd-2
- **Confidence:** High

### Finding 6: Context Window Management Is the Dominant Optimization Lever

The official Claude Code best practices page emphasizes that "most best practices are based on one constraint: Claude's context window fills up fast, and performance degrades as it fills." The gw-skills preamble already resolves GW_REPO once and persists it, and shared modules avoid duplication. However, the v1.1 Phase 8 (Reduce Maintenance Drag) which consolidates GW_REPO resolution, workforce loading, PPTX design system, and workforce redirect messages into canonical single sources has not yet started. Completing this phase directly reduces per-invocation token cost.

- **Source:** https://code.claude.com/docs/en/best-practices
- **Confidence:** High

### Finding 7: Plan-Then-Execute Is the Consensus Agent Orchestration Pattern

Multiple 2026 sources converge on the same pattern: explicit planning before implementation is essential for multi-agent coherence. Anthropic's own guidance recommends Explore -> Plan -> Implement -> Commit. Cursor's documented architecture uses Planner/Worker/Judge roles. Mike Mason's analysis confirms "Planning is essential. Agents should plan, then act." GSD-2 embodies this pattern as its core architecture. The gw-skills research and compete skills already produce structured plans -- the gap is automated handoff to an executor.

- **Source:** https://mikemason.ca/writing/ai-coding-agents-jan-2026/ and https://code.claude.com/docs/en/best-practices
- **Confidence:** High

### Finding 8: Git Worktree Isolation Is the Industry-Standard Parallelism Pattern

Both GSD-2 and gw-skills independently arrived at git worktrees as the isolation mechanism for parallel agent work. GSD-2 isolates each milestone in its own worktree with `milestone/<MID>` branches and squash-merges on completion. gw-skills' worktree skill creates per-feature worktrees with manifest tracking. The architectural alignment means a bridge skill could create a GSD-2 milestone within a gw-skill-managed worktree, letting both systems coexist without conflict.

- **Source:** https://github.com/gsd-build/gsd-2 and https://mikemason.ca/writing/ai-coding-agents-jan-2026/
- **Confidence:** High

### Finding 9: Verification Gates Prevent Agent Quality Degradation

GSD-2 runs configurable shell commands (lint, test) after each task with auto-fix retries and configurable max retry limits. The gw-skills test-runner shared module already detects and runs project test suites. The `gw:worktree execute` flow already includes baseline test verification (Step 1e) and per-agent verification. The gap is that individual gw-skills beyond worktree-execute do not consistently enforce verification gates -- review-app and research produce reports but do not validate their outputs programmatically.

- **Source:** https://github.com/gsd-build/gsd-2 and review of gw-skills source
- **Confidence:** Medium

### Finding 10: Subagent Delegation Preserves Main Context Quality

Claude Code officially supports subagents (`.claude/agents/`) that run in isolated contexts and report back summaries. The gw-skills research and review-app skills already spawn agents for parallel investigation (via the Agent tool). The optimization opportunity is defining these as formal subagent definitions in `.claude/agents/` rather than inline prompt construction, which gives them dedicated tool scopes and model selection.

- **Source:** https://code.claude.com/docs/en/best-practices
- **Confidence:** Medium

## Areas of Consensus

1. **Plan before executing.** Every source -- Anthropic docs, GSD-2 architecture, Mike Mason's analysis, Azure patterns -- agrees that agent systems must plan explicitly before implementing. Ad-hoc execution degrades quality.

2. **Fresh context per task unit.** Both GSD-2 and Claude Code best practices emphasize that long accumulated contexts degrade LLM performance. The solution is task-scoped fresh contexts with curated pre-loaded artifacts.

3. **Git worktrees for isolation.** GSD-2, gw-skills, and multiple independent analyses (Steve Yegge's Gas Town, Cursor's architecture) all use git worktrees as the parallelism boundary.

4. **Skill descriptions must be explicit and trigger-rich.** Both official Anthropic documentation and community analysis confirm that vague descriptions cause activation failure regardless of how good the skill body is.

5. **Verification gates are non-negotiable.** GSD-2, Claude Code best practices, and enterprise agent patterns all mandate automated verification (tests, lint, type-check) after agent work.

## Areas of Disagreement

1. **Autonomy level.** GSD-2 is designed for "walk away" full autonomy with crash recovery. gw-skills use approval gates (after Steps 2, 3, 5 in research). The right level depends on task criticality -- there is no consensus on when to remove the human from the loop.

2. **State format: JSON vs. Markdown.** gw-skills' worktree manifest uses JSON (`manifest.json`), while GSD-2 uses markdown (ROADMAP.md, STATE.md). Both work; the disagreement is about whether machine-parseable (JSON) or human-readable (markdown) state is preferable. GSD-2's markdown approach allows the LLM to natively reason about state without serialization overhead.

3. **Orchestration ownership.** Should the orchestrator be the CLI tool (GSD-2) or the skill system (gw-skills' worktree execute)? Running both creates a potential "two generals" problem -- competing state machines managing overlapping concerns.

## Practical Implications

### For gw-skills Optimization (Immediate, No GSD-2)

1. **Tune skill descriptions:** Add explicit "USE WHEN" trigger conditions to every skill's YAML description. Example for research: `"Use when the user asks to research, investigate, analyze, compare, or study a topic across multiple sources."` This alone could double activation rates from ~20% to ~50%.

2. **Audit SKILL.md line counts:** Any skill body exceeding 500 lines should be split. The `_shared/` pattern is already in place -- extend it to move argument parsing tables and error handling into shared reference files.

3. **Complete v1.1 Phase 8 first:** The shared-pattern extraction (GW_REPO resolution, workforce loading, PPTX design, workforce redirect) eliminates duplicated tokens across every skill invocation. This is the highest-ROI optimization on the existing roadmap.

4. **Add verification gates to research and review-app:** These skills produce reports but do not validate outputs. Add a post-generation step that checks report completeness (required sections present, source count > 0, no empty findings).

### For GSD-2 Integration (Bridge Architecture)

1. **Create a `gw:plan-to-gsd` bridge skill** that translates gw-skill output artifacts (research reports, compete specs, review-app findings) into GSD-2's `.gsd/` planning format: PROJECT.md, REQUIREMENTS.md, ROADMAP.md with slice/task decomposition.

2. **Use `gsd headless` as the executor subprocess.** The bridge skill would:
   - Generate `.gsd/` planning artifacts from gw-skill output
   - Invoke `gsd headless auto` for autonomous execution
   - Poll `gsd headless query` for JSON state snapshots
   - Report completion status back to the user

3. **Preserve worktree alignment.** Since both systems use git worktrees, the bridge should either (a) let GSD-2 manage its own worktrees within a gw-skill-created parent, or (b) configure GSD-2 to use the gw-skill worktree directory. Option (a) is safer -- clean boundaries.

4. **Start with `gw:research --execute` as the first integration point.** Research already produces structured plans with implementation steps. Adding a `--execute` flag that pipes the plan through the GSD-2 bridge would be the minimum viable integration.

## Knowledge Gaps

1. **GSD-2 API stability.** GSD-2 is at v2.41.0 with active development. The headless query JSON format may change. No formal API contract or versioning guarantee was found in the documentation.

2. **GSD-2 cost at scale.** GSD-2 tracks per-unit costs but published benchmarks for typical project sizes were not found. The token cost of GSD-2's fresh-context-per-task approach on large projects is unknown.

3. **Claude Code plugin system maturity.** The `/plugin` marketplace was referenced in the docs but its current status, review process, and whether gw-skills could be distributed as a plugin is unclear.

4. **Concurrent GSD-2 + gw-skill state conflicts.** No documentation describes what happens if both systems try to manage `.gsd/` and `.worktrees/` in the same repository simultaneously. Conflict behavior is untested.

5. **gw-skill line counts.** The actual line counts of each skill body were not measured in this research pass. The 500-line threshold needs to be validated against the current skill files.

## Sources

| # | Title | URL | Type | Retrieved |
|---|-------|-----|------|-----------|
| 1 | GSD-2 GitHub Repository | https://github.com/gsd-build/gsd-2 | GitHub Repo | 2026-03-21 |
| 2 | GSD-2 Getting Started Guide | https://github.com/gsd-build/gsd-2/blob/main/docs/getting-started.md | Documentation | 2026-03-21 |
| 3 | Best Practices for Claude Code | https://code.claude.com/docs/en/best-practices | Official Docs | 2026-03-21 |
| 4 | Skill Authoring Best Practices - Claude API Docs | https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices | Official Docs | 2026-03-21 |
| 5 | Claude Code Skills Structure and Usage Guide (Gist) | https://gist.github.com/mellanon/50816550ecb5f3b239aa77eef7b8ed8d | Community Guide | 2026-03-21 |
| 6 | AI Coding Agents 2026: Coherence Through Orchestration | https://mikemason.ca/writing/ai-coding-agents-jan-2026/ | Tech Blog | 2026-03-21 |
| 7 | AI Agent Orchestration Patterns - Azure Architecture Center | https://learn.microsoft.com/en-us/azure/architecture/ai-ml/guide/ai-agent-design-patterns | Architecture Guide | 2026-03-21 |
| 8 | What Is GSD? Spec-Driven Development Without the Ceremony | https://medium.com/@richardhightower/what-is-gsd-spec-driven-development-without-the-ceremony-570216956a84 | Tech Blog | 2026-03-21 |
| 9 | Claude Code Merges Slash Commands Into Skills | https://medium.com/@joe.njenga/claude-code-merges-slash-commands-into-skills-dont-miss-your-update-8296f3989697 | Tech Blog | 2026-03-21 |
| 10 | Unlocking Exponential Value with AI Agent Orchestration - Deloitte | https://www.deloitte.com/us/en/insights/industry/technology/technology-media-and-telecom-predictions/2026/ai-agent-orchestration.html | Industry Report | 2026-03-21 |
