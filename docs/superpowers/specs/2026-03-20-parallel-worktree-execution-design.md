# Parallel Worktree Execution for gw-skills

**Date:** 2026-03-20
**Status:** Draft

## Problem

gw-skills that generate implementation code (saas-idea, compete, research, review-app) currently either produce prompts/plans for the user to execute manually, or spawn agents without isolation. There is no mechanism for skills to automatically build multiple independent features concurrently with TDD, each in its own worktree, and merge them together at the end.

## Solution

Add a `gw:worktree execute <manifest>` subcommand that reads a feature manifest, creates worktrees in dependency-ordered waves, dispatches one TDD agent per worktree, and merges each wave before proceeding to the next. Refactor all four code-generating skills to produce manifests and invoke this subcommand.

## Design Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Executor location | `gw:worktree execute` subcommand | Keeps all worktree orchestration in one skill; avoids duplication across 4 skills |
| Manifest format | Rich JSON with spec refs + test scaffolds | Skills already produce rich artifacts; agents get better results with more context |
| TDD approach | Agents use `superpowers:test-driven-development` | Skill already exists and is well-defined; avoids reinventing TDD instructions |
| Parallelism model | Dependency-wave execution | Independent features run in parallel; dependent features wait for their prerequisites |
| Execution opt-in | User prompt before execution (y/m/s) | Skills work without worktree execution; never forced |

---

## Component 1: `gw:worktree execute` Subcommand

New subcommand added to `.claude/commands/gw/worktree.md`.

### Invocation

```
/gw:worktree execute <manifest-path>
```

### Manifest Format

```json
{
  "project": "saas-mvp",
  "tech_stack": {
    "framework": "Next.js",
    "db": "PostgreSQL",
    "auth": "Google OAuth"
  },
  "features": [
    {
      "name": "auth-system",
      "description": "Implement OAuth2 login with Google provider",
      "spec_file": ".saas-ideas/deep-dive/TECH-SPEC.md#auth",
      "test_scaffolds": ["tests/unit/auth.test.ts"],
      "acceptance_tests": [
        "User can log in via Google",
        "Session persists across refresh"
      ],
      "dependencies": [],
      "files_hint": ["src/auth/", "tests/auth/"]
    },
    {
      "name": "billing",
      "description": "Stripe subscription billing integration",
      "spec_file": ".saas-ideas/deep-dive/TECH-SPEC.md#billing",
      "test_scaffolds": [],
      "acceptance_tests": [
        "User can subscribe to a plan",
        "Webhook handles payment events"
      ],
      "dependencies": ["auth-system"],
      "files_hint": ["src/billing/", "tests/billing/"]
    }
  ]
}
```

**Required fields:**
- `project` — name used for worktree branch prefixes (e.g., branch becomes `saas-mvp/auth-system`)
- `features` — array of feature objects

**Required feature fields:**
- `name` — worktree name and branch suffix
- `description` — what to build (passed to agent)
- `acceptance_tests` — human-readable criteria the agent must satisfy

**Optional feature fields:**
- `spec_file` — path to detailed spec file (agent reads it for context). Supports `#section` anchors for heading-based navigation.
- `test_scaffolds` — array of paths to pre-written test files (agent uses these as failing tests)
- `dependencies` — array of other feature names that must complete before this feature starts
- `files_hint` — directories/files this feature will touch (informational, helps user understand scope)

**Optional top-level fields:**
- `tech_stack` — object describing technologies (passed to each agent for context)

### Execution Flow

#### Step E1: Parse and Validate

1. Read the manifest JSON file
2. Validate required fields are present
3. Resolve `spec_file` paths — verify files exist. If a path has a `#section` anchor, verify the heading exists in the file.
4. Resolve `test_scaffolds` paths — verify files exist
5. If validation fails, report errors and stop

#### Step E2: Build Dependency Graph

Sort features into execution waves:

1. **Wave 1:** Features with no dependencies (or empty `dependencies` array)
2. **Wave 2:** Features whose dependencies are all in Wave 1
3. **Wave N:** Features whose dependencies are all in Waves 1 through N-1
4. If circular dependencies are detected, report the cycle and stop

Present the execution plan to the user:

```
Execution plan for "saas-mvp" (5 features, 3 waves):

Wave 1 (parallel):
  - auth-system — Implement OAuth2 login with Google
  - landing-page — Marketing landing page with pricing

Wave 2 (parallel, after Wave 1 merges):
  - core-feature — Core SaaS functionality
  - billing — Stripe subscription billing

Wave 3 (after Wave 2 merges):
  - polish — Error handling, loading states, final QA

Proceed? [y/n]
```

#### Step E3: Execute Waves

For each wave:

**3a: Create worktrees**

For each feature in the wave:
```
/gw:worktree create <project>/<feature-name> --purpose "<description>"
```

**3b: Dispatch agents**

For each feature in the wave, dispatch an agent using `Agent` tool with `isolation: "worktree"`:

The agent prompt includes:
- Feature name and description
- Content of `spec_file` (if provided — read and inline it, don't make the agent read it)
- Paths to `test_scaffolds` (if provided)
- `acceptance_tests` list
- `tech_stack` context
- Instruction to use `superpowers:test-driven-development`:
  - If `test_scaffolds` exist: "These test files contain failing tests. Run them to confirm they fail, then implement the minimal code to make them pass."
  - If no `test_scaffolds`: "Write failing tests first based on the acceptance tests below, then implement the minimal code to make them pass."
- Commit discipline: "Make atomic commits per test/implementation cycle. Use conventional commit messages prefixed with the feature name."
- Self-verification: "After all tests pass, run the full project test suite to check for regressions."
- Report format: Status (DONE/DONE_WITH_CONCERNS/NEEDS_CONTEXT/BLOCKED), tests passing count, files changed, any concerns.

All agents in a wave are dispatched in parallel (multiple `Agent` tool calls in one message, all with `run_in_background: true`).

**3c: Wait for agents**

Wait for all agents in the wave to complete. As each agent finishes, collect its report.

**3d: Handle results**

For each agent result:
- **DONE:** Feature ready for merge.
- **DONE_WITH_CONCERNS:** Surface concerns to user. Ask: "Feature `<name>` completed with concerns: <concerns>. Include in merge [y] or investigate [i]?"
- **NEEDS_CONTEXT:** Agent needs clarification. Surface the question to the user. After user responds, re-dispatch the agent with the additional context. If user cannot answer, treat as BLOCKED.
- **BLOCKED:** Feature skipped. Report blocker. Ask: "Feature `<name>` is blocked: <reason>. Skip [s] or abort wave [a]?"

**3e: Merge wave**

After all features in the wave are resolved:
1. Run `/gw:worktree merge-all` for the features in this wave
2. Each feature gets its own PR (existing merge-all behavior)
3. After all PRs in the wave are merged, proceed to the next wave

**3f: Clean up wave**

After wave merge completes:
```
/gw:worktree cleanup
```

Remove merged worktrees before starting the next wave (keeps disk usage bounded).

#### Step E4: Report

After all waves complete:

```
Execution complete for "saas-mvp":

Wave 1:
  - auth-system: DONE (12 tests passing, PR #15)
  - landing-page: DONE (5 tests passing, PR #16)

Wave 2:
  - core-feature: DONE (24 tests passing, PR #17)
  - billing: DONE_WITH_CONCERNS (8 tests passing, PR #18)
    Concern: Stripe webhook signature verification uses test key

Wave 3:
  - polish: DONE (3 tests passing, PR #19)

Total: 5/5 features merged, 52 tests passing
```

### Error Handling

- **Manifest validation fails:** Report which fields are missing or invalid, stop before creating any worktrees.
- **Circular dependencies:** Report the cycle (e.g., "A depends on B, B depends on A"), stop.
- **Agent BLOCKED in a wave:** Feature is skipped. If a later wave depends on a blocked feature, those dependent features are also skipped. Report the cascade.
- **Merge conflict during merge-all:** Existing merge-all behavior (stop, ask skip/retry/abort). If aborted, remaining waves are not executed.
- **All features in a wave blocked:** Skip the wave, proceed to the next (dependent features will also be skipped).
- **User aborts mid-execution:** Clean up created worktrees, report what was completed.

---

## Component 2: Agent Protocol

Each agent dispatched by `execute` follows a consistent protocol.

### What the Agent Receives

1. **Feature context:** name, description, tech_stack
2. **Spec content:** full text of `spec_file` (inlined in prompt, not a path to read)
3. **Test scaffolds:** paths to pre-written test files in the worktree
4. **Acceptance tests:** human-readable success criteria
5. **TDD instruction:** Use `superpowers:test-driven-development`

### What the Agent Does

1. **Read context** — Read spec content provided in prompt. If test scaffolds exist, read those files.
2. **TDD cycle** — Via `superpowers:test-driven-development`:
   - If test scaffolds exist: run them, confirm they fail, implement to make them pass
   - If no test scaffolds: write failing tests from acceptance criteria, implement to make them pass
3. **Atomic commits** — One commit per passing test cycle. Message format: `feat(<feature-name>): <what was implemented>`
4. **Self-verify** — After all acceptance tests pass, run the full project test suite
5. **Report** — Status, test count, files changed, concerns

### What the Agent Does NOT Do

- Does not create the worktree (execute subcommand does this)
- Does not merge (execute subcommand handles merge-all)
- Does not install dependencies (worktree creation handles project setup)
- Does not work on other features (one agent per feature, strict isolation)

### Agent Failure Handling

- **Tests won't pass after 3 implementation attempts:** Report BLOCKED with test output
- **Spec is ambiguous:** Report NEEDS_CONTEXT (execute subcommand surfaces to user)
- **Unexpected errors (git, filesystem, etc.):** Report BLOCKED with error details

---

## Component 3: Skill Refactors

Each skill gets a new step that generates a manifest and optionally invokes `/gw:worktree execute`.

### `gw:saas-idea` — New Phase 4 Step 5: Parallel Build

**Location:** After Phase 4 Step 4 (Implementation Bridge), before the existing planning dialog.

**What it does:**

1. Read `TECH-SPEC.md` and `IMPLEMENTATION-PROMPTS.md` from `.saas-ideas/deep-dive/`
2. Parse the 6 build phases into features:
   - Phase 1: auth (no dependencies)
   - Phase 2: core-feature (depends on auth)
   - Phase 3: data-api (depends on core-feature)
   - Phase 4: billing (depends on core-feature)
   - Phase 5: landing-page (no dependencies)
   - Phase 6: polish (depends on all others)
3. For each feature, extract description and acceptance criteria from `IMPLEMENTATION-PROMPTS.md`
4. Set `spec_file` to `TECH-SPEC.md` with appropriate `#section` anchor
5. Set `tech_stack` from the hardcoded stack (PostgreSQL, Google OAuth, Stripe, AWS, Terraform)
6. Write manifest to `.saas-ideas/build-manifest.json`
7. Ask user: "Build all features in parallel worktrees with TDD? [y] / Generate manifest only [m] / Skip [s]"
8. If [y]: invoke `/gw:worktree execute .saas-ideas/build-manifest.json`
9. If [m]: commit manifest, tell user they can run it later
10. If [s]: continue to existing planning dialog

**Dependency graph (4 waves):**
- Wave 1: auth, landing-page
- Wave 2: core-feature
- Wave 3: data-api, billing
- Wave 4: polish

### `gw:compete` — New Step 9.5: Build Manifest

**Location:** After Step 9 (TDD test scaffolds committed), before Step 10 (report synthesis).

**What it does:**

1. Read `SELECTED.json` for user's chosen features
2. For each selected feature, collect test scaffold paths from `.competitors/tests/`
3. Generate manifest with one feature per selected competitive feature
4. Pre-populate `test_scaffolds` with the paths to scaffolded test files
5. Set `acceptance_tests` from the feature's success criteria in the debate consensus
6. No dependencies between competitive features (all Wave 1 — they're independent additions)
7. Write manifest to `.competitors/build-manifest.json`
8. Ask: "Execute TDD implementation in parallel worktrees? [y] / Generate manifest only [m] / Skip to planning [s]"
9. If [y]: invoke `/gw:worktree execute .competitors/build-manifest.json`
10. If [m] or [s]: continue to existing Step 10

### `gw:research` — Enhanced Output Option 4: Parallel Prototype

**Location:** Step 6 output dialog, Option 4 (Prototype).

**What it does:**

1. Parse `CONSENSUS.md` for Tier 1 recommendations
2. Each Tier 1 recommendation becomes a feature in the manifest
3. Set `description` from the recommendation text
4. Set `acceptance_tests` from the recommendation's success criteria
5. Set `spec_file` to `CONSENSUS.md`
6. Determine dependencies between recommendations (if any are sequential)
7. Write manifest to `{RESEARCH_DIR}/build-manifest.json`
8. Ask: "Build prototype features in parallel worktrees with TDD? [y] / Single prototype agent [s] / Generate manifest only [m]"
9. If [y]: invoke `/gw:worktree execute {RESEARCH_DIR}/build-manifest.json`
10. If [s]: fall back to existing single-agent prototype behavior (unchanged)
11. If [m]: commit manifest

### `gw:review-app` — Refactored Step 5: Worktree Fix Execution

**Location:** Step 5 catch-and-fix phase, after the approval gate.

**What it does:**

1. After user approves fixes, group approved fixes into independent bundles by logical concern:
   - Security fixes (all security findings)
   - Performance fixes (all performance findings)
   - Test coverage gaps (all missing test findings)
   - Other fixes (clarity, maintainability, etc.)
2. For each bundle, derive `acceptance_tests` from the review findings (e.g., "XSS vulnerability in user input field is patched", "Response time for /api/users is under 200ms")
3. Set `spec_file` to `.analysis/REPORT.md`
4. No dependencies between fix bundles (all Wave 1)
5. Write manifest to `.analysis/fix-manifest.json`
6. Invoke `/gw:worktree execute .analysis/fix-manifest.json`
7. This replaces the current parallel background agents — worktree isolation is now used instead, and each fix agent also writes regression tests (TDD)

**Note:** review-app does NOT ask y/m/s because the user already approved fixes at the approval gate. Execution proceeds directly.

---

## Component 4: Argument and Routing Updates

### `gw:worktree` Updates

- Add `execute <manifest-path>` to the argument parsing
- Add `execute` row to the workflow routing table → Step 5
- Update `argument-hint` to include `execute`
- New Step 5 — Execute (the full flow described in Component 1)

### README Updates

- Add `execute` to the `gw:worktree` subcommand table
- Add manifest format documentation
- Update skill descriptions to mention parallel worktree execution

---

## Out of Scope

- Conflict resolution beyond what `/gw:worktree merge-all` already provides
- Cross-worktree shared state or communication between agents
- Auto-detecting features from code (skills produce the manifest explicitly)
- Modifying the `superpowers:test-driven-development` skill
- Changes to skills that don't generate code (log-patrol, weekly-review, workforce, audit-repo, update)

## Dependencies

- `gw:worktree` skill (just merged — provides create, status, merge-all, cleanup)
- `superpowers:test-driven-development` skill (existing)
- `Agent` tool with `isolation: "worktree"` support (existing in Claude Code)
- `gh` CLI (existing requirement)
