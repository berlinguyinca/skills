# Roadmap: gw-skills

## Overview

The gw-skills toolkit roadmap spans two milestones. Milestone v1.0 shipped the 8-skill toolkit (weekly-review, saas-idea, compete, research, review-app, merge-it, workforce, update) with 37 default personas, a shared PPTX design system, and symlink-based installation. Milestone v1.1 establishes quality and safety: a .gitignore, ShellCheck linting, BATS test coverage for the 3 shell scripts, a GitHub Actions CI pipeline, input sanitization across all skill files, secure temp directory usage, and shared pattern extraction to reduce duplication.

Phases 6-9 execute in dependency order: safety net first (no code changes required), then core defenses (widest code surface), then deduplication (requires stable, tested code), then polish (CI completeness).

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

### v1.0 Phases (Superseded by v1.1)

- [x] **Phase 1: GitHub Data Foundation** - Verified data pipeline producing accurate PR and commit data within the correct time window *(v1.0 — superseded)*
- [x] **Phase 2: PPTX Script Foundation** - Standalone Python script generating all core slides from a JSON fixture *(v1.0 — superseded)*
- [x] **Phase 3: Categorization** - PR categorization calibrated against real metabolomics-us org data *(v1.0 — superseded)*
- [x] **Phase 4: Skill Integration** - Working /mos:progress command running end-to-end *(v1.0 — superseded)*
- [x] **Phase 5: Polish and Edge Cases** - Timeline slide, empty-state handling, overflow protection *(v1.0 — superseded)*

### v1.1 Phases

- [ ] **Phase 6: Safety Net** - Repository hygiene, ShellCheck config, version-pinned dependency, and two targeted security fixes with no code rewrites
- [ ] **Phase 7: Core Defenses** - Input sanitization across all skills, BATS test suite for all 3 shell scripts, and GitHub Actions CI running ShellCheck and BATS
- [ ] **Phase 8: Reduce Maintenance Drag** - Shared pattern extraction eliminating duplicated GW_REPO resolution, workforce loading, PPTX design system, and workforce redirect messages
- [ ] **Phase 9: Polish** - Markdown linting config, persona file validator, and CI validation of persona frontmatter

## Phase Details

### Phase 1: GitHub Data Foundation
**Goal**: The data pipeline produces accurate, deduplicated PR and commit data for the metabolomics-us org within the correct Wednesday-to-Tuesday UTC window
**Depends on**: Nothing (first phase)
**Requirements**: DATA-01, DATA-02, DATA-03, DATA-04
**Milestone**: v1.0 — superseded
**Success Criteria** (what must be TRUE):
  1. Running the data fetch produces a JSON output containing only PRs merged by the authenticated user in metabolomics-us within the expected Wednesday-to-Tuesday window
  2. The computed time window boundaries are logged and match the expected dates relative to today (verifiable by inspection)
  3. Commit counts per repo are present in the output and reflect commits by the authenticated user, not all authors
  4. Re-running the fetch on a week with zero qualifying activity returns an empty PRs array, not an error
**Plans**: Complete (v1.0)

### Phase 2: PPTX Script Foundation
**Goal**: A standalone Python script accepts the JSON schema and produces a well-formatted .pptx with summary, PR detail table, and breakdown chart slides — testable in isolation against a fixture
**Depends on**: Phase 1
**Requirements**: PRES-01, PRES-02, PRES-03, PRES-04
**Milestone**: v1.0 — superseded
**Success Criteria** (what must be TRUE):
  1. Running the script against the sample JSON fixture produces a .pptx file in the current working directory without errors
  2. The .pptx opens in PowerPoint/Keynote/Google Slides and contains a summary slide, a PR detail table slide, and a breakdown chart slide
  3. The summary slide displays total PR count, total commit count, and 3-5 key highlight bullets drawn from the fixture data
  4. The PR detail table slide renders title, repo, category, and description columns without text overflow on the fixture data
**Plans**: Complete (v1.0)

