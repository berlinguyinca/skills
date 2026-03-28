---
persona: Software Architect
round: 1
date: 2026-03-21
---

# Round 1 — Position Statement: Software Architect

## Position

The gw-skills system exhibits strong architectural instincts — shared modules in `_shared/`, a clear preamble/branch/execute lifecycle, and worktree-based isolation for parallelism — but it has grown organically beyond its structural boundaries. Six of the twelve command files exceed 500 lines (saas-idea at 2,117, research at 1,192, compete at 971, review-app at 937, weekly-review at 869, audit-repo at 804), which means the LLM must process increasingly large instruction sets per invocation, degrading both activation reliability and execution fidelity. The optimization path is not a rewrite; it is a disciplined application of the Single Responsibility Principle and Interface Segregation Principle to decompose these monoliths into orchestrator stubs that delegate to phase-specific reference files. The `_shared/` pattern already proves this works — it just needs to be applied more aggressively to the skill bodies themselves.

Integrating GSD-2 as a plan executor is architecturally sound but requires a deliberate anti-corruption layer. GSD-2 and gw-skills are two independent state machines: gw-skills manages execution through in-context step sequences with approval gates, while GSD-2 manages execution through a file-system state machine (`.gsd/STATE.md`) with milestone/slice/task decomposition. Coupling them directly — having gw-skills write to `.gsd/` or GSD-2 read gw-skill manifests — would create a Distributed Monolith: two systems with a shared mutable state boundary and no contract. The correct integration is a bridge skill (`gw:execute` or `gw:plan-to-gsd`) that acts as an Adapter between the two systems, translating gw-skill output artifacts into GSD-2's planning format, invoking `gsd headless` as a subprocess, and polling `gsd headless query` for status. This preserves clean boundaries: gw-skills own the planning phase, GSD-2 owns the execution phase, and the bridge owns the translation.

The deeper architectural question is orchestration ownership. Today, `gw:worktree execute` already implements dependency-wave parallel execution with agent dispatch, verification, and merge. GSD-2 offers the same capabilities plus crash recovery, cost tracking, fresh 200k-token contexts per task, and a headless mode designed for programmatic integration. Rather than maintaining two parallel orchestrators, the system should evolve toward a clean separation: gw-skills remain the intelligence layer (research, analysis, team assembly, debate) while GSD-2 becomes the execution engine for implementation tasks. This is the Ports and Adapters pattern — gw-skills define what to build, GSD-2 handles how to build it.

## Top Conclusions

1. **Skill file decomposition is the highest-ROI immediate optimization** (Confidence: H)
   - **Evidence:** Six of twelve command files exceed the 500-line threshold that Anthropic's own documentation identifies as the performance cliff for skill bodies. saas-idea.md alone is 2,117 lines — over 4x the recommended maximum. The `_shared/` module pattern already exists and works (7 shared modules totaling 370 lines). Extending this pattern to extract argument-parsing tables, agent prompt templates, and phase-specific instructions into reference files would bring every skill under 500 lines without changing any behavior. This is pure structural refactoring with zero functional risk.

