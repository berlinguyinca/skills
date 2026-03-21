# Parallel Worktree Execution Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `gw:worktree execute` subcommand for dependency-wave parallel execution with TDD agents, and refactor 4 code-generating skills to produce manifests and invoke it.

**Architecture:** The `execute` subcommand reads a JSON manifest of independent features, sorts them into dependency waves, creates worktrees per feature, dispatches TDD agents (using `superpowers:test-driven-development`) in parallel per wave, and merges each wave before proceeding to the next. Each skill generates a manifest from its existing artifacts and offers the user a choice to execute, save manifest only, or skip.

**Tech Stack:** Git worktrees, GitHub CLI, JSON manifests, Agent tool with `isolation: "worktree"`

**Spec:** `docs/superpowers/specs/2026-03-20-parallel-worktree-execution-design.md`

---

## File Structure

| Action | File | Responsibility |
|--------|------|---------------|
| Modify | `.claude/commands/gw/worktree.md` | Add `execute` subcommand (argument parsing, routing, Steps E1-E4) |
| Modify | `.claude/commands/gw/saas-idea.md` | Add Step 4.5: generate build manifest, invoke execute |
| Modify | `.claude/commands/gw/compete.md` | Add Step 9.5: generate build manifest from test scaffolds |
| Modify | `.claude/commands/gw/research.md` | Enhance Option 4: parallel prototype via manifest |
| Modify | `.claude/commands/gw/review-app.md` | Refactor Step 5d: worktree fix execution via manifest |
| Modify | `README.md` | Add `execute` subcommand docs, manifest format reference |

---

### Task 1: Add `execute` Subcommand to `gw:worktree`

**Files:**
- Modify: `.claude/commands/gw/worktree.md:4` (argument-hint)
- Modify: `.claude/commands/gw/worktree.md:38-41` (argument parsing)
- Modify: `.claude/commands/gw/worktree.md:45-50` (routing table)
- Modify: `.claude/commands/gw/worktree.md:396` (insert Step 5 before error handling)

This is the core new functionality. It adds the `execute <manifest-path>` subcommand with the full wave-based execution flow.

- [ ] **Step 1: Update frontmatter argument-hint**

In `.claude/commands/gw/worktree.md`, line 4, change:
```yaml
argument-hint: "create <name> [--purpose \"description\"] | status | merge-all | cleanup [name]"
```
to:
```yaml
argument-hint: "create <name> [--purpose \"description\"] | status | merge-all | cleanup [name] | execute <manifest-path>"
```

- [ ] **Step 2: Add `execute` to argument parsing**

In `.claude/commands/gw/worktree.md`, after line 41 (`If the first word is cleanup...`), add:
```markdown
- If the first word is `execute`, extract `<manifest-path>` (required)
```

- [ ] **Step 3: Add `execute` to routing table**

In `.claude/commands/gw/worktree.md`, in the routing table (after the `cleanup` row, around line 50), add:
```markdown
| `execute <manifest-path>` | Step 5 — Execute manifest |
```

- [ ] **Step 4: Add Step 5 — Execute manifest**

In `.claude/commands/gw/worktree.md`, insert a new section after Step 4 (Cleanup) and before the Error handling section (after line 396 `---`). This is the largest addition:

```markdown
## Step 5 — Execute manifest

### 5a: Parse and validate

1. Read the manifest JSON file at `<manifest-path>`
2. If the file does not exist or is not valid JSON, print the error and stop
3. Validate required fields:
   - `project` (string) must be present
   - `features` (array) must be present and non-empty
   - Each feature must have `name` (string), `description` (string), and `acceptance_tests` (array of strings)
4. For each feature with a `spec_file`:
   - Verify the file exists. If it has a `#section` anchor, verify the heading exists in the file.
   - If the file does not exist, warn: "spec_file '<path>' not found for feature '<name>' — agent will work from description only."
5. For each feature with `test_scaffolds`:
   - Verify each file exists
   - If a file does not exist, warn: "test scaffold '<path>' not found for feature '<name>' — agent will write tests from acceptance criteria."

### 5b: Build dependency graph

Sort features into execution waves:

1. Collect all feature names
2. For each feature, validate that all entries in `dependencies` refer to other feature names in the manifest. If a dependency is not found, print: "Feature '<name>' depends on '<dep>' which is not in the manifest." and stop.
3. Build waves:
   - **Wave 1:** Features with no dependencies (or empty `dependencies` array)
   - **Wave N:** Features whose dependencies are ALL in waves 1 through N-1
