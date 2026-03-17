---
name: merge-it
description: Ship the current changes end-to-end: branch, PR, review, fix, present, merge
---

## Step 0 — Update check

Resolve the gw-skills repo directory and run its update check script:

```bash
GW_REPO="$(cd "$(readlink ~/.claude/commands/gw)/../../.." 2>/dev/null && pwd)" || GW_REPO="$HOME/.gw-skills"
bash "$GW_REPO/check-update.sh" 2>/dev/null || true
```

If the output contains `UPDATE_AVAILABLE`, tell the user how many commits behind they are and ask: "gw-skills has updates available. Run /gw:update to install them, or continue?" If they want to update, invoke `/gw:update` and stop. Otherwise continue. If the script is missing or fails, skip silently.

---

Ship the current changes end-to-end: branch, PR, review, fix, present, merge.

Follow these steps IN ORDER. Do not skip steps or proceed past approval gates without explicit user confirmation.

### Step 1: Create a branch

- Determine a descriptive branch name from the staged/unstaged changes (e.g., `fix/path-rewriter-escaping` or `feat/auto-update`)
- Run: `git checkout -b <branch-name>`
- Stage and commit all relevant changes with a clear commit message

### Step 2: Push the branch

- Run: `git push -u origin <branch-name>`

### Step 3: Create a PR

- Detect the default branch (`main` or `master`) using `git remote show origin`
- Create a PR using `gh pr create` against the default branch
- Include a summary and test plan in the PR body
- Show the user the PR URL

### Step 4: Review the PR

- Run: `gh pr diff <pr-number>`
- Perform a thorough code review covering:
  - Correctness and edge cases
  - Security concerns (injection, XSS, secrets, OWASP top 10)
  - Performance and efficiency
  - Code clarity and maintainability
  - Test coverage gaps
  - Cross-platform issues (if applicable)
- Present the review as a numbered list of findings with severity (critical/warning/suggestion)

### Step 5: Generate a fix plan

- For each review finding, propose a concrete fix with file paths and approach
- Group fixes by file
- Estimate scope (one-liner vs multi-file change)
- Present the full plan to the user in a clear table or list

### Step 6: APPROVAL GATE — Stop and wait

**IMPORTANT: You MUST stop here and ask the user to approve the plan.**

Present the plan summary and ask:
> "Here's the plan to address the review findings. Approve all, select specific items, or reject?"

- If the user approves all: proceed to step 7
- If the user selects specific items: only implement those
- If the user rejects: skip to step 8 (merge as-is) or abort entirely based on user preference
- Do NOT proceed without explicit approval

### Step 7: Execute fixes and generate presentation

#### 7a: Execute the approved fixes
- Implement each approved fix
- Run tests if a test runner is available (`npm test`, `vitest`, `pytest`, etc.)
- Commit fixes with a clear message referencing the review
- Push the updated branch: `git push`

#### 7b: Generate a PowerPoint presentation

Create a `.pptx` file using Python and the `python-pptx` library. Install it if needed: `pip install python-pptx`

Write and execute a Python script that builds the presentation with these requirements:

**Theme:**
- Light background: white (`#FFFFFF`) or very light gray (`#F5F5F5`)
- Primary text: dark gray (`#333333`)
- Accent color: soft blue (`#4A90D9`)
- Secondary accent: light green (`#27AE60`) for improvements
- Font: Calibri or Arial throughout
- Slide dimensions: widescreen 16:9

**Slide structure:**

1. **Title slide** — Project name, "What Changed & Why", date, branch name
2. **Overview slide** — Bullet summary of all changes in plain English (no code jargon). Use a subtitle like "Here's what we improved"
3. **For each significant change**, create a slide with:
   - A plain-English title (e.g., "We made the app faster" not "Optimized O(n²) loop")
   - Before/After comparison — use a simple two-column layout or visual metaphor
   - A "Why this matters" callout box explaining the user-facing benefit
   - Add a simple visual where helpful:
     - Use colored shapes (rectangles, arrows, circles) to illustrate flow changes
     - Use simple bar charts or comparison graphics for performance improvements
     - Use checkmark/X icons (✓/✗) for fixed vs broken states
     - Use arrow diagrams for architectural changes
4. **Impact summary slide** — A visual scorecard:
   - Number of issues found vs fixed
   - Categories addressed (security, performance, clarity, etc.)
   - Use colored boxes or a simple chart
5. **Closing slide** — "Ready for production" with the PR link and merge status

Create the `doc/` directory in the project root if it doesn't exist. Save the file as `doc/changes-presentation-<branch-name>.pptx`.

Tell the user where the file was saved.

### Step 8: Merge into default branch

- Ask the user for final confirmation: "Ready to merge PR #<number> into <default-branch>?"
- If confirmed, run: `gh pr merge <pr-number> --merge --delete-branch`
- Show the merge result and final status
- If not confirmed, leave the PR open and inform the user

### Error handling

- If any step fails, show the error clearly and ask the user how to proceed
- Never force-push or use destructive git operations without asking
- If `python-pptx` is unavailable and cannot be installed, fall back to creating an HTML presentation file instead
