# Execute Subcommand — Manifest Format, Agent Dispatch, Dependency-Wave Execution

This module is read and followed by `gw:worktree execute <manifest-path>`.

---

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

For each feature in the wave, create a worktree using the existing Step 1 (create) logic:

- Worktree path: `<worktree-dir>/<project>/<feature-name>`
- Branch: `<project>/<feature-name>`
- Purpose: the feature description

Update the worktree manifest (`.worktrees/manifest.json`) with each new entry.

**Dispatch agents:**

For each feature in the wave, dispatch an agent using the `Agent` tool:

- Set `isolation: "worktree"`
- Set `run_in_background: true`
- Set `description` to: "Build <feature-name>"

Construct the agent prompt:

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

1. For features that completed (DONE or DONE_WITH_CONCERNS accepted), the worktree already has commits on its branch
2. Run the merge-all logic (Step 3) for the worktrees in this wave — each feature gets its own PR
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

---

## Error handling (execute-specific)

- **Manifest validation fails:** Report which fields are missing or invalid. Do not create any worktrees.
- **Circular dependencies in manifest:** Report the cycle (e.g., "A depends on B, B depends on A"). Do not create any worktrees.
- **Agent BLOCKED in a wave:** Feature is skipped. If later-wave features depend on it, cascade-skip them too and report the chain.
- **All features in a wave blocked:** Skip the wave, proceed to the next. Cascade-skip dependent features.
- **Merge conflict during wave merge-all:** Existing merge-all behavior applies (stop, ask skip/retry/abort). If aborted, remaining waves are not executed.
- **User aborts mid-execution:** Clean up all worktrees created during this execution. Report what was completed.