4. If circular dependencies are detected, report the cycle and stop
5. Present the execution plan:

```
Execution plan for "<project>" (<N> features, <W> waves):

Wave 1 (parallel):
  - <name> — <description>
  - <name> — <description>

Wave 2 (parallel, after Wave 1 merges):
  - <name> — <description>

...

Proceed? [y/n]
```

If the user declines, stop.

### 5c: Execute waves

For each wave in order:

**Create worktrees:**

For each feature in the wave, create a worktree:

```bash
# Uses existing Step 1 (create) logic internally
```

Create the worktree at `<worktree-dir>/<project>/<feature-name>` with branch `<project>/<feature-name>` and purpose set to the feature description.

Update the manifest (`.worktrees/manifest.json`) with each new worktree entry.

**Dispatch agents:**

For each feature in the wave, dispatch an agent using the `Agent` tool:

- Set `isolation: "worktree"`
- Set `run_in_background: true`
- Set `description` to: "Build <feature-name>"

Construct the agent prompt as follows:

```
You are implementing the feature "<name>" in an isolated git worktree.

## Feature
Name: <name>
Description: <description>

## Tech Stack
<tech_stack as formatted key-value pairs, or "Not specified" if absent>

## Specification
<Content of spec_file read and inlined here, or "No spec file provided — work from the description and acceptance tests." if absent>

## Test Scaffolds
<If test_scaffolds exist: "The following test files contain failing tests. Run them first to confirm they fail, then implement the minimal code to make them pass:" followed by the file paths>
<If no test_scaffolds: "No pre-written tests. Write failing tests first based on the acceptance tests below, then implement the minimal code to make them pass.">

## Acceptance Tests
<Each acceptance test as a numbered list>

## Instructions

1. Use `superpowers:test-driven-development` for all implementation work
2. If test scaffolds exist, run them first to confirm they fail
3. If no test scaffolds, write failing tests first from the acceptance tests
4. Implement the minimal code to make each test pass
5. Make atomic commits per test/implementation cycle
6. Use commit messages: feat(<name>): <what was implemented>
7. After all tests pass, run the full project test suite to check for regressions
8. Do NOT modify files outside your feature scope (<files_hint if provided>)

## Report

When done, report:
- **Status:** DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
- Tests passing count
- Files changed
- Any concerns or blockers
```

Dispatch all agents in the wave in parallel (multiple Agent tool calls in one message, all with `run_in_background: true`).

**Wait and handle results:**

Wait for all agents in the wave to complete. For each result:

- **DONE:** Feature is ready for merge. Log: "Feature '<name>' complete."
- **DONE_WITH_CONCERNS:** Surface concerns to user. Ask: "Feature '<name>' completed with concerns: <concerns>. Include in merge [y] or investigate [i]?"
  - `[y]`: include in merge
  - `[i]`: pause execution, let user investigate. After user confirms, continue.
- **NEEDS_CONTEXT:** Surface the agent's question to the user. After user responds, re-dispatch the agent with the additional context appended to the prompt. If user cannot answer, treat as BLOCKED.
- **BLOCKED:** Feature is skipped. Log: "Feature '<name>' BLOCKED: <reason>". Ask: "Skip and continue [s] or abort remaining waves [a]?"
  - `[s]`: mark as skipped, continue
  - `[a]`: stop processing this and all remaining waves

**Merge wave:**

After all features in the wave are resolved (done, skipped, or investigated):

1. For each feature that completed (DONE or DONE_WITH_CONCERNS accepted), the worktree already has commits on its branch
2. Run the merge-all logic (Step 3) for the worktrees in this wave — each feature gets its own PR via the existing merge-all flow
3. After all PRs in the wave are merged, proceed to the next wave

**Clean up wave:**

After wave merge completes, run cleanup (Step 4) for the merged worktrees to free disk space.

### 5d: Report

After all waves complete:

```
Execution complete for "<project>":

Wave 1:
  - <name>: DONE (<N> tests, PR #<N>)
  - <name>: DONE (<N> tests, PR #<N>)

Wave 2:
  - <name>: DONE_WITH_CONCERNS (<N> tests, PR #<N>)
    Concern: <concern text>
  - <name>: SKIPPED
    Reason: <blocker text>

Total: <N>/<N> features merged, <N> tests passing
Skipped: <N> (<names>)
```

If any features were skipped and later-wave features depended on them, note the cascade:

```
Cascade: <dep-name> was also skipped because it depends on <blocked-name>
```

