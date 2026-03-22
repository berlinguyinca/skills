## Skill Recommendations & Auto-Install

### 9a. Detect skill relevance signals

Scan the project for signals that map to specific skills. Run these checks in parallel:

| Signal | Detection | Recommended Skill | Category |
|--------|-----------|-------------------|----------|
| No test-before-code git patterns | Git log analysis (same as coding-defaults enforcer) | `superpowers:test-driven-development` | Process |
| No E2E/Playwright tests | Missing playwright.config, no @playwright/test dep | `superpowers:test-driven-development` | Process |
| Complex multi-step task ahead (from Priority 1 items) | 3+ Priority 1 items with effort > Quick Win | `superpowers:writing-plans` | Process |
| Multiple independent subsystems | 3+ specialist dimensions flagged CRITICAL | `superpowers:dispatching-parallel-agents` | Process |
| Bug or failure patterns detected | Test failures, error patterns in logs | `superpowers:systematic-debugging` | Process |
| No PR review workflow | Missing `.github/CODEOWNERS`, no PR templates | `superpowers:requesting-code-review` | Process |
| Active feature branches | 2+ non-default branches | `/gw:worktree create <name>` | Process |
| No presentation/docs workflow | No `docs/gw/` directory with `.pptx` files, no merge-it usage | `gw:merge-it` | Workflow |
| No periodic review | No weekly review config at `~/.config/gw-skills/weekly-review.json` | `gw:weekly-review` | Workflow |
| SaaS signals detected (from Step 1) | APP_TYPE = saas or SaaS signals present | `gw:saas-idea` | Workflow |
| No project planning | Missing `.planning/` directory | `superpowers:writing-plans` or `gsd:new-project` | Planning |
| Existing project with stale phases | `.planning/` exists but no recent phase activity | `gsd:progress` | Planning |
| No CI/CD pipeline | Missing `.github/workflows/`, `Jenkinsfile`, `.gitlab-ci.yml` | `superpowers:verification-before-completion` | Process |
| Fixes applied in Step 5 (code changed, benefits from ongoing simplification) | Any fix agents ran and produced fix summaries | `superpowers:code-simplifier` | Process |
| Complex architectural issues (3+ CRITICAL findings across different dimensions) | 3+ dimensions have CRITICAL-severity findings | `superpowers:brainstorming` | Process |

### 9b. Check what's already available

1. Check which gw-skills are installed: `ls ~/.claude/commands/gw/ 2>/dev/null`
2. Check which GSD skills are installed: `ls ~/.claude/commands/gsd/ 2>/dev/null`
3. Check if superpowers are available: glob for `~/.claude/plugins/cache/claude-plugins-official/superpowers/` or check if any `superpowers:*` skills appear in the skill list. Superpowers are globally available when installed — they don't need per-project setup.
4. Read the project's `CLAUDE.md` if it exists — check if any skill references are already documented there

Filter out skills that are already installed or referenced in CLAUDE.md.

### 9c. Present recommendations

Display a recommendations table, grouped by category:

```
Recommended Skills for {project_name}:

Process Skills:
  1. [INSTALL] superpowers:test-driven-development
     Why: No TDD patterns detected, 3 test files have ceremonial assertions
  2. [AVAILABLE] superpowers:writing-plans
     Why: 5 Priority 1 items need coordinated implementation
  3. [INSTALL] superpowers:systematic-debugging
     Why: Test failures detected in 2 modules

Workflow Skills:
  4. [INSTALL] gw:merge-it
     Why: No presentation workflow — changes go undocumented
  5. [AVAILABLE] gw:weekly-review
     Why: Already installed, recommend configuring for this repo

Planning Skills:
  6. [INSTALL] gsd:new-project
     Why: No project planning structure detected

[INSTALL] = not yet referenced in project | [AVAILABLE] = installed but not used

Install all recommended [a], select by number [1,3,6], skip [s]?
```

- **[INSTALL]** means the skill exists in the user's environment but isn't referenced in the project's CLAUDE.md
- **[AVAILABLE]** means it's already referenced or the user already uses it

