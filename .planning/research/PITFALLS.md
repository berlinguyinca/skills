# Pitfalls Research

**Domain:** GitHub activity reporting + automated PowerPoint generation (Claude Code skill)
**Researched:** 2026-03-10
**Confidence:** HIGH (GitHub API), HIGH (python-pptx), MEDIUM (Claude Code skill mechanics)

---

## Critical Pitfalls

### Pitfall 1: Author Date vs. Committer Date Confusion

**What goes wrong:**
The skill queries commits using a date range and misses commits or double-counts them because GitHub's API exposes two separate timestamps for every commit — `author.date` (when the developer ran `git commit`) and `committer.date` (when the commit was rebased, amended, or integrated). By default, `git log --since` and GitHub's search `committer-date` filter on committer date, not author date. A developer who commits on Monday but whose PR is squash-merged on Wednesday has their work appear on Wednesday in commit search results even though the work was done on Monday.

**Why it happens:**
Developers assume "commit date" is a single unambiguous value. GitHub's UI shows committer date in most places, but the Blame view uses author date, and the REST search API's `committer-date` and `author-date` qualifiers behave differently. Squash-merge workflows (common in `metabolomics-us`) always produce a committer date equal to the merge time, regardless of when the original commits were authored.

**How to avoid:**
Use `--author-date` for the `gh search commits` qualifier when the goal is "work done during the week." Since this project cares about the user's own contributions (not when PRs landed), filter by `author-date` in the commit search. For PR queries, use the PR `mergedAt` or `createdAt` timestamps, which are unambiguous. Document the chosen convention (author date) explicitly in a comment in the skill prompt.

**Warning signs:**
- Commits from a squash-merge appear outside the expected time window.
- The commit count reported doesn't match what the user sees when they browse their GitHub profile activity graph.
- The timeline slide shows clusters at Wednesday noon (merge time) rather than spread across the week.

**Phase to address:**
GitHub data-fetching phase. Validate with a known week before building the PowerPoint layer.

---

### Pitfall 2: GitHub Search API Only Indexes the Default Branch

**What goes wrong:**
`gh search commits --author=<user> --owner=metabolomics-us --author-date=...` uses GitHub's search index, which only indexes commits on the default branch of each repository. Work on feature branches that has not yet been merged will be invisible. Pull requests with commits that haven't been merged to `main`/`master` won't appear in commit search results at all.

**Why it happens:**
GitHub's search index is a deliberately limited subset of the full commit graph for performance reasons. This is a documented limitation with no workaround through the search endpoint alone.

**How to avoid:**
Use a two-track approach: (1) fetch merged PRs via `gh pr list --author=@me --state=merged --search="merged:>=DATE"` to capture merged work with PR-level metadata, and (2) use `gh search commits` only as a supplementary signal for commits on default branches (e.g., direct pushes). Do not rely on commit search as the sole source of truth. The PR-centric approach is more reliable for a code review workflow.

**Warning signs:**
- A PR the user knows was merged doesn't show up in commit results.
- Commit counts are consistently lower than the user's mental model of activity.
- Repositories with branch-protection rules (all merges via PR) show zero direct commits but should have merged-commit entries.

**Phase to address:**
GitHub data-fetching phase. Write an explicit test: merge a PR, then verify both the PR endpoint and commit endpoint capture it.

---

### Pitfall 3: Timezone Mismatch Corrupts the Time Window

**What goes wrong:**
The skill computes "previous Wednesday through Tuesday noon" in local time, but GitHub's API filters dates in UTC. If the user is in UTC-5, their "Tuesday noon" is 17:00 UTC — submitting `until=2026-03-10T12:00:00` to the API (without a timezone offset) silently filters in UTC, cutting off 5 hours of Tuesday activity and including 5 extra hours from the prior period.

**Why it happens:**
GitHub CLI has a documented issue where it does not pass the user's `TZ` environment variable to API calls. ISO 8601 timestamps without an explicit offset are interpreted as UTC by GitHub's backend. Developers test in UTC and never notice the boundary error.

**How to avoid:**
Always construct date strings with an explicit UTC offset when calling the GitHub API or `gh` CLI. Compute the window in UTC from the start: determine the user's local timezone offset at runtime (via Python's `datetime.now().astimezone().utcoffset()`), convert the Wednesday-to-Tuesday window to UTC-anchored ISO 8601 strings (e.g., `2026-03-04T00:00:00-05:00`), and pass those directly to `gh`. Log the computed window in human-readable local time so the user can sanity-check it.

**Warning signs:**
- Activity from Tuesday afternoon is missing.
- A consistent "shift" appears where the window seems to start/end a few hours earlier or later than expected.
- The skill produces different results when run on Wednesday morning vs. Wednesday afternoon.

**Phase to address:**
GitHub data-fetching phase, specifically the time-window calculation utility. This is a silent bug — add a unit test with a known timezone offset.

---

### Pitfall 4: `add_chart()` Returns a GraphicFrame, Not a Chart

**What goes wrong:**
Code calls `slide.shapes.add_chart(XL_CHART_TYPE.BAR_CLUSTERED, x, y, cx, cy, chart_data)` and immediately tries to set `.chart.series[0].fill.fore_color.rgb = RGBColor(...)`. This raises `AttributeError` because `add_chart()` returns a `GraphicFrame` shape, and the actual chart is at `graphic_frame.chart`.

**Why it happens:**
The method name `add_chart` implies it returns a chart. Most other `add_*` methods (e.g., `add_textbox`, `add_picture`) return the shape directly usable. The `GraphicFrame` indirection is a DrawingML architectural detail that leaks into the API.

**How to avoid:**
Always capture the graphic frame and immediately extract the chart:
```python
graphic_frame = slide.shapes.add_chart(chart_type, x, y, cx, cy, chart_data)
chart = graphic_frame.chart
```
Similarly, `shapes.add_table()` returns a shape container, not the table itself — use `shape.table`. Establish this pattern in a helper utility at the start of the PowerPoint-generation phase.

**Warning signs:**
- `AttributeError: 'GraphicFrame' object has no attribute 'series'`
- Tests pass for text/image slides but fail when chart slides are added.

**Phase to address:**
PowerPoint generation phase, in the chart utility functions.

---

### Pitfall 5: Text Overflow Is Silent — Slides Look Wrong in PowerPoint, Not in Code

**What goes wrong:**
Long PR titles, long repository names, or a week with an unusually high number of PRs cause text to overflow text boxes and table cells. python-pptx does not raise an error or truncate — it generates a valid `.pptx` file where text simply renders outside its container in PowerPoint. The code "succeeds" and the file opens, but the presentation looks broken.

**Why it happens:**
python-pptx has limited autofit support. `MSO_AUTO_SIZE.TEXT_TO_FIT_SHAPE` and `word_wrap=True` exist but do not reliably shrink font size or truncate text when content exceeds the allocated space. The library does not simulate PowerPoint's rendering engine — it only writes XML.

**How to avoid:**
Apply defensive truncation in code before writing to shapes. Establish a `MAX_CHARS` constant for each text region (e.g., 80 chars for PR titles in tables, 120 chars for summary bullets). Truncate with an ellipsis (`…`) before assignment. For table rows, cap the number of rows displayed (e.g., 10 most recent PRs) and add a "...and N more" footer row if truncated. Test the output by opening the `.pptx` in LibreOffice or PowerPoint on a week with 15+ PRs.

**Warning signs:**
- Output looks fine in weeks with 3–4 PRs but breaks in busier weeks.
- Text in tables appears outside the slide boundary when opened in PowerPoint.
- No code errors are raised despite visual corruption.

**Phase to address:**
PowerPoint generation phase. Add an explicit "heavy week" test case (15+ PRs across 5+ repos).

---

### Pitfall 6: Categorization by Heuristic Is Unreliable Without Ground Truth Validation

**What goes wrong:**
The skill categorizes each PR into "bug fix," "new feature," or "new tool" based on PR title keywords or labels. PRs titled "Update X" get misclassified as features. PRs without labels are force-fitted into a category. The resulting "bug vs. feature breakdown" chart shows incorrect proportions that the user then presents in a meeting.

**Why it happens:**
Natural language categorization by keyword matching is inherently noisy. GitHub labels are inconsistently applied across repos in an organization. Developers vary wildly in how they title PRs ("fix typo in config" vs. "tweak settings").

**How to avoid:**
Use a tiered approach: (1) check for GitHub labels first (`bug`, `enhancement`, `feature`, `fix`) as the authoritative signal; (2) fall back to keyword matching on PR title for unlabeled PRs (`fix`, `bug`, `error`, `patch` → bug; `add`, `implement`, `new`, `create` → feature; `tool`, `script`, `cli` → tool); (3) bucket everything unmatched into "Other" rather than forcing a bad category. Make the category mapping visible in the output (e.g., include the category assigned in the PR table) so the user can spot misclassifications. Do not present a pie chart if the "Other" bucket exceeds 40% of PRs — that's a sign the heuristics aren't working.

**Warning signs:**
- "Other" category contains more than 30% of PRs in test runs.
- A PR titled "Fix broken pipeline" is categorized as "new feature."
- The user manually corrects the categorization after seeing the slide.

