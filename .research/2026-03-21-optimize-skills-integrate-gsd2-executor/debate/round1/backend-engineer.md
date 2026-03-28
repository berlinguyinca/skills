---
persona: Backend Engineer
round: 1
date: 2026-03-21
---

# Round 1 — Position Statement: Backend Engineer

## Position

The gw-skills system has a data pipeline reliability problem disguised as a feature richness problem. Seven of the thirteen skill files exceed the 500-line recommended threshold for Claude Code skills, with `saas-idea.md` at 2,117 lines and `research.md` at 1,192 lines. From a backend engineering perspective, these are monolithic request handlers -- the equivalent of a single API endpoint that accepts 12 optional query parameters (`review-app`'s skip flags), performs multi-stage orchestration, spawns parallel workers, commits to git, creates PRs, and generates PPTX output all in one call. The immediate optimization priority is decomposing these oversized skills into composable pipeline stages with well-defined contracts between them, rather than adding more features or integrations.

Integrating GSD-2 as a plan executor is architecturally sound but must be approached as a loose-coupling problem, not a tight integration. GSD-2's file-based state machine (`.gsd/STATE.md`, `PLAN.md`, `CONTEXT.md`, `completed-units.json`) and its headless mode with structured exit codes (0=complete, 1=error, 2=blocked) provide a clean API contract. The correct integration pattern is a "plan generation" adapter: gw-skills produce a GSD-2-compatible plan file, then the user (or a thin bridge skill) invokes `gsd headless` to execute it. This keeps the two systems independently deployable and testable. The existing preamble already detects GSD v1's `.planning/config.json`; extending it to detect `.gsd/STATE.md` is a small, safe change. However, any tighter coupling -- where a gw-skill directly invokes GSD-2 in-process and monitors its execution -- introduces a runtime dependency that will create operational complexity disproportionate to its value.

The critical insight from the codebase analysis is that gw-skills already implement a de facto state machine pattern (branch creation, stash/pop, approval gates, subagent dispatch, PR creation) but without the crash recovery, budget enforcement, or structured error handling that GSD-2 provides. Rather than duplicating those capabilities within gw-skills, the system should delegate long-running autonomous execution to GSD-2 and keep gw-skills focused on what they do well: interactive, human-in-the-loop orchestration with approval gates.

## Top Conclusions

1. **Six of thirteen gw-skills exceed the 500-line recommended limit, creating a reliability ceiling** (Confidence: H)
   - **Evidence:** Line counts from the actual codebase: `saas-idea.md` (2,117), `research.md` (1,192), `compete.md` (971), `review-app.md` (937), `weekly-review.md` (869), `audit-repo.md` (804). Claude Code's official documentation recommends keeping SKILL.md under 500 lines and splitting reference material into separate files. The shared module pattern (`_shared/preamble.md`, `_shared/branch-first.md`, `_shared/team-assembly.md`) already demonstrates the correct decomposition approach -- it just hasn't been applied to the skill bodies themselves. Each of these large skills contains inline reference tables (source mapping tables, detection signal tables, category definitions) that should be extracted to `_shared/` files.

2. **GSD-2 integration should use a plan-generation adapter pattern, not direct invocation** (Confidence: H)
   - **Evidence:** GSD-2's headless mode provides structured exit codes (0/1/2) and auto-responds to prompts, making it a well-defined external process. The existing `_shared/auto-pr.md` module already demonstrates the pattern of shelling out to `gh` CLI with error handling and graceful degradation. A `gsd-plan-export.md` shared module could follow the same pattern: generate a `.gsd/PLAN.md` file with milestone/slice/task structure, then optionally invoke `gsd headless`. This avoids tight coupling while still enabling the workflow. The preamble's existing GSD v1 detection (`_shared/preamble.md` lines 17-25) proves the codebase already expects to coexist with GSD projects.

3. **The approval-gate pattern in gw-skills and GSD-2's autonomous execution serve different use cases and should not be merged** (Confidence: H)
   - **Evidence:** `research.md` has approval gates after Steps 2, 3, and 5. `review-app.md` has approval gates in team assembly and before output generation. These gates exist because research and review are inherently exploratory -- the user needs to confirm direction before investing compute. GSD-2's auto mode is designed for executing well-defined plans where the scope is already locked. The correct architecture is: gw-skills handle the interactive planning phase (with approval gates), then hand off a finalized plan to GSD-2 for autonomous execution. Trying to make gw-skills fully autonomous or GSD-2 fully interactive would degrade both systems.

4. **Budget enforcement is the missing critical infrastructure for any autonomous execution path** (Confidence: H)
   - **Evidence:** None of the current gw-skills implement step count limits, cost caps, or runtime limits. The subagent dispatches in `research.md` Step 4 and `review-app.md` Step 2 launch N parallel agents with no ceiling on total token consumption. GSD-2 provides budget ceilings with preemptive pause and sliding-window stuck detection. If gw-skills adopt GSD-2 for execution, they inherit these guardrails for free. If they don't, they need to implement equivalent protections before any autonomous execution is safe, especially for the `--deep` research mode which presumably generates more extensive (and expensive) agent runs.

5. **The preamble's GSD detection needs a version-aware upgrade path** (Confidence: M)
   - **Evidence:** The current preamble (`_shared/preamble.md`) checks for `.planning/config.json` (GSD v1). GSD-2 uses `.gsd/` with a different file structure (`STATE.md`, `PLAN.md`, `CONTEXT.md`). A naive "check both" approach creates a maintenance burden as GSD evolves (the project is at v2.41.0 with active development and no documented state format stability guarantees). The detection should be version-aware: check `.gsd/STATE.md` first (GSD-2), fall back to `.planning/config.json` (GSD v1), and log which version was detected. This is a small change but has outsized impact since every gw-skill includes the preamble.

## Uncertainties

- **GSD-2 plan file schema stability.** The exact format of `.gsd/PLAN.md` (milestone/slice/task structure, checkbox conventions, metadata fields) is not documented as a stable API. Building a plan generator against an unstable schema means maintenance burden on every GSD-2 release. I was unable to find a formal schema specification or versioning contract for the state files.

- **Token budget pressure from skill descriptions.** With 13 skill files and growing, the 2% context window budget for skill descriptions may already be under pressure. No measurement of the current aggregate description footprint exists. If descriptions are being silently truncated, activation reliability is degraded and the user would not know.

- **Parallel subagent cost characteristics.** The research and review-app skills launch N parallel subagents (up to 10 for review-app). The actual token consumption profile of these parallel runs -- and whether they hit rate limits in practice -- is unknown. This matters because GSD-2 integration would add another layer of agent spawning.

- **GSD-2 installation prevalence.** The integration assumes GSD-2 is installed in the user's environment. If adoption is low, the integration becomes dead code. No telemetry or user survey data on GSD-2 usage within the gw-skills user base was available.

## Recommendations

1. **Extract inline reference tables from the six oversized skills into `_shared/` modules.** Priority targets: the 40-row source mapping table in `research.md` (lines 157-199+), the detection signal tables in `review-app.md` (lines 66-104), and the category definitions in `saas-idea.md`. This is the highest-ROI optimization: it reduces skill file sizes below the 500-line threshold, improves context window efficiency, and makes the reference data reusable across skills. Estimated effort: 1-2 days.

2. **Build a `_shared/gsd2-plan-export.md` module that converts gw-skill output into GSD-2 plan format.** The module should: (a) check if GSD-2 is installed (`which gsd`), (b) generate a `.gsd/PLAN.md` with the skill's output structured as milestones/slices/tasks, (c) optionally invoke `gsd headless` if the user passes `--execute`, (d) degrade gracefully if GSD-2 is not present. Skills that produce structured output (`research`, `review-app`, `audit-repo`, `saas-idea`) would include this module after their output step.

3. **Upgrade `_shared/preamble.md` to version-aware GSD detection.** Check for `.gsd/STATE.md` (GSD-2) first, then `.planning/config.json` (GSD v1). Log which version is detected. Inherit model profile and budget settings from whichever version is found. This is a prerequisite for any deeper GSD-2 integration.

4. **Add budget guardrails to all skills that spawn parallel subagents.** At minimum: (a) a hard cap on total subagent count (already partially implemented via team sizing, but not enforced at the dispatch level), (b) a timeout per subagent (prevent hung agents from blocking the pipeline), (c) a total skill execution timeout. These can be implemented as a `_shared/budget-guard.md` module included before subagent dispatch steps.

5. **Audit and optimize all 13 skill descriptions for activation reliability.** Rewrite descriptions in third person, add specific trigger keywords, and include "when to use" guidance. Measure the aggregate description byte count against the 2% budget. This is low effort and directly improves the user experience for skill discovery.

## Risks

- **Schema drift between gw-skills plan output and GSD-2 plan input.** If GSD-2 changes its plan format without a deprecation period, the plan-generation adapter breaks silently (generating plans that GSD-2 cannot parse or parses incorrectly). Mitigation: pin to a known GSD-2 version in the adapter, add a format version header to generated plans, and validate the generated plan with `gsd validate` if such a command exists.

- **Increased operational complexity from dual state directories.** Supporting both `.planning/` (GSD v1) and `.gsd/` (GSD-2) in the preamble means two code paths for detection, two formats for model profile extraction, and two sets of edge cases. Mitigation: set a deprecation timeline for GSD v1 support (e.g., remove `.planning/` detection after 6 months).

- **Subagent cost explosion in autonomous mode.** If gw-skills delegate to GSD-2 for autonomous execution, and GSD-2 spawns Claude Code sessions via `-p` flag for each task, the total cost could be N(skills) x M(tasks) x tokens-per-session. Without budget enforcement on both the gw-skill side and the GSD-2 side, a single `research --deep --execute` could consume significant API credits. Mitigation: require explicit `--execute` flag (never auto-execute), inherit GSD-2's budget ceiling, and display a cost estimate before execution begins.

- **Loss of human oversight in the handoff gap.** The current gw-skills approval gates ensure the user reviews intermediate outputs. If execution is handed off to GSD-2 after the planning phase, the user loses visibility into execution-time decisions (e.g., which files GSD-2 modifies, how it handles ambiguous requirements). Mitigation: require GSD-2's milestone validation gates to produce human-readable summary files that gw-skills can present after execution completes.

- **Skill file decomposition may temporarily break existing user workflows.** If large skills are split into smaller files with `_shared/` references, users who have memorized the current skill structure or have custom forks may be disrupted. Mitigation: ensure the decomposition is purely structural (no behavior changes), document the new file layout in a CHANGELOG entry, and keep the skill entry point files (`research.md`, `review-app.md`, etc.) as the single point of invocation.