Stop.
```

- [ ] **Step 5: Add execute error handling**

In the existing Error handling section (after the new Step 5), add these entries:

```markdown
- **Manifest validation fails:** Report which fields are missing or invalid. Do not create any worktrees.
- **Circular dependencies in manifest:** Report the cycle (e.g., "A depends on B, B depends on A"). Do not create any worktrees.
- **Agent BLOCKED in a wave:** Feature is skipped. If later-wave features depend on it, cascade-skip them too and report the chain.
- **All features in a wave blocked:** Skip the wave, proceed to the next. Cascade-skip dependent features.
- **User aborts mid-execution:** Clean up all worktrees created during this execution (both current wave and any from completed waves that were not yet cleaned up). Report what was completed.
```

- [ ] **Step 6: Commit**

```bash
git add .claude/commands/gw/worktree.md
git commit -m "feat(worktree): add execute subcommand for parallel TDD agent execution

Reads a JSON manifest of features, sorts into dependency waves,
creates worktrees per feature, dispatches TDD agents in parallel,
and merges each wave before proceeding to the next."
```

---

### Task 2: Add Build Manifest to `gw:saas-idea`

**Files:**
- Modify: `.claude/commands/gw/saas-idea.md:1986-1987` (insert new Step 4.5 between Step 4 and Step 5)

- [ ] **Step 1: Insert Step 4.5 — Parallel Build**

In `.claude/commands/gw/saas-idea.md`, after line 1985 (end of Step 4 error handling) and before line 1988 (`### Step 5 — Present Results`), insert:

```markdown
### Step 4.5 — Parallel Build (optional)

Generate a build manifest from the deep-dive artifacts and offer parallel worktree execution.

1. Read `TECH-SPEC.md` from `.saas-ideas/deep-dive/`
2. Read `IMPLEMENTATION-PROMPTS.md` from `.saas-ideas/deep-dive/`
3. Parse the 6 build phases into features:

| Feature | Dependencies | Description source |
|---------|-------------|-------------------|
| `auth` | none | Phase 1 from IMPLEMENTATION-PROMPTS.md |
| `landing-page` | none | Phase 5 from IMPLEMENTATION-PROMPTS.md |
| `core-feature` | `auth` | Phase 2 from IMPLEMENTATION-PROMPTS.md |
| `data-api` | `core-feature` | Phase 3 from IMPLEMENTATION-PROMPTS.md |
| `billing` | `core-feature` | Phase 4 from IMPLEMENTATION-PROMPTS.md |
| `polish` | `auth`, `core-feature`, `data-api`, `billing`, `landing-page` | Phase 6 from IMPLEMENTATION-PROMPTS.md |

4. For each feature:
   - Extract `description` from the corresponding phase prompt in IMPLEMENTATION-PROMPTS.md
   - Extract `acceptance_tests` from the phase's "Verify" or "Success criteria" section
   - Set `spec_file` to `.saas-ideas/deep-dive/TECH-SPEC.md`
5. Set `tech_stack` from the hardcoded stack: `{"db": "PostgreSQL", "auth": "Google OAuth", "payments": "Stripe", "cloud": "AWS", "iac": "Terraform", "domain": "codingandmore.net"}`
6. Set `project` to the slugified idea name from the deep-dive
7. Write manifest to `.saas-ideas/build-manifest.json`
8. Commit the manifest: `git add .saas-ideas/build-manifest.json && git commit -m "feat: generate build manifest for parallel execution"`

Ask the user:

```
Build manifest generated with 6 features in 4 waves:
  Wave 1: auth, landing-page
  Wave 2: core-feature
  Wave 3: data-api, billing
  Wave 4: polish

Build all features in parallel worktrees with TDD? [y] / Generate manifest only (already saved) [m] / Skip [s]
```

- `[y]`: invoke `/gw:worktree execute .saas-ideas/build-manifest.json`
- `[m]`: tell user: "Manifest saved. Run `/gw:worktree execute .saas-ideas/build-manifest.json` when ready."
- `[s]`: continue to Step 5
```

- [ ] **Step 2: Commit**

```bash
git add .claude/commands/gw/saas-idea.md
git commit -m "feat(saas-idea): add Step 4.5 for parallel build manifest generation

Generates build-manifest.json from TECH-SPEC and IMPLEMENTATION-PROMPTS,
offers parallel worktree execution with TDD agents."
```

---

### Task 3: Add Build Manifest to `gw:compete`

**Files:**
- Modify: `.claude/commands/gw/compete.md:807-808` (insert Step 9.5 between Step 9 and Step 10)

- [ ] **Step 1: Insert Step 9.5 — Build Manifest**