**Phase to address:**
Categorization/data-enrichment phase, immediately after raw data fetching.

---

### Pitfall 7: Querying All Repos in the Org Is Slow and Rate-Limit Dangerous

**What goes wrong:**
The skill iterates over every repository in `metabolomics-us` and calls the commits endpoint per repo per time window. A 50-repo org generates 50+ API calls per skill invocation. GitHub's secondary rate limits (abuse detection) trigger on bursts of sequential requests, returning 403 responses mid-execution.

**Why it happens:**
The naive approach to "find all my commits in an org" is to enumerate repos and query each. Secondary rate limits are not the same as the primary hourly quota — they fire on request frequency within a short window, not total count.

**How to avoid:**
Use `gh search commits --author=@me --owner=metabolomics-us --author-date=RANGE` as the first pass — this is a single request and returns commits across all repos. Use `gh pr list` with `--author=@me` as a second pass for PRs. Reserve per-repo API calls only for fetching additional details on a small set of already-identified commits/PRs. Add a short sleep (100–200ms) between any sequential per-repo API calls if they cannot be avoided.

**Warning signs:**
- Skill execution time exceeds 30 seconds.
- `403 secondary rate limit` errors appear partway through execution.
- The skill works for small orgs in testing but fails for larger ones.

**Phase to address:**
GitHub data-fetching phase. Establish the query strategy before writing any data-processing code.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Hardcode slide dimensions in pixels/points instead of using `Inches()`/`Cm()` | Faster first-pass layout | Slides look wrong on non-standard screen ratios; magic numbers are unmaintainable | Never — use `Inches()` from day one |
| Keyword-only categorization (no label check) | Simpler code | Systematically wrong categories for unlabeled PRs; user loses trust in output | MVP only, document the limitation |
| Skip pagination (assume <100 results per query) | No pagination logic needed | Silent data loss in high-activity weeks or large orgs | Never — implement pagination from the start |
| Single hardcoded timezone (e.g., UTC) | No timezone math | Wrong time windows for any user not in UTC | Never for the time-window calculation |
| Reuse default python-pptx blank template | No template file to maintain | Default styling looks generic; harder to brand later | Acceptable for MVP if styling is not a requirement |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| GitHub REST commits endpoint | Filtering by `since`/`until` uses committer date, not author date | Use `author-date` qualifier in `gh search commits` or explicitly document which date field is used |
| GitHub PR search | `gh pr list` defaults to open PRs; merged PRs require `--state=merged` | Always pass `--state=merged` and verify `mergedAt` is within the time window |
| `gh search commits` | Assumes results include all branches — they only include default branch | Supplement with PR data to capture branch work; document the limitation |
| python-pptx `add_chart()` | Treating return value as a `Chart` object | Capture as `GraphicFrame`, access chart via `.chart` property |
| python-pptx `add_table()` | Same GraphicFrame confusion | Capture shape, access table via `.table` property |
| python-pptx chart colors | Setting series colors via `.format.fill` without a template | Colors may not persist correctly without a themed template; set theme colors in a `.potx` file |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Per-repo commit enumeration | Slow execution, 403 errors | Use org-wide `gh search commits` as primary query | Org with 20+ repos |
| Fetching full commit history per repo | Extremely slow first run, potential timeout | Use `--author-date` date range filter on every API call | Any repo with >500 commits |
| Generating slides synchronously for each data point | Acceptable for 5 slides, slow for 10+ | This is acceptable at this scale — not a real concern | Not a concern for a personal weekly report |
| Loading all org repos to discover which ones have activity | Slow and wasteful | Derive repo list from search results, not org enumeration | Org with 50+ repos |

---

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Printing or logging GitHub tokens in skill output | Token exposure in terminal history or Claude Code logs | Never log the `GH_TOKEN` env var; use `gh auth status` to verify auth state without printing the token |
| Saving the generated `.pptx` to a shared or synced directory (e.g., iCloud Drive auto-sync) | Inadvertent distribution of work-in-progress data | Default save path should be a local-only directory; document where files are saved |
| Embedding raw commit messages in slides without sanitization | Not a security risk per se, but commit messages can contain internal project names or sensitive context | Acceptable for personal use, but note this if the skill is ever shared |

---

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Silent failure when GitHub returns 0 results (e.g., wrong date window) | User gets a blank or near-empty presentation and doesn't know why | Output the computed time window and raw data counts before generating slides; fail loudly with a clear message if 0 PRs and 0 commits are found |
| No progress indication during API calls | User sees nothing for 10–20 seconds and assumes the skill hung | Print brief status lines during execution ("Fetching PRs...", "Building slides...") |
| Overloaded slides (20+ table rows) | Presentation is unreadable in the meeting | Cap table rows, group by repo, use a summary "top N" approach |
| File saved to an unexpected location | User can't find the `.pptx` | Always print the absolute file path of the saved presentation as the final output line |
| Generic slide title ("Weekly Report") with no date range | User can't tell which week the presentation covers | Include the exact date range in the title slide (e.g., "Progress: Mar 4–10, 2026") |

