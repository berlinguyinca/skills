# gw-skills

## What This Is

A collection of 8 Claude Code skills by Gert Wohlgemuth, prefixed `gw:` and available as global slash commands. Skills cover app analysis (review-app), SaaS idea generation (saas-idea), competitive analysis (compete), multi-persona research (research), weekly GitHub reporting (weekly-review), PR shipping (merge-it), persona management (workforce), and self-update (update). The toolkit includes 37 default persona files used by team-driven skills, 3 shell scripts for install/uninstall/update-check, and a canonical PPTX design system shared across 6 presentation-generating skills.

## Core Value

One slash command assembles a specialist team, runs parallel analysis or research, conducts structured debate, and produces actionable deliverables (reports, presentations, implementation plans) — no manual orchestration required.

## Requirements

### Validated

- ✓ 8 skills installed and invocable as Claude Code slash commands — v1.0
- ✓ 37 default personas with frontmatter-driven configuration — v1.0
- ✓ Shared workforce across compete, research, review-app, saas-idea — v1.0
- ✓ Canonical PPTX design system (9-color palette, accent bar, Calibri) — v1.0
- ✓ Auto-update check on skill invocation — v1.0
- ✓ Multi-source weekly-review with persistent config — v1.0
- ✓ Structured 3-round debate in compete, research, saas-idea — v1.0

### Active

See REQUIREMENTS.md for current milestone requirements.

### Out of Scope

- Web frontend or documentation site — CLI-only tool
- Automated scheduling (cron/launchd) — user invokes skills manually
- Multi-user support — single-user, trust-the-operator model
- Google Slides or PDF output — PowerPoint only

## Current Milestone: v1.1 Quality & Safety

**Goal:** Establish safety net, input validation, testing infrastructure, and CI/CD for the gw-skills toolkit.

**Target features:**
- .gitignore and repository hygiene
- Input sanitization across all skill files
- ShellCheck linting and BATS test suite
- GitHub Actions CI pipeline
- Secure temp directory usage
- Shared pattern extraction to reduce duplication

## Context

- Project started as "mos:progress" (weekly GitHub reporting), evolved into 8-skill toolkit
- All skills are Markdown instruction files consumed by Claude Code at runtime
- 3 shell scripts (install.sh, uninstall.sh, check-update.sh) are the only executable code
- Personas are Markdown files with YAML frontmatter, loaded dynamically by skills
- PPTX generation uses python-pptx via `uv run --with python-pptx`
- Skills auto-check for updates via check-update.sh on every invocation
- Analysis from gw:review-app (2026-03-19) identified 18 findings across 6 dimensions

## Constraints

- **Platform**: Must work as Claude Code skills on macOS
- **Naming**: All skills must use `gw:` prefix
- **Design system**: All PPTX-generating skills must use the canonical 9-color palette
- **Skill structure**: Frontmatter → Step 0 update check → argument parsing → workflow routing → numbered steps → approval gates → error handling
- **No breaking changes**: Skill argument contracts must remain backward-compatible

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Claude Code skills, not standalone CLI | Leverages Claude's orchestration and agent capabilities | ✓ Good |
| Shared workforce across skills | Personas are reusable across compete, research, review-app, saas-idea | ✓ Good |
| Canonical PPTX design system | Visual consistency across all presentation-generating skills | ✓ Good |
| gw: prefix for all skills | Namespace isolation from other skill collections | ✓ Good |
| Symlink-based installation | git pull delivers updates instantly | ✓ Good |
| CONSENSUS.md for debate output | Consistent naming across all debate-capable skills | ✓ Good |

---
*Last updated: 2026-03-19 after v1.1 milestone initialization*
