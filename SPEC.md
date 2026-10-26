# gw-skills Optimization & GSD-2 Integration -- Specification

**Generated:** 2026-03-21
**Source:** gw:research CONSENSUS.md
**Confidence:** High (optimization), Medium (integration)

## Goal
Optimize gw-skills by decomposing oversized skill files, fixing broken GSD detection, improving activation reliability, and migrating 47 GSD v1 references to a centralized GSD-2 bridge skill.

## Requirements

### Core Features (Tier 1 -- High Confidence)
- [ ] Decompose `saas-idea.md` (2,117 lines) into orchestrator + reference files, all under 500 lines
- [ ] Decompose `research.md` (1,192 lines) into orchestrator + reference files
- [ ] Decompose `compete.md` (971 lines) into orchestrator + reference files
- [ ] Decompose `review-app.md` (937 lines) into orchestrator + reference files
- [ ] Decompose `weekly-review.md` (869 lines) into orchestrator + reference files
- [ ] Decompose `audit-repo.md` (804 lines) into orchestrator + reference files
- [ ] Fix `_shared/preamble.md` to detect `.gsd/STATE.md` (GSD-2) alongside `.planning/config.json` (GSD v1)
- [ ] Rewrite all 12 skill descriptions with "USE WHEN" trigger patterns
- [ ] Measure context window token payload for representative skill invocation

### Technical Requirements (Tier 2 -- Moderate Confidence)
- [ ] Build `gw:gsd` bridge skill with Strategy pattern (supervised mode only)
- [ ] Bridge accepts source artifact path + phase mapping configuration payload
- [ ] Bridge handles GSD-2 protocol: detection, brownfield/greenfield routing, plan translation, invocation, graceful degradation
- [ ] Replace inline `[g] GSD` action in 5 skills (research, compete, review-app, audit-repo, saas-idea shallow) with bridge delegation
- [ ] Create `_shared/budget-guard.md` with max subagent count (default 10), per-agent timeout (5 min), per-skill timeout (30 min)
- [ ] Instrument gw:research to log per-persona token consumption and contribution quality

### Non-Functional Requirements
- [ ] No breaking changes to existing skill argument contracts
- [ ] All decomposed skills produce identical output to their monolithic versions
- [ ] Bridge skill degrades gracefully when GSD-2 is not installed
- [ ] Budget guard is configurable per-skill via frontmatter or arguments

## Extraction Taxonomy (for skill decomposition)

| Content Type | Action | Rationale |
|---|---|---|
| Format templates (output formats, report structures) | Extract to `_shared/` | Phase-specific, only needed at output time |
| Data/reference tables (source mappings, detection signals, scoring criteria) | Extract to `_shared/` | Lookup data, not decision logic |
| Phase-specific execution instructions (PPTX generation, PR creation) | Extract to `_shared/` | Already proven pattern (pptx-design.md, auto-pr.md) |
| Decision-shaping instructions (scoring logic, budget semantics, constraint definitions) | Keep inline | Must be visible when LLM makes decisions |
| Hard constraints (mandatory stack, naming conventions, security requirements) | Keep inline or load at decision point | Extracting risks instruction loss under context pressure |
| Agent prompt templates | Extract to `_shared/` | Large, formulaic, loaded just-in-time |

## Bridge Skill Design

### Protocol (owned by bridge)
1. Check if GSD-2 CLI is installed (`which gsd`)
2. Detect project state: `.gsd/STATE.md` (GSD-2 brownfield) or nothing (greenfield)
3. If brownfield: translate skill output to GSD-2 milestone format, invoke `gsd headless auto` (when autonomous mode enabled)
4. If greenfield: generate `.gsd/PROJECT.md` + `.gsd/ROADMAP.md` from skill output, invoke `gsd init` + `gsd headless auto`
5. If GSD-2 not installed: degrade gracefully with message suggesting installation

### Per-skill configuration payload
```
source: <path to skill output artifact>
phase_mapping: <how skill output maps to GSD-2 milestones/slices>
context: <optional metadata like TDD anchors, workflow instructions>
```

### Exclusion
- `saas-idea` Phase 5 auto-chain is NOT handled by the bridge (blocked on subagent instruction passthrough)

## Gate Conditions for Autonomous Execution (Tier 3)
- [ ] GSD-2 subagent instruction passthrough resolved upstream OR verified fixed in current version OR workaround documented
- [ ] Proof-of-concept achieves >80% task completion rate on representative plan
- [ ] Budget enforcement (`_shared/budget-guard.md`) is operational
- [ ] Kill criteria defined: token budget >120K remaining, success rate >80%, maintenance <4 hours/month
- [ ] Combined token payload measurement shows >80K usable tokens remaining

## Out of Scope
- `.claude/commands/` to `.claude/skills/` directory migration (deferred -- evaluate after Claude Code skills directory stabilizes)
- Full autonomous execution via `gsd headless auto` (gated behind Tier 3 conditions)
- PromptAgent-style automated prompt optimization for skill instructions (untested for complex procedural instructions)
- Selective persona engagement implementation (measure first via Tier 2 instrumentation, then design)
- `saas-idea` Phase 5 GSD-2 auto-chain integration (blocked on subagent instruction passthrough)

## Success Criteria
- [ ] All 12 skill files under 500 lines
- [ ] Preamble correctly detects both GSD v1 and GSD-2 projects
- [ ] All skill descriptions include "USE WHEN" trigger patterns
- [ ] Bridge skill successfully translates research CONSENSUS.md to GSD-2 ROADMAP.md format
- [ ] Bridge skill degrades gracefully when GSD-2 is not installed
- [ ] Budget guard prevents runaway subagent costs (verified by test)
- [ ] No regression in existing skill behavior (end-to-end test each decomposed skill)

## References
- `.research/2026-03-21-optimize-skills-integrate-gsd2-executor/CONSENSUS.md`
- `.research/2026-03-21-optimize-skills-integrate-gsd2-executor/agents/` (5 specialist reports)
- `.research/2026-03-21-optimize-skills-integrate-gsd2-executor/debate/` (2 rounds, 10 position papers)
- GSD-2: https://github.com/gsd-build/gsd-2
- Anthropic skill best practices: https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices
