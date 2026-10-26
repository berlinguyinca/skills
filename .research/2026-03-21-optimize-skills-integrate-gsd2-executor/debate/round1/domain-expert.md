---
persona: Domain Expert
round: 1
date: 2026-03-21
---

# Round 1 — Position Statement: Domain Expert

## Position

Having examined the gw-skills codebase in detail -- 9,091 lines across 12 skill files, 7 shared modules, a symlink-based install mechanism, and deep GSD v1 integration already wired into 6 of the 12 skills -- my position is that optimization and GSD-2 integration are two separable but complementary workstreams that should be sequenced carefully. In practice, the most impactful optimizations are not the ones that sound the most architecturally elegant (migrating to `.claude/skills/`), but the ones that address the actual bottlenecks: context window consumption from oversized skill files, wasted tool calls on boilerplate preamble resolution, and fragile GSD v1 integration paths that check for directory structures that no longer exist in GSD-2.

The GSD-2 integration question is more nuanced than "just add a bridge skill." The current codebase already has substantial GSD v1 integration: `saas-idea` has a full Phase 5 build execution pipeline that synthesizes a GSD Idea Document and launches `/gsd:new-project --auto`; `research`, `compete`, `review-app`, and `audit-repo` all offer `[g] GSD` as an output action that dispatches to `/gsd:new-milestone` or `/gsd:new-project`. This is not a greenfield integration -- it is a migration from GSD v1's `/gsd:*` slash commands and `.planning/` directory convention to GSD-2's standalone CLI and `.gsd/` state machine. The migration surface is large (I counted 47 GSD-related references across the skill files), and breaking it requires understanding that GSD-2 is no longer a Claude Code plugin but an independent process with its own execution model.

The critical insight from 18 years of building developer tooling: the highest-ROI change is not adding new features but reducing the failure modes of existing ones. The current preamble resolution pattern costs 2-3 tool calls per invocation across all 12 skills. The `saas-idea.md` file at 2,117 lines is over 4x the recommended 500-line ceiling, which means the LLM is processing instruction-dense text well past the point where instruction-following degrades. And the GSD v1 detection in `preamble.md` checks for `.planning/config.json`, which GSD-2 does not produce -- meaning the model inheritance feature silently fails for GSD-2 users. These are the fires to put out first.

## Top Conclusions

1. **Skill file decomposition is the single highest-impact optimization** (Confidence: H)
   - **Evidence:** `saas-idea.md` (2,117 lines), `research.md` (1,192 lines), `compete.md` (971 lines), `review-app.md` (937 lines), `weekly-review.md` (869 lines), and `audit-repo.md` (804 lines) all exceed the empirically-validated 500-line ceiling. Anthropic's own best practices and community research (mellanon's study across 200+ prompts) converge on the finding that instruction-following quality degrades in long skill files. The gw-skills already demonstrate the correct architectural pattern via shared modules (`_shared/branch-first.md`, `_shared/team-assembly.md`, `_shared/pptx-design.md`), but the main skill files have not been similarly decomposed. Moving reference sections, error handling blocks, detailed spec templates, and output format definitions into supporting files would bring every skill under 500 lines without changing any behavior.

2. **GSD-2 integration is a migration, not a new integration, and the migration surface is large** (Confidence: H)
   - **Evidence:** I found 47 GSD-related references across the skill files. Six skills (`research`, `compete`, `review-app`, `saas-idea`, `audit-repo`, `merge-prs`) already have GSD v1 integration paths. The `preamble.md` checks for `.planning/config.json` (GSD v1) for model profile inheritance. `saas-idea` has the deepest integration: a full Phase 5 that writes `GSD-IDEA-DOC.md` and invokes `/gsd:new-project --auto`. Migrating to GSD-2 means changing: (a) detection from `.planning/config.json` to `.gsd/STATE.md`, (b) invocation from `/gsd:new-project` and `/gsd:new-milestone` to `gsd init` and `gsd headless auto`, (c) output format from `.planning/` directory trees to `.gsd/ROADMAP.md` milestone/slice/task structure, and (d) progress checking from `/gsd:progress` to `gsd headless query`. This is a coordinated change across at least 7 files, not a drop-in replacement.