---

## "Looks Done But Isn't" Checklist

- [ ] **Time window:** Verify the window is in UTC-adjusted form, not naive local time — check output on a non-UTC machine.
- [ ] **Merged PRs:** Confirm `--state=merged` is used and that `mergedAt` (not `createdAt`) falls in the window.
- [ ] **Pagination:** Verify more than 30 PRs/commits are handled — the default page size is 30 for most `gh` commands.
- [ ] **Chart object access:** Confirm every chart is accessed via `graphic_frame.chart`, not directly from `add_chart()` return value.
- [ ] **Text truncation:** Open the output `.pptx` after running against a "heavy" week (15+ PRs) — check for overflow.
- [ ] **Categorization coverage:** Confirm every PR is assigned a category and "Other" is a valid output bucket.
- [ ] **Empty state handling:** Run the skill on a week with no PRs and no commits — confirm a graceful message instead of a crash or empty slide deck.
- [ ] **Output path printed:** Confirm the saved file path is printed to the terminal on every successful run.
- [ ] **Date range on title slide:** Confirm the exact date range (not just "Weekly Report") appears on slide 1.

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Author/committer date confusion discovered after launch | MEDIUM | Add `author-date` qualifier to search query; re-run against historical weeks to validate; update skill prompt |
| Default-branch-only gap discovered | MEDIUM | Switch primary data source to PR list; commit search becomes supplementary only |
| Timezone off-by-hours discovered | LOW | Fix date construction to include UTC offset; re-run; bug is localized to one function |
| GraphicFrame confusion causing runtime crash | LOW | Fix accessor pattern; error is deterministic and easy to reproduce |
| Text overflow in busy weeks | LOW | Add truncation constants and re-run; no architectural change needed |
| Categorization quality unacceptable | MEDIUM | Add label-first logic, expand keyword lists, add "Other" bucket; no infrastructure change |
| Rate limit 403 mid-run | MEDIUM | Restructure to use search endpoint first; add delay between per-repo calls |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Author date vs. committer date confusion | GitHub data-fetching | Run against a known week, cross-check commit count with GitHub profile graph |
| Default-branch-only search gap | GitHub data-fetching | Verify a PR from a feature branch appears in output after merge |
| Timezone mismatch | GitHub data-fetching | Run skill from a machine set to UTC-5 and verify the window boundary is correct |
| `add_chart()` GraphicFrame confusion | PowerPoint generation (charts) | Unit test that chart series properties are accessible after creation |
| Text overflow | PowerPoint generation (layout) | Generate a test deck from a week with 15+ PRs and open in PowerPoint |
| Categorization unreliability | Data enrichment / categorization | Spot-check 10 PRs from a real week, verify categories match expectations |
| Per-repo query rate limiting | GitHub data-fetching | Measure execution time; confirm no 403 errors in an org with 20+ repos |

---

## Sources

- [GitHub community: Timezone not respected in gh CLI (Issue #1504)](https://github.com/cli/cli/issues/1504)
- [GitHub community: Commit timestamps discrepancy discussion](https://github.com/orgs/community/discussions/22695)
- [Working with dates in Git — Alex Peattie](https://alexpeattie.com/blog/working-with-dates-in-git/)
- [python-pptx: Working with charts (1.0.0 docs)](https://python-pptx.readthedocs.io/en/latest/user/charts.html)
- [python-pptx: Text autofit issue #969](https://github.com/scanny/python-pptx/issues/969)
- [python-pptx: Text fit issue #715](https://github.com/scanny/python-pptx/issues/715)
- [GitHub REST API: Search rate limits (30 req/min authenticated)](https://docs.github.com/en/rest/search/search?apiVersion=2022-11-28)
- [GitHub community: Difference in commit data GraphQL vs REST API #49492](https://github.com/orgs/community/discussions/49492)
- [GitHub community: GraphQL — Get all commits by all users in all orgs with filtered date #24590](https://github.com/orgs/community/discussions/24590)
- [GitHub community: Best practices for rate limits — frequent polling #156480](https://github.com/orgs/community/discussions/156480)
- [gh CLI manual: gh search commits](https://cli.github.com/manual/gh_search_commits)

---
*Pitfalls research for: GitHub activity reporting + PowerPoint generation (mos:progress skill)*
*Researched: 2026-03-10*
