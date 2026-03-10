# Project Research Summary

**Project:** mos:progress — Weekly GitHub Activity Report (Claude Code skill)
**Domain:** GitHub org activity querying + automated PowerPoint generation
**Researched:** 2026-03-10
**Confidence:** HIGH

## Executive Summary

This project is a Claude Code slash command skill that queries the `metabolomics-us` GitHub org for the authenticated user's weekly activity (PRs and commits), categorizes that work, and produces a `.pptx` presentation ready to open in a meeting. The recommended approach is a clean two-component design: Claude (the LLM) acts as orchestrator and data normalizer, while a bundled Python script (`generate_pptx.py`) handles all slide rendering via python-pptx. These two components communicate through a well-defined JSON handoff file written to `/tmp/`. This separation is the key architectural decision — it keeps slide layout deterministic and testable while leveraging Claude's language understanding for categorization and summarization.

The recommended stack is deliberately minimal: the `gh` CLI for GitHub data access (already authenticated in the user's environment), Python with `python-pptx==1.0.2` and `matplotlib>=3.10` for presentation generation, and `uv run` for zero-friction isolated script execution. No server, no database, no scheduled jobs. Every existing tool in this space (GitDailies, Gitmore, QuantEcon) outputs to web dashboards or Slack; none produces a meeting-ready `.pptx` via a single command, which is the core differentiator.

The primary risks cluster in two areas. First, GitHub data fidelity: timezone handling, author-date vs. committer-date confusion, and the default-branch-only limitation of commit search can silently produce wrong or incomplete data. These must be addressed at the data-fetching layer before any presentation work begins. Second, python-pptx has a non-obvious API trap (`add_chart()` returns a `GraphicFrame`, not a `Chart`) and provides no protection against text overflow. Both are deterministic bugs with straightforward prevention patterns — establish them early in the script and they will not resurface.

## Key Findings

### Recommended Stack

The entire skill runs on tools already present in the user's environment plus two Python libraries. The `gh` CLI handles all GitHub interaction with zero additional auth setup; `python-pptx` is the only mature Python library for native `.pptx` creation; and `matplotlib` fills the gap where python-pptx's native chart support is insufficient for complex layouts (particularly the timeline/Gantt-style slide). `uv run --with` enables one-command execution with isolated dependencies and no venv management.

**Core technologies:**
- `Python 3.11+`: script runtime — python-pptx is Python-only; no Node.js equivalent exists
- `python-pptx 1.0.2`: PPTX generation — only mature Python library for native PPTX with charts and tables; 1.0.x is required (0.6.x is legacy with a breaking API difference)
- `matplotlib 3.10.x`: chart rendering — generates charts as embedded PNG images; more reliable and flexible than python-pptx native chart objects for this use case
- `gh` CLI (system): GitHub data access — already authenticated; `gh search prs` and `gh search commits` with `--owner`, `--author`, and `--json` cover all data needs
- `uv`: isolated script execution — `uv run --with python-pptx --with matplotlib` eliminates setup friction entirely

### Expected Features

The feature dependency chain is clear: time window computation is the root dependency everything else requires. The PR fetch is the critical path (three slides consume it). Categorization must run before the breakdown chart and summary can be built. This ordering is non-negotiable and should directly drive build order.

**Must have (table stakes):**
- Time window scoping (Wednesday through Tuesday noon) — all data queries depend on this; it must be first
- Multi-repo PR fetch for the org, scoped to current user — the core data source
- Activity categorization (bug / feature / tool / other) — enables breakdown chart and meaningful summary bullets
- Summary slide with counts and key highlights — the most important single slide; what a manager reads first
- PR detail table slide (title, repo, status, description) — replaces manual GitHub browsing in the meeting
- Breakdown chart slide (bug vs. feature vs. tool counts) — justifies the categorization effort
- Commit count per repo — low-effort supplementary metric that users universally expect
- `.pptx` saved to local working directory — the specified output format

**Should have (competitive):**
- Work timeline slide (when PRs merged across the week) — shows sprint pacing, adds meeting value
- Clean minimal visual design — auto-generated decks typically look cluttered; a simple layout reads as professional

**Defer (v2+):**
- Configurable time windows — Wednesday–Tuesday is correct for the stated use case; no config needed
- Multiple output formats (PDF, Google Slides) — `.pptx` opens in Google Slides; double output path doubles testing
- Team-level reporting — fundamentally different data model and permissions; different use case entirely

### Architecture Approach

The architecture follows the LLM-as-Orchestrator, Script-as-Renderer pattern. SKILL.md instructs Claude to: (1) inject the current date via `!`date`` syntax, (2) compute the Wednesday-to-Tuesday UTC-anchored window, (3) fetch PRs and commits via `gh` CLI, (4) normalize and categorize in-context, (5) write `/tmp/mos_data.json` with the agreed JSON schema, and (6) invoke the bundled `generate_pptx.py` script. Claude never generates the Python code — it runs a pre-written, stable script. The JSON file is the single interface boundary, not Claude's working memory.

**Major components:**
1. `SKILL.md` — entry point and orchestration; defines the JSON schema Claude must produce; keeps presentation logic out of natural language instructions
2. `scripts/generate_pptx.py` — receives the JSON file, builds all slides, saves `.pptx`; fully testable in isolation with a fixture; owns all layout decisions
3. `gh` CLI — raw data fetching via two org-wide queries (not N+1 per-repo); outputs JSON directly into Claude's context
4. Claude (LLM reasoning) — time window calculation, deduplication, categorization, summary text generation; the only component that should touch NLP tasks
5. `/tmp/mos_data.json` — the handoff artifact; written by Claude, read by the script; makes the data contract explicit and durable across context compaction

### Critical Pitfalls

1. **Timezone mismatch corrupts the time window** — compute the Wednesday-to-Tuesday window in UTC from the start using Python's `datetime.now().astimezone().utcoffset()`; pass explicit UTC-offset ISO 8601 strings to `gh`; log the computed window so the user can sanity-check it. Silent bug — add a unit test with a known non-UTC offset.

2. **Author date vs. committer date confusion** — always use `--author-date` qualifier in `gh search commits`; use `mergedAt` for PR queries; document the chosen convention in SKILL.md. Squash-merge workflows (common in this org) produce committer dates equal to merge time, making commits appear outside the actual work window.

3. **`gh search commits` only indexes the default branch** — PRs on feature branches not yet merged are invisible to commit search. Use `gh pr list --state=merged` as the primary data source; treat commit search as supplementary for direct pushes only. This is a documented GitHub limitation with no search-API workaround.

4. **`add_chart()` returns a `GraphicFrame`, not a `Chart`** — always capture `graphic_frame = slide.shapes.add_chart(...)` then access `chart = graphic_frame.chart`. Same pattern applies to `add_table()`. Establish this as a helper utility at the start of the script; the error is otherwise a confusing `AttributeError` that only surfaces when chart properties are set.

5. **Text overflow is silent** — python-pptx does not raise errors when text exceeds container bounds; the `.pptx` opens and looks broken. Apply defensive truncation constants (`MAX_CHARS`) before writing to any shape or table cell. Cap the PR table at 10 rows with an "...and N more" footer. Test with a 15+ PR week before declaring the layout done.

## Implications for Roadmap

Based on the feature dependency chain, the architecture's prescribed build order, and the pitfall-to-phase mapping, the natural phase structure is:

### Phase 1: GitHub Data Foundation

**Rationale:** Everything else depends on correct data. The time window, PR fetch, and commit query must be validated against real GitHub data before any presentation work begins. The three most critical pitfalls (timezone, author date, default-branch-only) all live in this phase — discovering them later means rewriting already-integrated code.

**Delivers:** A verified data pipeline that produces accurate, deduplicated PR and commit data for the `metabolomics-us` org within the correct Wednesday-to-Tuesday UTC window.

**Addresses:** Time window scoping, multi-repo PR fetch, commit count per repo

**Avoids:** Timezone mismatch (Pitfall 3), author/committer date confusion (Pitfall 1), default-branch-only gap (Pitfall 2), per-repo rate limit danger (Pitfall 7)

**Research flag:** Standard patterns — `gh` CLI docs are complete and verified HIGH confidence. No additional research needed.

### Phase 2: PPTX Script Foundation

**Rationale:** Build and test `generate_pptx.py` against a hardcoded sample JSON fixture before integrating with live GitHub data. This isolates python-pptx API complexity (GraphicFrame trap, text overflow, chart rendering) from data complexity. Architecture research explicitly recommends this build order.

**Delivers:** A fully functional, standalone Python script that accepts the JSON schema and produces a well-formatted `.pptx` with all required slides. Testable in isolation.

**Addresses:** `.pptx` output, summary slide, PR detail table slide, breakdown chart slide

**Avoids:** `add_chart()` GraphicFrame confusion (Pitfall 4), text overflow (Pitfall 5)

**Research flag:** Standard patterns — python-pptx 1.0.2 docs are complete and HIGH confidence. Chart and table patterns are well-documented. No additional research needed.

### Phase 3: Data Enrichment and Categorization

**Rationale:** Categorization logic must be isolated and validated against real PR data before it feeds the presentation layer. The heuristic approach (label-first, then keyword fallback, then "Other") needs calibration against actual `metabolomics-us` PRs — the "Other" bucket exceeding 40% is a failure signal that requires iteration.

**Delivers:** A categorization pass that correctly classifies PRs from the `metabolomics-us` org into bug fix / new feature / new tool / other with acceptable accuracy.

**Addresses:** Activity categorization, breakdown chart data, summary bullet "X bugs, Y features"

**Avoids:** Categorization unreliability (Pitfall 6)

**Research flag:** Needs light validation — the keyword list should be calibrated against a real week of `metabolomics-us` PRs during this phase.

### Phase 4: SKILL.md Integration and JSON Handoff

**Rationale:** Once both the data pipeline (Phase 1) and the script (Phase 2) are independently validated, the integration is a matter of wiring them together via the JSON schema and SKILL.md instructions. Integration issues at this stage will be schema mismatches, not fundamental logic errors.

**Delivers:** A working `/mos:progress` Claude Code skill that runs end-to-end: fetches data, categorizes, writes JSON, invokes the script, and reports the output path.

**Addresses:** Single-command invocation, skill file structure, JSON handoff contract

**Avoids:** Putting all logic in SKILL.md (Anti-Pattern 4), generating code instead of running bundled script (Anti-Pattern 1), storing data in context instead of `/tmp/` (Anti-Pattern 3)

**Research flag:** Standard patterns — Claude Code skills documentation is verified HIGH confidence. No additional research needed.

### Phase 5: Polish and Edge Cases

**Rationale:** After the core skill works, address the "looks done but isn't" checklist: timeline slide, visual design, empty-state handling, progress feedback during API calls, and heavy-week testing (15+ PRs).

**Delivers:** A production-ready skill with graceful error handling, clear output messages, truncation guards, and the optional work timeline slide.

**Addresses:** Work timeline slide (P2), clean visual design (P2), UX pitfalls (silent failure, no progress indication, overloaded slides)

**Avoids:** Text overflow (Pitfall 5, final validation), UX pitfalls (silent failure, missing output path, generic slide title)

**Research flag:** Standard patterns — this phase is design and hardening, not new technology.

### Phase Ordering Rationale

- **Data before presentation:** The architecture research is explicit — build the script with a fixture first, then integrate data. Inverting this order means debugging two unknowns simultaneously.
- **Categorization after raw data, before integration:** The heuristic needs calibration against real org PRs; it cannot be tuned against synthetic data. But it should not block the script-building phase.
- **Integration last among core phases:** Both halves tested independently means integration issues are boundary issues (schema), not logic bugs.
- **Polish deferred to Phase 5:** The timeline slide and visual design are P2 features; they should not hold up validation of the core reporting capability.

### Research Flags

Phases with standard, well-documented patterns (skip research-phase):
- **Phase 1:** `gh` CLI docs are complete, official, and HIGH confidence. Query patterns are verified.
- **Phase 2:** python-pptx 1.0.2 docs are complete and HIGH confidence. Pitfall patterns are documented.
- **Phase 4:** Claude Code skills documentation is official and HIGH confidence.
- **Phase 5:** Hardening and design — no new technology.

Phases that need light validation during planning:
- **Phase 3:** Categorization heuristics should be calibrated against 1-2 real weeks of `metabolomics-us` PR data before finalizing keyword lists. Not a research-phase blocker, but build in a review step.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All core technologies verified against official docs (gh CLI manual, python-pptx PyPI + readthedocs, Claude Code skills docs). `uv run --with` verified via multiple secondary sources (MEDIUM on that specific flag). |
| Features | HIGH (core) / MEDIUM (categorization) | PR-based features and output format are HIGH confidence. Categorization heuristic accuracy against this specific org's PR labeling practices is MEDIUM — requires empirical calibration. |
| Architecture | HIGH | Build order and component boundaries are well-justified and internally consistent. LLM-as-orchestrator pattern is a proven Claude Code skill pattern per official docs. |
| Pitfalls | HIGH (GitHub), HIGH (python-pptx), MEDIUM (skill mechanics) | GitHub API pitfalls verified against official docs and community discussions. python-pptx pitfalls confirmed in library issues. Claude Code skill edge cases are MEDIUM — less community documentation available. |

**Overall confidence:** HIGH

### Gaps to Address

- **Categorization accuracy for `metabolomics-us`:** The keyword heuristics are generic. During Phase 3, run categorization against 2-4 real weeks of the org's PRs and expand or adjust the keyword list based on actual PR title patterns. The "Other" bucket percentage is the quality metric.
- **`uv` availability:** SKILL.md should detect whether `uv` is available and fall back to `python3` with a `pip install` advisory if not. This edge case is minor but affects first-run experience.
- **Output directory creation:** The `~/output/` directory may not exist. `generate_pptx.py` must call `mkdir -p` before writing. Document this in the script.
- **Pagination for high-activity weeks:** The default `gh` page size is 30. The `--limit` flag must be set explicitly (e.g., `--limit 200`) on all `gh` queries. This is a "looks done but isn't" item that will silently truncate data in active weeks.

## Sources

### Primary (HIGH confidence)
- [gh search prs — GitHub CLI Manual](https://cli.github.com/manual/gh_search_prs) — verified `--owner`, `--author`, `--created`, `--json` flags
- [gh search commits — GitHub CLI Manual](https://cli.github.com/manual/gh_search_commits) — verified `--owner`, `--author`, `--author-date`, `--json` fields
- [python-pptx on PyPI](https://pypi.org/project/python-pptx/) — confirmed version 1.0.2, released Aug 7, 2024
- [python-pptx Charts Documentation](https://python-pptx.readthedocs.io/en/latest/user/charts.html) — confirmed chart types, GraphicFrame API
- [Claude Code Skills Documentation](https://code.claude.com/docs/en/skills) — confirmed SKILL.md structure, `${CLAUDE_SKILL_DIR}`, `!`backtick`` injection, `disable-model-invocation`
- [matplotlib on PyPI](https://pypi.org/project/matplotlib/) — confirmed version 3.10.x
- [GitHub REST API: Search rate limits](https://docs.github.com/en/rest/search/search?apiVersion=2022-11-28) — rate limit behavior
- [GitDailies report content documentation](https://gitdailies.com/docs/reports/content/) — feature landscape
- [GitHub Pulse documentation](https://docs.github.com/en/repositories/viewing-activity-and-data-for-your-repository/using-pulse-to-view-a-summary-of-repository-activity) — competitor feature analysis
- [Atlassian project status report guide](https://www.atlassian.com/agile/project-management/status-report) — report structure best practices

### Secondary (MEDIUM confidence)
- [uv — Astral](https://github.com/astral-sh/uv) — `uv run --with` pattern; verified via multiple secondary sources
- [Gitmore GitHub reporting features](https://gitmore.io/git-reporting/tool/github) — competitor feature analysis
- [QuantEcon action-weekly-report](https://github.com/QuantEcon/action-weekly-report) — reference implementation for org-scoped weekly reports
- [GitHub community: Timezone not respected in gh CLI (Issue #1504)](https://github.com/cli/cli/issues/1504) — timezone pitfall
- [Working with dates in Git — Alex Peattie](https://alexpeattie.com/blog/working-with-dates-in-git/) — author/committer date behavior
- [Skill authoring best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices) — SKILL.md design patterns

### Tertiary (background context)
- [python-pptx text autofit issue #969](https://github.com/scanny/python-pptx/issues/969) — text overflow behavior confirmation
- [GitHub community: Best practices for rate limits](https://github.com/orgs/community/discussions/156480) — secondary rate limit behavior

---
*Research completed: 2026-03-10*
*Ready for roadmap: yes*