3. **Dynamic context injection for the preamble would save 2-3 tool calls per invocation across all skills** (Confidence: H)
   - **Evidence:** Every single skill file (all 12) begins with the same Step 0 pattern: resolve `GW_REPO` via bash, then "read and follow" `preamble.md`. This means Claude must (1) execute bash to resolve the path, (2) read the preamble file, and (3) execute the update check bash command inside the preamble. With Claude Code's `!`command`` dynamic context injection (documented in the skills spec), the preamble content and update check result could be pre-injected before Claude sees the skill content, eliminating tool calls entirely. However, this feature requires the `.claude/skills/` directory -- which connects to the directory migration question.

4. **The `.claude/commands/` to `.claude/skills/` migration is blocked by the install mechanism and has breaking-change risk** (Confidence: M)
   - **Evidence:** The `install.sh` script symlinks `.claude/commands/gw/` to `~/.claude/commands/gw/`. All skills are invoked as `/gw:<name>`. Claude Code's skills directory uses a different invocation pattern and discovery mechanism. The README documents the `/gw:` prefix explicitly. The memory file `feedback_gw_prefix.md` mandates "All skills in this repo must use the gw: prefix." Migration would require: updating `install.sh` to symlink into `~/.claude/skills/`, verifying that the `/gw:` invocation prefix still works with the skills directory, testing that `$ARGUMENTS` still passes through correctly, and updating all documentation. The benefit (unlocking `context: fork`, lifecycle hooks, `model` overrides, `effort` levels) is real but not urgent until there is a concrete use case requiring these features. The risk of breaking existing users during migration is non-trivial.

5. **A `gw:gsd` bridge skill is the right integration pattern, not modifying every existing skill** (Confidence: M)
   - **Evidence:** The current architecture already separates plan generation from plan execution -- skills produce reports (`.analysis/REPORT.md`, `.competitors/REPORT.md`, `.research/CONSENSUS.md`, `.saas-ideas/deep-dive/TECH-SPEC.md`) and then offer output actions including `[g] GSD`. Rather than modifying the GSD integration path in each of the 6 skills that support it, a dedicated `gw:gsd` bridge skill could: (a) accept any gw-skills report as input, (b) convert it to GSD-2's `.gsd/ROADMAP.md` format, (c) optionally invoke `gsd headless auto` for autonomous execution, and (d) provide status via `gsd headless query`. This decouples the conversion logic from individual skills and provides a single place to maintain the GSD-2 protocol. The risk is that it adds indirection and breaks the current inline `[g]` user flow where GSD launches directly from the skill's output menu.

## Uncertainties

1. **GSD-2 plan format schema.** The exact structure of `.gsd/ROADMAP.md` and the task XML format (mentioned in community docs) are not fully documented. Without this, the bridge skill cannot reliably generate GSD-2-compatible plans. This needs to be resolved by inspecting actual GSD-2 output or reading its source code before implementation begins.

2. **GSD-2 API stability.** GSD-2 is relatively new (standalone CLI released 2025-2026). Whether `gsd headless auto`, `gsd headless query`, and the `.gsd/` directory format constitute a stable interface for external integration is unknown. Tight coupling to undocumented internals could break with GSD-2 updates.

3. **Interaction between `.claude/skills/` features and gw-skills' internal agent spawning.** The `worktree execute` command already dispatches multiple agents in parallel with dependency-wave ordering. Whether wrapping the entire skill in `context: fork` conflicts with this internal agent orchestration, or composes cleanly, is not documented anywhere. Testing is required before migration.