### 9d. Install selected skills

For skills the user approves:

**For superpowers skills:** These are already available globally. "Installing" means adding a reference to the project's `CLAUDE.md` so they're top-of-mind. Append to `CLAUDE.md` (create if it doesn't exist):

```markdown
## Recommended Skills

The following skills were identified by `gw:review-app` as beneficial for this project:

- `superpowers:test-driven-development` — Use TDD for all new features and bug fixes
- `superpowers:writing-plans` — Plan multi-step tasks before coding
- `superpowers:systematic-debugging` — Use scientific debugging for failures
```

**For gw: skills:** gw-skills is necessarily already installed (the user is running `gw:review-app`). Just add the recommended skill references to CLAUDE.md so they're discoverable for the project.

**For gsd: skills:** Check if superpowers are available first (glob for `~/.claude/plugins/cache/claude-plugins-official/superpowers/` or check if any `superpowers:*` skills appear in the skill list).
- If superpowers are available: prefer recommending the superpowers equivalent (e.g., `superpowers:writing-plans`) as the primary option, and mention GSD as an alternative.
- Check if GSD is installed (`~/.claude/commands/gsd/` exists).
  - If yes: GSD skills are already available, add to CLAUDE.md recommendations as an alternative.
  - If not: tell the user: "GSD not installed — use `superpowers:writing-plans` as the primary planning alternative, or install GSD for full project management support."

### 9e. Configure thinking mode

If the project has complex architectural issues (3+ CRITICAL findings across different dimensions), suggest enabling extended thinking:

```
This project has complex cross-cutting issues. For best results when implementing fixes:
- Use extended thinking mode if available (model-dependent)
- Pair with superpowers:brainstorming before major architectural changes
- Use superpowers:writing-plans for multi-phase implementations
```

### 9f. Summary

Print a final summary:

```
Skills configured for {project_name}:
  - {N} skills recommended
  - {N} references added to CLAUDE.md
  - {N} already available (no action needed)

Next steps:
  - Run /gw:merge-it when ready to ship changes
  - Use superpowers:writing-plans to create a structured implementation plan (or /gsd:new-project if GSD is installed)
  - Use superpowers:test-driven-development for all new code
```

---

## Step 9.5 — Persona Contribution

Skip this step if `CREATED_PERSONAS` is empty.

Present the created personas:

```
New persona(s) created during this run:
  - {Name1} (workforce/{slug1}.md)
  - {Name2} (workforce/{slug2}.md)

Contribute to gw-skills defaults? This creates a PR to share with all users.
  Contribute [y], skip [n]?
```

If the user selects `[y]`:

1. Save the current directory and branch
2. `cd $GW_REPO`
3. Check for uncommitted changes — if the working tree is dirty, ask: "gw-skills repo has uncommitted changes. Stash them? [y/n]" If yes, `git stash`. If no, abort contribution.
4. Create a branch:
   - Single persona: `persona/{slug}`
   - Multiple personas: `persona/batch-YYYY-MM-DD`
5. For each persona in `CREATED_PERSONAS`:
   - Copy `workforce/{slug}.md` -> `workforce/_defaults/{slug}.md`
6. Stage and commit:
   ```bash
   git add workforce/_defaults/
   git commit -m "feat(workforce): add {Name} persona

   Background: {background}
   Created inline during gw:review-app run."
   ```
   (For multiple personas, list all names in the commit message.)
7. Push: `git push -u origin {branch}`
8. Create PR:
   ```bash
   gh pr create --title "Add {Name} persona to defaults" --body "$(cat <<'EOF'
   ## New Persona: {Name}

   **Background:** {background}
   **Skills used by:** gw:compete, gw:research, gw:review-app, gw:saas-idea
   **Created:** Inline during gw:review-app run on {date}

   Generated with [Claude Code](https://claude.com/claude-code)
   EOF
   )"
   ```
9. If stashed in step 3, `git stash pop`
10. Return to the original directory and branch
11. Print the PR URL
