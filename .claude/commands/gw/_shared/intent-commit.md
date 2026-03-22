# Intent Commit

Shared module for writing and committing a `.gw-intent.md` file that documents what this skill execution did and why. This file enables `gw:merge-prs` to understand the purpose of each branch without re-analyzing all code.

The calling skill sets `SKILL_NAME`, `GW_BRANCH`, `BASE_BRANCH`, and `BRANCH_CREATED` before including this module.

---

## Skip Check

If `BRANCH_CREATED` is `false`, skip this module entirely. Nothing to commit.

---

## Write Intent File

Write `.gw-intent.md` to the project root with this structure:

```markdown
# gw:<SKILL_NAME> Intent

**Branch:** <GW_BRANCH>
**Base:** <BASE_BRANCH>
**Date:** <current ISO-8601 date>
**Skill:** gw:<SKILL_NAME>

## Purpose
<1-3 sentences describing what this skill execution accomplished, derived from
the skill's arguments ($ARGUMENTS) and the work done during execution>

## Key Decisions
<bullet list of significant decisions made during execution, e.g.:
- Selected research personas: X, Y, Z
- Focused analysis on security dimension
- Chose to implement prototype in Python>

## Files Changed
<output of: git diff --stat ${BASE_BRANCH}..HEAD>

## Plan Files
<list any superpowers/GSD plan/spec files created during this execution with
a one-line summary of each, e.g.:
- docs/superpowers/specs/2026-03-21-auth-design.md — Authentication system design
- .planning/phases/01-setup/01-01-PLAN.md — Initial setup plan

If none: "None">

## Dependencies
<any detected dependencies on other branches/PRs, or "None".
Look for references to other gw/ branches in plan files or arguments.>
```

---

## Commit

```bash
git add .gw-intent.md
git commit -m "docs(gw): add intent file for gw:${SKILL_NAME} execution

Branch: ${GW_BRANCH}
Skill: gw:${SKILL_NAME}

This file documents the intent and decisions for this skill execution.
Used by gw:merge-prs to understand branch purpose during integration."
```

If the commit fails (e.g., nothing to commit), warn but do not abort the skill.
