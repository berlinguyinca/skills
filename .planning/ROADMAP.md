# Roadmap: MOS (My Own Stuff) — mos:progress

## Overview

Build the `mos:progress` Claude Code skill in five phases that follow the natural dependency chain: verified data before presentation, presentation before integration, integration before polish. Phase 1 establishes a correct data pipeline against real GitHub data. Phase 2 builds and validates the PPTX generator in isolation. Phase 3 adds categorization calibrated against real org PRs. Phase 4 wires the components together into a working slash command. Phase 5 hardens edge cases and adds the timeline slide.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: GitHub Data Foundation** - Verified data pipeline producing accurate PR and commit data within the correct time window
- [ ] **Phase 2: PPTX Script Foundation** - Standalone Python script generating all core slides from a JSON fixture
- [ ] **Phase 3: Categorization** - PR categorization calibrated against real metabolomics-us org data
- [ ] **Phase 4: Skill Integration** - Working /mos:progress command running end-to-end
- [ ] **Phase 5: Polish and Edge Cases** - Timeline slide, empty-state handling, overflow protection

## Phase Details

### Phase 1: GitHub Data Foundation
**Goal**: The data pipeline produces accurate, deduplicated PR and commit data for the metabolomics-us org within the correct Wednesday-to-Tuesday UTC window
**Depends on**: Nothing (first phase)
**Requirements**: DATA-01, DATA-02, DATA-03, DATA-04
**Success Criteria** (what must be TRUE):
  1. Running the data fetch produces a JSON output containing only PRs merged by the authenticated user in metabolomics-us within the expected Wednesday-to-Tuesday window
  2. The computed time window boundaries are logged and match the expected dates relative to today (verifiable by inspection)
  3. Commit counts per repo are present in the output and reflect commits by the authenticated user, not all authors
  4. Re-running the fetch on a week with zero qualifying activity returns an empty PRs array, not an error
**Plans**: TBD

### Phase 2: PPTX Script Foundation
**Goal**: A standalone Python script accepts the JSON schema and produces a well-formatted .pptx with summary, PR detail table, and breakdown chart slides — testable in isolation against a fixture
**Depends on**: Phase 1
**Requirements**: PRES-01, PRES-02, PRES-03, PRES-04
**Success Criteria** (what must be TRUE):
  1. Running the script against the sample JSON fixture produces a .pptx file in the current working directory without errors
  2. The .pptx opens in PowerPoint/Keynote/Google Slides and contains a summary slide, a PR detail table slide, and a breakdown chart slide
  3. The summary slide displays total PR count, total commit count, and 3-5 key highlight bullets drawn from the fixture data
  4. The PR detail table slide renders title, repo, category, and description columns without text overflow on the fixture data
**Plans**: TBD

### Phase 3: Categorization
**Goal**: Each PR from the metabolomics-us org is assigned a category (bug fix, new feature, new tool, or other) with acceptable accuracy against real org data
**Depends on**: Phase 1
**Requirements**: CATG-01, CATG-02, CATG-03, CATG-04
**Success Criteria** (what must be TRUE):
  1. Every PR in the data output has a non-null category field — no PR is silently dropped or left uncategorized
  2. PRs with recognized GitHub labels (bug, enhancement, etc.) receive the correct category without keyword inspection
  3. PRs with no labels receive a category based on title keyword matching rather than defaulting to "other"
  4. The "other" bucket on a real week of metabolomics-us PRs is below 40% (calibration check)
**Plans**: TBD

### Phase 4: Skill Integration
**Goal**: Typing /mos:progress in Claude Code fetches data, categorizes it, writes the JSON handoff file, runs the script, and reports the output path — end-to-end with no manual steps
**Depends on**: Phase 2, Phase 3
**Requirements**: SKIL-01, SKIL-02, SKIL-03
**Success Criteria** (what must be TRUE):
  1. /mos:progress is invocable as a slash command in Claude Code and begins executing without a "command not found" error
  2. Running the command on a machine with uv and gh available completes without requiring the user to install any dependencies manually
  3. The command exits with the path to the generated .pptx file printed to the terminal, and that file exists and opens correctly
**Plans**: TBD

### Phase 5: Polish and Edge Cases
**Goal**: The skill handles the full range of real-world inputs gracefully — zero-activity weeks, high-volume weeks, and produces a timeline slide — without layout breakage or silent failures
**Depends on**: Phase 4
**Requirements**: PRES-05, PRES-06, PRES-07
**Success Criteria** (what must be TRUE):
  1. Running /mos:progress on a week with zero merged PRs produces a valid .pptx with an empty-state slide rather than an error or a blank file
  2. Running /mos:progress on a fixture with 15+ PRs produces a .pptx where no slide has text overflowing its container — verified by visual inspection
  3. The .pptx includes a timeline slide showing when each PR merged across the week, readable with 1-15 entries
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. GitHub Data Foundation | 0/TBD | Not started | - |
| 2. PPTX Script Foundation | 0/TBD | Not started | - |
| 3. Categorization | 0/TBD | Not started | - |
| 4. Skill Integration | 0/TBD | Not started | - |
| 5. Polish and Edge Cases | 0/TBD | Not started | - |
