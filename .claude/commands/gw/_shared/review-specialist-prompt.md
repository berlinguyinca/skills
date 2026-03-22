## Specialist Agent Prompt Template

For each specialist, build the prompt from this template:

```
You are a {SPECIALIST_NAME} analyzing a {APP_TYPE} application.

{STACK_CONTEXT}

{FILE_SCOPE_BLOCK}

Focus on these categories: {CATEGORIES}

Discover by reading relevant source files, configs, and patterns.
Verify every file you cite exists using Glob/Grep.

RULES:
- You are analyzing the codebase in the current working directory.
- Only cite files that actually exist — use Glob and Grep to verify before citing.
- Be specific: include file paths with line numbers (path/to/file.ts:42).
- Be actionable: every finding must have a concrete recommendation.
- Use severity levels: CRITICAL (must fix — security hole, data loss, broken UX), WARNING (should fix — degraded experience, tech debt, cost waste), INFO (nice to have — polish, optimization).
- Code duplication is always a red flag — flag duplicated logic/patterns as WARNING with specific file pairs.
- Test coverage below the coverage threshold (80%) is CRITICAL. Estimate coverage by comparing test files to source files. Flag untested critical paths. Coverage enforcement in Step 5g will generate tests for uncovered code — list the TOP 10 uncovered files/functions to feed that step (Step 5g will pick the top 5 most critical from that list).
- If a dimension does not apply to this codebase, write a short "Not Applicable" report explaining why.
- Write your report to the specified output file using the Write tool.

Write your report in this exact format:

# {Dimension} Analysis

**Date:** {today's date}
**Stack:** {detected stack summary}
**App Type:** {APP_TYPE}
**Severity Summary:** {N} critical, {N} warning, {N} info

## {Category Name}

### [CRITICAL] {Finding title}
**Files:** `path/to/file.ts:42`, `other/file.py:15`
**Issue:** {clear description of the problem}
**Impact:** {why this matters — what breaks, what's at risk}
**Recommendation:** {specific steps to fix}

### [WARNING] {Finding title}
...

(repeat for all findings across all categories)

---
**Verdict:** {One sentence overall assessment of this dimension}

Write your report to .analysis/{NN}-{SLUG}.md
```

### Specialist-specific prompt additions

When building the agent prompt for a specialist, check if the persona file has content after the frontmatter (`prompt_additions` from Step 1e). If it does, **append** that content after the generic template as specialist-specific instructions.

For example, the SEO Specialist, Test Sense-Checker, and Coding Defaults Enforcer persona files include additional instructions that are appended to their agent prompts automatically.

When FILE_SCOPE is non-empty, the FILE_SCOPE_BLOCK is:
```
SCOPE: Focus analysis on these recently-changed files and their immediate
dependencies. Reference other files for context, but prioritize scoped files.
Files: {FILE_SCOPE}
```
When FILE_SCOPE is empty, omit the block entirely.

---

## Code Simplification Agent (Step 5f)

Skip this sub-step if SKIP_SIMPLIFY is true OR no fixes were applied in Step 5d.

Launch a **foreground** Agent (`subagent_type="code-simplifier:code-simplifier"`) with this prompt:

```
You are simplifying code that was just modified by automated fix agents.

Read all .analysis/fixes/*-fix-summary.md files to identify which files were modified.

For each modified file:
1. Read the file
2. Review for: duplicated logic, unnecessary complexity, inconsistent style, dead code, missed utility reuse
3. Apply minimal, obvious simplifications using the Edit tool
4. Preserve all existing behavior — do not change semantics

RULES:
- Only touch files that were modified by fix agents (listed in fix summaries)
- Do NOT refactor unrelated code
- Do NOT add comments or documentation
- Keep changes minimal and obvious — if a simplification is debatable, skip it
- Prefer removing dead code and deduplicating over restructuring

After simplifications, write .analysis/fixes/simplification-summary.md containing:
- Files simplified with brief description of each change
- Total lines removed/changed
- "No simplifications needed" if nothing was worth changing
```

After simplification completes, re-run the test suite (same detection as Step 5e). If tests fail, revert all simplifications using `git checkout -- {files}` and note "Simplifications reverted due to test failure" in the summary.

---

## Coverage Enforcement Agent (Step 5g)

Skip this sub-step if SKIP_TESTING is true OR SKIP_TEST_GEN is true.

Read the QA Engineer's report from `.analysis/*-testing-qa.md` for coverage data.

**If coverage >= 80%:** Print "Coverage is at {N}% — above 80% threshold, skipping test generation." and proceed to Step 5h.

**If coverage < 80%:**

1. **Select targets:** Pick up to 5 lowest-coverage critical-path files from the QA report. Prioritize: auth, payment, data mutation > utility, formatting.

2. **Detect test patterns:** Read 2-3 existing test files to identify: test framework (Jest, pytest, Go testing, etc.), naming conventions, directory structure, assertion style, mock patterns.

3. **Generate tests:** Launch up to 5 parallel **background** Agents (`subagent_type="general-purpose"`, `run_in_background=true`), each writing tests for one uncovered module:

```
You are a test writer generating meaningful tests for an uncovered module.

Target file: {FILE_PATH}
Test framework: {DETECTED_FRAMEWORK}
Test directory: {DETECTED_TEST_DIR}
Naming convention: {DETECTED_NAMING}

Write tests that:
- Test actual behavior, not implementation details
- Cover the happy path + 2 edge cases minimum
- Follow existing test patterns exactly (framework, assertions, file naming)
- Mock only external dependencies (network, filesystem, databases)
- Do NOT mock internal modules
- Write the test file to {TEST_FILE_PATH}

After writing, list what you tested and why in a brief summary.
```

4. **Verify tests:** After all test-generation agents complete, run the test suite. For each failing new test:
   - Spawn a fix agent (1 retry attempt)
   - If still failing after retry, delete the test file
   - Note deleted tests in summary

5. **Measure delta:** If a coverage tool is available, re-run coverage and report the delta (before -> after).

6. **Write summary:** Write `.analysis/fixes/coverage-enforcement-summary.md` containing:
   - Coverage before and after (if measurable)
   - Tests generated: file path, what it tests, pass/fail status
   - Tests deleted (if any) with reason
   - Remaining coverage gap (if still < 80%)
