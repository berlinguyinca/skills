# Requirements: MOS (My Own Stuff)

**Defined:** 2026-03-10
**Core Value:** One command produces a meeting-ready PowerPoint that accurately captures the week's development work

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Data Collection

- [ ] **DATA-01**: Skill computes the reporting time window as previous Wednesday 00:00 through Tuesday 12:00 noon, anchored to user's local timezone
- [ ] **DATA-02**: Skill fetches all merged PRs authored by the user across all repos in `metabolomics-us` org within the time window
- [ ] **DATA-03**: Skill counts commits per repo authored by the user within the time window
- [ ] **DATA-04**: Skill uses merged PRs as primary data source (not commit search) to avoid missing work on non-default branches

### Categorization

- [ ] **CATG-01**: Skill categorizes each PR as bug fix, new feature, or new tool
- [ ] **CATG-02**: Categorization uses PR labels as primary signal (e.g., `bug`, `enhancement`)
- [ ] **CATG-03**: Categorization falls back to commit message / PR title keyword matching when labels are absent
- [ ] **CATG-04**: Uncategorizable PRs are labeled "other" rather than silently dropped

### Presentation

- [ ] **PRES-01**: Skill generates a .pptx file saved to the current working directory
- [ ] **PRES-02**: PowerPoint includes a summary slide with total PR count, commit count, and 3-5 key highlights
- [ ] **PRES-03**: PowerPoint includes a PR detail table slide with columns: title, repo, category, description
- [ ] **PRES-04**: PowerPoint includes a breakdown chart slide showing bug vs feature vs tool counts
- [ ] **PRES-05**: PowerPoint includes a timeline slide showing when PRs merged across the week
- [ ] **PRES-06**: Slides handle weeks with zero activity gracefully (empty state, not an error)
- [ ] **PRES-07**: Slides handle weeks with 15+ PRs without text overflow or layout breakage

### Skill Integration

- [ ] **SKIL-01**: Skill is invocable as `/mos:progress` in Claude Code
- [ ] **SKIL-02**: Skill runs without manual dependency installation (uses `uv run --with` or equivalent)
- [ ] **SKIL-03**: Skill uses `gh` CLI for all GitHub queries (leverages existing auth)

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Customization

- **CUST-01**: User can configure the time window (not just Wed-Tue)
- **CUST-02**: User can customize slide theme/colors

### Distribution

- **DIST-01**: Skill can email the PowerPoint after generation
- **DIST-02**: Skill can output to PDF or Google Slides format

## Out of Scope

| Feature | Reason |
|---------|--------|
| Automated scheduling (cron/launchd) | User wants manual invocation control |
| Team-wide activity reporting | Different data model, privacy concerns, contradicts personal prep use case |
| AI-generated narrative prose per PR | Adds latency, costs tokens, risks hallucination — PR titles are sufficient |
| Commit-level detail in slides | Commit noise obscures the meaningful unit (the PR) |
| Configurable templates/theming | Most users never change defaults; hardcode a clean neutral design |
| Real-time/live data in slides | PowerPoint is static; generate fresh on demand instead |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| DATA-01 | Phase 1 | Pending |
| DATA-02 | Phase 1 | Pending |
| DATA-03 | Phase 1 | Pending |
| DATA-04 | Phase 1 | Pending |
| CATG-01 | Phase 3 | Pending |
| CATG-02 | Phase 3 | Pending |
| CATG-03 | Phase 3 | Pending |
| CATG-04 | Phase 3 | Pending |
| PRES-01 | Phase 2 | Pending |
| PRES-02 | Phase 2 | Pending |
| PRES-03 | Phase 2 | Pending |
| PRES-04 | Phase 2 | Pending |
| PRES-05 | Phase 5 | Pending |
| PRES-06 | Phase 5 | Pending |
| PRES-07 | Phase 5 | Pending |
| SKIL-01 | Phase 4 | Pending |
| SKIL-02 | Phase 4 | Pending |
| SKIL-03 | Phase 4 | Pending |

**Coverage:**
- v1 requirements: 18 total
- Mapped to phases: 18
- Unmapped: 0 ✓

---
*Requirements defined: 2026-03-10*
*Last updated: 2026-03-10 after roadmap creation*