4. **Whether the 500-line ceiling is causative or correlative.** The research shows higher activation and instruction-following rates for shorter skill files, but gw-skills are invoked via explicit `/gw:` prefix, not via model-initiated activation. The activation rate benefit may be irrelevant for slash-command-invoked skills. The instruction-following quality benefit at smaller file sizes is plausible but not definitively proven for the skill file context specifically.

5. **Token budget impact of optimized descriptions at scale.** With 12+ skills, each description consumes part of the context window budget for skill descriptions. Whether the current descriptions collectively approach the documented 2% ceiling, and whether adding "USE WHEN" trigger conditions to all descriptions would push past it, has not been measured.

## Recommendations

1. **Immediate (Week 1): Decompose the six oversized skill files.** Extract error handling, output format templates, detailed spec blocks, and reference sections into `_shared/` or skill-specific supporting files. Target: every main skill file under 500 lines. Start with `saas-idea.md` (2,117 lines -- the most extreme case). This requires no architectural changes and has zero breaking-change risk.

2. **Immediate (Week 1): Fix the GSD v1 detection in preamble.md.** Add `.gsd/STATE.md` detection alongside the existing `.planning/config.json` check. This is a 5-line change that immediately unblocks model inheritance for GSD-2 users. Keep the v1 detection for backward compatibility.

3. **Short-term (Week 2-3): Build a `gw:gsd` bridge skill.** Create a dedicated skill that accepts a gw-skills report path, converts it to GSD-2 format, and optionally triggers execution. Update the `[g] GSD` action in existing skills to delegate to `gw:gsd` rather than inline the GSD invocation logic. This consolidates the 47 GSD references into one maintainable location.

4. **Short-term (Week 2-3): Rewrite skill descriptions with "USE WHEN" patterns.** Even though gw-skills are primarily slash-command-invoked, model-initiated activation will become increasingly important as Claude Code's autonomous capabilities expand. Optimized descriptions also serve as better documentation for users scanning the skill list.

5. **Medium-term (Month 2): Evaluate `.claude/skills/` migration after the Claude Code skills directory stabilizes.** The features unlocked (dynamic context injection, `context: fork`, model overrides) are valuable, but the migration risk to existing users is non-trivial. Prototype the migration in a branch, test thoroughly, and ship only when the breaking-change risk is fully characterized. Dynamic context injection for the preamble is the strongest motivator and should be the trigger for migration.

## Risks

1. **GSD-2 format coupling creates a maintenance burden.** If GSD-2's `.gsd/` format changes, the bridge skill breaks. Mitigation: keep the conversion logic in a single file, version the format assumption, and add a format-version check at the start of conversion.

2. **Skill decomposition could break existing skill behavior.** Moving sections to supporting files changes what Claude sees and when. If a section that was previously visible inline is now behind a "read this file" instruction, Claude may skip it under token pressure. Mitigation: test each decomposed skill end-to-end before shipping, and prefer inlining via dynamic context injection (when available) over "read and follow" references.

3. **The bridge skill adds indirection that slows the user flow.** Currently, selecting `[g]` in a skill output menu immediately launches GSD. With a bridge skill, the user would need to either invoke a separate command or the skill would delegate internally, adding latency. Mitigation: make the bridge invocation transparent -- the `[g]` action should call the bridge skill internally, not require the user to invoke it separately.

4. **Parallel optimization workstreams could conflict.** Decomposing skill files while simultaneously migrating GSD integration paths doubles the merge surface. Mitigation: sequence the work -- decomposition first (no GSD changes), then GSD bridge skill (operating on already-decomposed files).

5. **Over-optimization of descriptions may hit the token budget ceiling.** Adding "USE WHEN" clauses to all 12 skill descriptions expands the aggregate description payload. If descriptions collectively exceed the context budget, Claude Code may silently truncate them, which is worse than having shorter descriptions. Mitigation: measure the total description token count before and after optimization, and keep individual descriptions under 200 characters where possible.