2. **GSD-2 integration must use a bridge/adapter pattern, not direct coupling** (Confidence: H)
   - **Evidence:** GSD-2 uses markdown-based state files (`.gsd/STATE.md`, `ROADMAP.md`) while gw-skills use JSON manifests (`manifest.json`) and in-context step sequences. These are incompatible state representations. Direct coupling (either system reading the other's state files) violates the Dependency Inversion Principle and creates a shared-mutable-state boundary that neither system controls. GSD-2's `gsd headless` mode with structured exit codes (0=complete, 1=error, 2=blocked) and `gsd headless query` for JSON state snapshots provide a clean programmatic interface — this is the integration surface. The bridge skill translates between formats, preserving each system's internal invariants.

3. **The `gw:worktree execute` manifest system should be the first GSD-2 integration point** (Confidence: M)
   - **Evidence:** `gw:worktree execute` already implements the exact same pattern as GSD-2: hierarchical decomposition (features with dependencies = milestones with slices), dependency-wave execution, agent dispatch with verification, and merge-on-complete. The manifest JSON format maps naturally to GSD-2's ROADMAP.md structure — features become milestones, acceptance tests become task verification gates. However, the confidence is Medium because the two systems' worktree management could conflict if not carefully coordinated (both create branches, both manage worktree directories, both attempt merges).

4. **Skill description tuning can double activation rates with zero structural changes** (Confidence: H)
   - **Evidence:** Anthropic's best practices documentation confirms that Claude uses pure LLM reasoning (not embeddings or keyword matching) for skill activation, and that descriptions with explicit "USE WHEN" trigger patterns achieve 50% activation versus 20% baseline. The current gw-skill descriptions are informative but lack explicit trigger conditions. For example, research.md's description is "Multi-persona research with structured debate, parallel source investigation, and actionable output" — this describes capabilities but not activation triggers. Adding "USE WHEN the user asks to research, investigate, analyze, compare, study, or explore a topic" would significantly improve activation without touching the skill body.

5. **v1.1 Phase 8 (shared-pattern extraction) should be completed before GSD-2 integration** (Confidence: M)
   - **Evidence:** Phase 8 consolidates GW_REPO resolution, workforce loading, PPTX design system, and workforce redirect messages into canonical single sources. Today, every skill independently resolves GW_REPO with the same 2-line bash snippet and independently handles `--hire/--fire/--roster` redirects. This duplication is not just maintenance drag — it consumes tokens on every invocation. Completing Phase 8 first reduces the per-invocation token budget, making room for the additional context that a GSD-2 bridge skill would require. Confidence is Medium because the token savings are real but the magnitude is uncertain without measurement.

## Uncertainties

1. **GSD-2 API stability and versioning.** GSD-2 is at v2.41.0 with active development. No formal API contract or versioning guarantee was found for the `gsd headless query` JSON format. Building a bridge skill against an unstable interface risks breakage on upstream updates. Mitigation: pin to a specific GSD-2 version and add a version-check preamble to the bridge skill.

2. **Concurrent worktree management conflicts.** Both gw-skills and GSD-2 create git branches and worktrees. If the bridge skill invokes GSD-2 inside a gw-skill-managed worktree, both systems may attempt branch operations on overlapping namespaces. The interaction behavior is undocumented and untested. Mitigation: enforce namespace conventions (gw-skills use `gw/<name>` branches, GSD-2 uses `milestone/<MID>` branches) and let GSD-2 manage its own worktrees in a subdirectory.

3. **Token cost of GSD-2's fresh-context-per-task model.** GSD-2 pre-loads each task with curated artifacts in a fresh 200k-token session. For projects with many small tasks, this could be significantly more expensive than gw-skills' current approach of dispatching lightweight agents. No published benchmarks for typical cost-per-project were found.

4. **Actual line count impact on performance.** The 500-line threshold comes from Anthropic's guidance, but the actual performance degradation curve is not published. It is possible that 800-line skills perform adequately while 2,000-line skills do not — but the exact inflection point is unknown.

5. **Autonomy level calibration.** GSD-2 is designed for "walk away" full autonomy with crash recovery. gw-skills use approval gates (after Steps 2, 3, 5 in research). The bridge skill must decide which model to follow. For research and analysis tasks, human-in-the-loop gates are likely necessary; for implementation tasks, GSD-2's autonomous mode may be appropriate. The right boundary is task-dependent and not formalized.

## Recommendations

1. **Immediate (0-2 weeks): Decompose oversized skill files.** Extract argument-parsing tables, agent prompt templates, search-skill mapping tables, and phase-specific instructions from the six oversized skills into `_shared/` or skill-specific reference files (e.g., `_shared/research-phases.md`, `_shared/saas-scoring.md`). Target: every skill orchestrator under 500 lines, with `include`-style references to extracted content. This is the Single Responsibility Principle applied to prompt engineering.

2. **Immediate (0-2 weeks): Add "USE WHEN" trigger patterns to all skill descriptions.** Audit all 12 command YAML frontmatter descriptions and add explicit activation triggers. Format: `"<capability description>. USE WHEN user asks to <verb1>, <verb2>, <verb3>..."`. Validate by testing activation against 20 representative prompts per skill.

3. **Short-term (2-4 weeks): Complete v1.1 Phase 8 shared-pattern extraction.** Consolidate GW_REPO resolution, workforce redirects, and PPTX design into canonical shared modules. Measure token savings per invocation before and after.

4. **Medium-term (4-8 weeks): Build `gw:execute` bridge skill.** Create a new command that accepts a gw-skill output artifact (research report, compete spec, worktree manifest) and translates it into GSD-2's `.gsd/` planning format. The bridge should: (a) generate PROJECT.md and ROADMAP.md from the artifact, (b) invoke `gsd headless auto`, (c) poll `gsd headless query` for status, (d) report results. Start with `gw:worktree execute` manifest as the first supported input format.

5. **Medium-term: Add `--execute` flag to `gw:research`.** After the bridge skill exists, add a flag that pipes the research output's implementation plan directly into `gw:execute`. This closes the plan-to-execution loop: research produces a plan, `--execute` translates it to GSD-2 format, GSD-2 executes it autonomously.

## Risks

1. **Two-Generals Problem in dual orchestration.** If both gw-skills' worktree-execute and GSD-2 are active, they represent competing state machines managing overlapping concerns (branch creation, agent dispatch, verification, merge). A failure in the bridge layer could leave the repository in an inconsistent state where neither system has a complete picture. Mitigation: the bridge skill must be the sole owner of the GSD-2 lifecycle — no direct GSD-2 invocation outside the bridge.

2. **Skill decomposition could reduce coherence.** Splitting a 2,117-line skill into an orchestrator + 5 reference files means the LLM must read multiple files to understand the full workflow. If reference files are not loaded at the right time, the LLM may miss context. Mitigation: use progressive disclosure — the orchestrator contains the step sequence and decision logic; reference files contain only templates and data tables that are loaded just-in-time.

3. **GSD-2 dependency introduces external supply chain risk.** GSD-2 is an independently maintained npm package. Breaking changes, abandonment, or license changes could strand the bridge skill. Mitigation: the bridge skill should encapsulate all GSD-2 interactions behind a single module, making replacement feasible. Do not spread GSD-2 assumptions across multiple skills.

4. **Over-engineering the integration before validating demand.** Building a full bridge skill is significant effort. If users primarily use gw-skills for research and analysis (not implementation), the GSD-2 integration may see low adoption. Mitigation: start with the `--execute` flag on research as a low-commitment experiment. Measure usage before building the full `gw:execute` command.

5. **Token budget pressure from bridge overhead.** The bridge skill adds a translation layer that consumes tokens for format conversion, status polling, and result summarization. Combined with GSD-2's own token consumption for fresh contexts, the total cost per execution could be significantly higher than the current gw-skills-only approach. Mitigation: implement cost estimation in the bridge skill and present it to the user before execution begins, with an explicit opt-in gate.