### Phase 3: Categorization
**Goal**: Each PR from the metabolomics-us org is assigned a category (bug fix, new feature, new tool, or other) with acceptable accuracy against real org data
**Depends on**: Phase 1
**Requirements**: CATG-01, CATG-02, CATG-03, CATG-04
**Milestone**: v1.0 — superseded
**Success Criteria** (what must be TRUE):
  1. Every PR in the data output has a non-null category field — no PR is silently dropped or left uncategorized
  2. PRs with recognized GitHub labels (bug, enhancement, etc.) receive the correct category without keyword inspection
  3. PRs with no labels receive a category based on title keyword matching rather than defaulting to "other"
  4. The "other" bucket on a real week of metabolomics-us PRs is below 40% (calibration check)
**Plans**: Complete (v1.0)

### Phase 4: Skill Integration
**Goal**: Typing /mos:progress in Claude Code fetches data, categorizes it, writes the JSON handoff file, runs the script, and reports the output path — end-to-end with no manual steps
**Depends on**: Phase 2, Phase 3
**Requirements**: SKIL-01, SKIL-02, SKIL-03
**Milestone**: v1.0 — superseded
**Success Criteria** (what must be TRUE):
  1. /mos:progress is invocable as a slash command in Claude Code and begins executing without a "command not found" error
  2. Running the command on a machine with uv and gh available completes without requiring the user to install any dependencies manually
  3. The command exits with the path to the generated .pptx file printed to the terminal, and that file exists and opens correctly
**Plans**: Complete (v1.0)

### Phase 5: Polish and Edge Cases
**Goal**: The skill handles the full range of real-world inputs gracefully — zero-activity weeks, high-volume weeks, and produces a timeline slide — without layout breakage or silent failures
**Depends on**: Phase 4
**Requirements**: PRES-05, PRES-06, PRES-07
**Milestone**: v1.0 — superseded
**Success Criteria** (what must be TRUE):
  1. Running /mos:progress on a week with zero merged PRs produces a valid .pptx with an empty-state slide rather than an error or a blank file
  2. Running /mos:progress on a fixture with 15+ PRs produces a .pptx where no slide has text overflowing its container — verified by visual inspection
  3. The .pptx includes a timeline slide showing when each PR merged across the week, readable with 1-15 entries
**Plans**: Complete (v1.0)

### Phase 6: Safety Net
**Goal**: The repository is safe to push publicly and safe to run — .gitignore prevents accidental secret commits, ShellCheck enforces shell correctness, the python-pptx dependency is version-pinned, gw:update warns before destructive resets, and gw:weekly-review validates download URLs before fetching
**Depends on**: Nothing (REPO-01 already complete; remaining items are config files and two targeted instruction edits)
**Requirements**: REPO-01, REPO-02, SECR-02, SECR-03, SECR-04
**Milestone**: v1.1
**Success Criteria** (what must be TRUE):
  1. Running `shellcheck *.sh` in the repo root exits 0 and prints no warnings for install.sh, uninstall.sh, and check-update.sh
  2. All 6 presentation-generating skill files reference a version-pinned python-pptx (e.g. `python-pptx==1.0.2`) rather than an unpinned package name
  3. Running gw:update when the local branch is behind shows an explicit data-loss warning before any git reset --hard instruction
  4. Running gw:weekly-review with a download_url from an unexpected domain causes Claude to reject the URL and report it, rather than fetch it silently
  5. `git status` after a normal working session shows no .DS_Store, no credentials files, and no generated output directories staged for commit
**Plans**: TBD

