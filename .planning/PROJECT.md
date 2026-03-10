# MOS (My Own Stuff)

## What This Is

A personal collection of Claude Code skills for automating day-to-day tasks. The first skill, `mos:progress`, generates a PowerPoint presentation summarizing a week's worth of GitHub activity across the `metabolomics-us` organization, formatted for a recurring Wednesday IT meeting.

## Core Value

One command produces a meeting-ready presentation that accurately captures the week's development work — no manual digging through GitHub required.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Skill `mos:progress` is invocable as a Claude Code slash command
- [ ] Queries GitHub `metabolomics-us` org for the user's PRs and commits
- [ ] Time window: previous Wednesday through Tuesday noon (7-day rolling window aligned to meeting cadence)
- [ ] Categorizes activity into bug fixes, new features, and new tools
- [ ] Generates a PowerPoint (.pptx) file saved locally
- [ ] PowerPoint includes summary statements with key highlights
- [ ] PowerPoint includes charts (commit/PR counts by repo, bug vs feature breakdown)
- [ ] PowerPoint includes a timeline of when work landed during the week
- [ ] PowerPoint includes tables with PR details (title, repo, status, description)
- [ ] Presentation is clean and simple — professional but not overdesigned

### Out of Scope

- Email delivery — user handles distribution manually
- Automated scheduling (cron/launchd) — user invokes skill manually
- Covering other org members' activity — only the user's own PRs/commits
- Google Slides or PDF output — PowerPoint only
- Other skills beyond `mos:progress` — will be added in future milestones

## Context

- The user has a weekly IT meeting every Wednesday
- The GitHub organization is `metabolomics-us`
- This runs inside Claude Code as a skill (slash command)
- The user has GitHub CLI (`gh`) available for querying GitHub data
- The skill should use the `gh` CLI or GitHub API to pull PR/commit data
- PowerPoint generation will need a library (e.g., python-pptx or a Node equivalent)

## Constraints

- **Platform**: Must work as a Claude Code skill on macOS
- **GitHub scope**: Only the user's own contributions in `metabolomics-us`
- **Output format**: PowerPoint (.pptx) — no other formats needed
- **Simplicity**: Charts and tables should be informative but not overloaded

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Claude Code skill, not cron automation | User wants manual control over when it runs | — Pending |
| Local save only, no email | User will handle distribution | — Pending |
| Only user's own activity | Meeting prep is about their own work | — Pending |

---
*Last updated: 2026-03-10 after initialization*
