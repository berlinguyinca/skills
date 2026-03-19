# Requirements: gw-skills

**Defined:** 2026-03-19
**Core Value:** One slash command assembles a specialist team, runs parallel analysis, and produces actionable deliverables
**Source:** gw:review-app analysis (2026-03-19) — 18 findings across 6 dimensions

## v1.1 Requirements

Requirements for Quality & Safety milestone. Each maps to roadmap phases.

### Repository Hygiene

- [x] **REPO-01**: Repository has a .gitignore preventing accidental commit of secrets, .DS_Store, and generated output directories
- [ ] **REPO-02**: ShellCheck config exists and all 3 shell scripts pass linting without errors
- [ ] **REPO-03**: Markdown linting config exists for consistent formatting across 45+ Markdown files

### Input Validation

- [ ] **INPT-01**: All 7 skill files reject shell metacharacters in named parameters (--focus, --add, --hire, etc.)
- [ ] **INPT-02**: Slug generation across all skills enforces consistent rules (lowercase, no path traversal, no empty/dot-prefixed results)
- [ ] **INPT-03**: Integer parameters (--pick, --team) validate as positive integers with range checking
- [ ] **INPT-04**: Agent prompt templates include directive to treat interpolated values as literal data

### Testing

- [ ] **TEST-01**: BATS test suite covers install.sh (fresh install, reinstall over symlink, reinstall over directory)
- [ ] **TEST-02**: BATS test suite covers uninstall.sh (symlink removal, non-symlink refusal)
- [ ] **TEST-03**: BATS test suite covers check-update.sh (up-to-date, behind, network failure, timeout)
- [ ] **TEST-04**: Persona file structural validator checks required frontmatter fields

### CI/CD

- [ ] **CICD-01**: GitHub Actions workflow runs ShellCheck on all .sh files on push/PR
- [ ] **CICD-02**: GitHub Actions workflow runs BATS test suite on push/PR
- [ ] **CICD-03**: GitHub Actions workflow validates persona file frontmatter on push/PR

### Security

- [ ] **SECR-01**: PPTX-generating skills use mktemp -d instead of hardcoded /tmp/ paths
- [ ] **SECR-02**: python-pptx dependency is version-pinned in all skill files
- [ ] **SECR-03**: gw:update warns about data loss before suggesting git reset --hard
- [ ] **SECR-04**: gw:weekly-review validates download_url domain before curl

### Shared Patterns

- [ ] **SHRD-01**: Duplicated GW_REPO resolution pattern extracted into a shared script
- [ ] **SHRD-02**: Duplicated workforce loading instructions reference a single canonical source
- [ ] **SHRD-03**: PPTX design system defined once and referenced by all 6 presentation-generating skills
- [ ] **SHRD-04**: --hire/--fire/--roster redirect messages are identical across all skills that use them

## v2 Requirements

Deferred to future milestone.

- **ADVS-01**: Full E2E test for at least one skill (simulated Claude Code invocation)
- **ADVS-02**: Persona file migration script for schema changes
- **ADVS-03**: Shell script portability testing across macOS and Linux

## Out of Scope

| Feature | Reason |
|---------|--------|
| Rewriting skills in a programming language | Skills are Markdown instructions for Claude — this is by design |
| Multi-user authentication | Single-user tool, trust-the-operator model |
| Automated CI deployment | Skills are distributed via git clone + symlink |
| Full input sanitization in Claude's prompt execution | Claude Code's sandbox handles this; skill-level validation is defense-in-depth |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| REPO-01 | Phase 6 | Complete |
| REPO-02 | Phase 6 | Pending |
| REPO-03 | Phase 9 | Pending |
| INPT-01 | Phase 7 | Pending |
| INPT-02 | Phase 7 | Pending |
| INPT-03 | Phase 7 | Pending |
| INPT-04 | Phase 7 | Pending |
| TEST-01 | Phase 7 | Pending |
| TEST-02 | Phase 7 | Pending |
| TEST-03 | Phase 7 | Pending |
| TEST-04 | Phase 9 | Pending |
| CICD-01 | Phase 7 | Pending |
| CICD-02 | Phase 7 | Pending |
| CICD-03 | Phase 9 | Pending |
| SECR-01 | Phase 7 | Pending |
| SECR-02 | Phase 6 | Pending |
| SECR-03 | Phase 6 | Pending |
| SECR-04 | Phase 6 | Pending |
| SHRD-01 | Phase 8 | Pending |
| SHRD-02 | Phase 8 | Pending |
| SHRD-03 | Phase 8 | Pending |
| SHRD-04 | Phase 8 | Pending |

**Coverage:**
- v1.1 requirements: 22 total
- Mapped to phases: 22
- Unmapped: 0 ✓

---
*Requirements defined: 2026-03-19*
*Last updated: 2026-03-19 after initial definition*