In `.claude/commands/gw/compete.md`, after line 806 (end of Step 9 git commit block) and before line 809 (`## Step 10 — Report Synthesis`), insert:

```markdown
## Step 9.5 — Build Manifest (optional)

If SKIP_TESTS is true, skip this step.

Generate a build manifest from the selected features and their test scaffolds.

1. Read `SELECTED.json` from `.competitors/` for the user's chosen features
2. Read `CONSENSUS.md` from `.competitors/debate/` for success criteria
3. For each selected feature:
   - Set `name` to the feature slug
   - Set `description` from the feature's debate consensus summary
   - Collect test scaffold paths from `.competitors/tests/<feature-slug>-*-manifest.md`
   - Set `test_scaffolds` to the actual test file paths referenced in the manifest files (parse the manifest to find the generated test files like `tests/unit/<slug>.test.*`, `tests/integration/<slug>.test.*`, etc.)
   - Extract `acceptance_tests` from the feature's success criteria in CONSENSUS.md
   - Set `dependencies` to empty (competitive features are independent additions)
4. Set `project` to `compete`
5. Set `tech_stack` by detecting the current project's stack (read package.json, Cargo.toml, etc.)
6. Write manifest to `.competitors/build-manifest.json`
7. Commit: `git add .competitors/build-manifest.json && git commit -m "feat: generate build manifest for competitive features"`

Ask:

```
Build manifest generated with <N> features (all Wave 1 — independent):
  - <feature-1> (<N> test scaffolds)
  - <feature-2> (<N> test scaffolds)
  ...

Execute TDD implementation in parallel worktrees? [y] / Generate manifest only [m] / Skip to report [s]
```

- `[y]`: invoke `/gw:worktree execute .competitors/build-manifest.json`
- `[m]`: tell user: "Manifest saved. Run `/gw:worktree execute .competitors/build-manifest.json` when ready."
- `[s]`: continue to Step 10

---
```

- [ ] **Step 2: Commit**

```bash
git add .claude/commands/gw/compete.md
git commit -m "feat(compete): add Step 9.5 for build manifest from test scaffolds

Generates build-manifest.json from selected features and their
TDD test scaffolds, offers parallel worktree execution."
```

---

### Task 4: Enhance Prototype Option in `gw:research`

**Files:**
- Modify: `.claude/commands/gw/research.md:1117-1138` (replace Option 4 content)

- [ ] **Step 1: Replace Option 4 content**

In `.claude/commands/gw/research.md`, replace lines 1117-1138 (the entire Option 4 block, from `### Option 4: Prototype` through `Tell the user what was created and how to run it.`) with:

```markdown
### Option 4: Prototype

Parse CONSENSUS.md to identify independent Tier 1 recommendations that can be prototyped.

1. Read `CONSENSUS.md` from `{RESEARCH_DIR}/`
2. Identify Tier 1 recommendations (highest priority findings)
3. For each Tier 1 recommendation:
   - Set `name` to a slugified version of the recommendation title
   - Set `description` from the recommendation text
   - Extract `acceptance_tests` from the recommendation's success criteria or expected outcome
   - Set `spec_file` to `{RESEARCH_DIR}/CONSENSUS.md`
   - Determine `dependencies` between recommendations (if recommendation B builds on recommendation A, B depends on A). If no ordering is implied, all are independent.
4. Set `project` to `research-<slug>` (using the research question slug)
5. Set `tech_stack` from project context (if PROJECT_CONTEXTUAL) or from the recommendations
6. Write manifest to `{RESEARCH_DIR}/build-manifest.json`
7. Commit: `git add {RESEARCH_DIR}/build-manifest.json && git commit -m "feat: generate prototype build manifest from research"`

Ask:

```
Build manifest generated with <N> prototype features (<W> waves):
  Wave 1: <names>
  ...

Build prototype features in parallel worktrees with TDD? [y] / Single prototype agent (original behavior) [s] / Generate manifest only [m]
```

- `[y]`: invoke `/gw:worktree execute {RESEARCH_DIR}/build-manifest.json`
- `[s]`: fall back to original single-agent behavior:
  - Launch a single foreground agent (`subagent_type="general-purpose"`) with CONSENSUS.md findings
  - Agent writes working code to `{RESEARCH_DIR}/prototype/`
  - Keep it minimal — proof of concept, not production code
  - Tell the user what was created and how to run it
- `[m]`: tell user: "Manifest saved. Run `/gw:worktree execute {RESEARCH_DIR}/build-manifest.json` when ready."
```