### Phase 7: Core Defenses
**Goal**: All 7 skill files reject malformed inputs, the 3 shell scripts have BATS test coverage, and a GitHub Actions CI pipeline runs ShellCheck and BATS on every push and PR
**Depends on**: Phase 6 (ShellCheck must pass before CI enforces it)
**Requirements**: INPT-01, INPT-02, INPT-03, INPT-04, TEST-01, TEST-02, TEST-03, CICD-01, CICD-02, SECR-01
**Milestone**: v1.1
**Success Criteria** (what must be TRUE):
  1. Passing a shell metacharacter (e.g. `; rm -rf ~`) to any named parameter (--focus, --add, --hire, etc.) causes the skill to stop and report an invalid-input error rather than interpolating the value
  2. Slug generation in all skills produces only lowercase, path-safe strings — an empty input, a dot-prefixed input, or a value containing `../` is rejected before any file operation
  3. Passing a non-integer or out-of-range value to --pick or --team causes the skill to report a validation error and halt
  4. Running `bats tests/` executes tests for install.sh, uninstall.sh, and check-update.sh and exits 0 with all cases passing
  5. Opening a pull request against main triggers the GitHub Actions workflow and the ShellCheck and BATS jobs both pass (green check on the PR)
  6. PPTX-generating skills write their intermediate files to a path produced by `mktemp -d` rather than a hardcoded /tmp/ directory
**Plans**: TBD

### Phase 8: Reduce Maintenance Drag
**Goal**: Duplicated patterns that currently exist in 3-8 places each are replaced by a single canonical source, so future changes to GW_REPO resolution, workforce loading, the PPTX design system, or workforce redirect messages touch one file instead of many
**Depends on**: Phase 7 (BATS tests must exist before refactoring shell scripts; skills must have input validation before restructuring their instruction text)
**Requirements**: SHRD-01, SHRD-02, SHRD-03, SHRD-04
**Milestone**: v1.1
**Success Criteria** (what must be TRUE):
  1. A single shared script resolves GW_REPO and is sourced by install.sh, uninstall.sh, and check-update.sh — the resolution logic appears in exactly one place
  2. All skills that load workforce personas reference one canonical loading instruction block (or shared file) rather than each containing their own copy
  3. The PPTX 9-color palette, accent bar spec, and Calibri font definition exist in one canonical location and all 6 presentation-generating skills reference it rather than re-specifying it
  4. The --hire/--fire/--roster redirect message is identical across all skills that support workforce commands, and that message text lives in one place
**Plans**: TBD

### Phase 9: Polish
**Goal**: The repository enforces consistent Markdown formatting across all 45+ files, persona files are validated for required frontmatter fields, and CI catches both on every push
**Depends on**: Phase 8 (shared patterns must be stable before adding linting that would flag inconsistencies introduced during extraction)
**Requirements**: REPO-03, TEST-04, CICD-03
**Milestone**: v1.1
**Success Criteria** (what must be TRUE):
  1. A Markdown linting config file (.markdownlint.json or equivalent) exists and running the linter against all .md files in the repo exits 0
  2. Running the persona validator script against all files in workforce/_defaults/ and workforce/ reports pass for every file that has the required frontmatter fields (name, role, description)
  3. The GitHub Actions CI workflow includes a persona validation job that runs on push/PR and fails the check if any persona file is missing required frontmatter
  4. After Phase 9, adding a new persona file without the required frontmatter causes CI to fail before the PR can merge
**Plans**: TBD

## Progress

**Execution Order:**
v1.0 phases complete. v1.1 executes in order: 6 → 7 → 8 → 9

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. GitHub Data Foundation | —/— | Complete (v1.0) | 2026-03-19 |
| 2. PPTX Script Foundation | —/— | Complete (v1.0) | 2026-03-19 |
| 3. Categorization | —/— | Complete (v1.0) | 2026-03-19 |
| 4. Skill Integration | —/— | Complete (v1.0) | 2026-03-19 |
| 5. Polish and Edge Cases | —/— | Complete (v1.0) | 2026-03-19 |
| 6. Safety Net | 0/TBD | Not started | - |
| 7. Core Defenses | 0/TBD | Not started | - |
| 8. Reduce Maintenance Drag | 0/TBD | Not started | - |
| 9. Polish | 0/TBD | Not started | - |

---
*Roadmap updated: 2026-03-19 — v1.1 phases added (6-9)*