- [ ] **Step 2: Commit**

```bash
git add .claude/commands/gw/research.md
git commit -m "feat(research): enhance Option 4 with parallel prototype via manifest

Parses Tier 1 recommendations into build manifest features,
offers parallel worktree execution with TDD. Falls back to
single-agent prototype if user prefers."
```

---

### Task 5: Refactor Fix Execution in `gw:review-app`

**Files:**
- Modify: `.claude/commands/gw/review-app.md:582-600` (replace Step 5d fix agent spawning)

- [ ] **Step 1: Replace Step 5d with manifest-based execution**

In `.claude/commands/gw/review-app.md`, replace the content of `### 5d. Spawn fix agents` (starting at line 582) through the end of the fix agent instructions (find where the next `###` heading begins — this is likely `### 5e` or `### 5f`). Replace with:

```markdown
### 5d. Generate fix manifest and execute

Group approved fixes into independent bundles by logical concern:

| Bundle | Contains |
|--------|----------|
| `security-fixes` | All CRITICAL and WARNING security findings |
| `performance-fixes` | All performance findings |
| `test-coverage` | All missing test / coverage gap findings |
| `quality-fixes` | All clarity, maintainability, and other findings |

Skip any bundle that has zero approved fixes.

For each bundle:
- Set `name` to the bundle slug (e.g., `security-fixes`)
- Set `description` to a summary of all fixes in the bundle
- Derive `acceptance_tests` from each review finding:
  - Security: "XSS vulnerability in <file>:<line> is patched", "SQL injection in <file>:<line> is parameterized"
  - Performance: "Response time for <endpoint> improved", "<function> avoids N+1 query"
  - Test coverage: "Coverage for <module> reaches 80%", "Critical path <X> has regression test"
  - Quality: "Dead code in <file> removed", "Function <X> has clear naming"
- Set `spec_file` to `.analysis/REPORT.md`
- Set `dependencies` to empty (fix bundles are independent)
- Set `files_hint` to the target files for each bundle

Set `project` to `review-fix`.

Write manifest to `.analysis/fix-manifest.json`.

Commit: `git add .analysis/fix-manifest.json && git commit -m "feat: generate fix manifest from review findings"`

Invoke `/gw:worktree execute .analysis/fix-manifest.json` directly (no y/m/s prompt — user already approved fixes at the approval gate in Step 5c).

After execution completes, continue to the next step (simplification, test generation, etc.).
```

- [ ] **Step 2: Commit**

```bash
git add .claude/commands/gw/review-app.md
git commit -m "refactor(review-app): replace fix agents with manifest-based worktree execution

Groups fixes into logical bundles (security, performance, test coverage,
quality), generates fix-manifest.json, invokes gw:worktree execute
for parallel TDD-based fix implementation."
```

---

### Task 6: Update README

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Add `execute` to the `gw:worktree` command synopsis**

In `README.md`, in the `/gw:worktree` section, update the command synopsis to add `execute`:

```
/gw:worktree create <name> [--purpose "description"]
/gw:worktree status
/gw:worktree merge-all
/gw:worktree cleanup [name]
/gw:worktree execute <manifest-path>
```

- [ ] **Step 2: Add `execute` to the subcommand table**

Add a new row to the subcommand table:

```markdown
| `execute <manifest>` | Read a feature manifest, create worktrees in dependency waves, dispatch TDD agents in parallel, merge each wave |
```

- [ ] **Step 3: Add manifest format documentation**

After the "Concurrent development workflow" section, add:

```markdown
#### Parallel execution with manifests

Skills like `/gw:saas-idea`, `/gw:compete`, `/gw:research`, and `/gw:review-app` can generate build manifests that describe independent features. The `execute` subcommand reads these manifests and builds all features in parallel with TDD.

```json
{
  "project": "my-project",
  "tech_stack": {"framework": "Next.js", "db": "PostgreSQL"},
  "features": [
    {
      "name": "auth",
      "description": "OAuth2 login",
      "spec_file": "docs/SPEC.md",
      "test_scaffolds": ["tests/auth.test.ts"],
      "acceptance_tests": ["User can log in"],
      "dependencies": [],
      "files_hint": ["src/auth/"]
    }
  ]
}
```

Features are sorted into dependency waves and executed in parallel per wave. Each agent uses TDD (`superpowers:test-driven-development`) and gets its own isolated worktree.
```

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "docs: add gw:worktree execute and manifest format to README

Documents the execute subcommand, manifest JSON format,
and parallel execution workflow."
```
