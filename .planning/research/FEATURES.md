# Feature Research

**Domain:** Weekly developer activity report tool with PowerPoint output (Claude Code skill)
**Researched:** 2026-03-10
**Confidence:** MEDIUM — Core GitHub data features HIGH confidence from official docs and existing tools; PowerPoint capability HIGH confidence from python-pptx docs; categorization heuristics MEDIUM confidence from community patterns.

## Feature Landscape

### Table Stakes (Users Expect These)

Features users assume exist. Missing these = product feels incomplete.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| PR list with title, repo, status | Every GitHub reporting tool shows this; it's the atomic unit of developer work | LOW | gh CLI: `gh pr list --author @me --search "..."` covers this cleanly |
| Commit count per repo | Standard metric in all activity dashboards (GitHub Pulse, GitDailies, QuantEcon weekly report) | LOW | `gh api` or `git log` with date filter |
| Time window scoping | Tools without date filtering are useless for weekly cadence | LOW | Previous Wednesday through Tuesday noon per PROJECT.md |
| Activity categorization (bug / feature / other) | GitDailies, Gitmore, and git-commit-classifier all do this; meeting attendees expect organized output, not a raw list | MEDIUM | Heuristic from PR labels + commit message keywords; not ML, just keyword matching |
| Summary slide / executive overview | Every engineering status report template (Atlassian, Smartsheet, SlideTeam) leads with a summary | LOW | Auto-generated narrative from counts; 3-5 bullet points |
| .pptx output | Specified in PROJECT.md; standard for corporate IT meetings | MEDIUM | python-pptx is the standard library; supports slides, text, charts, tables |
| Scoped to user's own activity | The meeting is personal prep; everyone expects the report to be about the author | LOW | `--author @me` flag on all gh queries |
| Multi-repo aggregation | The metabolomics-us org has multiple repos; single-repo tools fail immediately | LOW | Loop across repos or use org-wide search |

### Differentiators (Competitive Advantage)

Features that set the product apart. Not required, but valuable.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Meeting-cadence-aligned time window | Tools default to calendar week or last 7 days; this aligns to Wednesday-to-Tuesday meeting rhythm, so the data matches exactly what was done since last meeting | LOW | Hard-code the Wednesday–Tuesday noon window; no config needed for now |
| PR detail table slide | Most tools show counts and dashboards; a slide with PR title, repo, description, and status is immediately usable in a meeting without context-switching to GitHub | LOW | python-pptx table; one row per PR |
| Work timeline slide | Shows when work landed during the week (not just totals), which helps explain sprint pacing to managers | MEDIUM | Bar chart or scatter plot using PR merge timestamps; python-pptx supports bar charts |
| Breakdown chart (bug vs. feature vs. tool) | Gives managers a quick read on the nature of the week's work without reading individual PR titles | LOW | Simple pie or bar chart from categorized PR counts |
| Clean, minimal design | Most auto-generated decks look visually noisy; a simple layout with consistent spacing reads as professional without design effort | MEDIUM | Use a small set of slide masters; resist adding too many elements per slide |
| Single-command invocation as Claude Code skill | No existing tool operates as a Claude Code slash command; the entire workflow (query → categorize → generate) runs in one step | MEDIUM | Skill file + prompt engineering for the Claude agent driving it |

### Anti-Features (Commonly Requested, Often Problematic)

Features that seem good but create problems.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Automated scheduling (cron/launchd) | "Set it and forget it" sounds convenient | Adds system-level complexity, requires persistent daemons, breaks when machine sleeps, creates stale reports if run at wrong time | Manual invocation as Claude Code skill; user controls timing |
| Email delivery of the deck | Seamless distribution sounds great | Requires SMTP config, auth management, attachment handling; adds a fragile integration layer for a personal tool | Save .pptx locally; user attaches and sends manually |
| Covering other team members' activity | Managers might want team view | Changes the data model entirely (org-wide API, privacy considerations, permission scoping); contradicts the personal prep use case | Separate skill if needed later; out of scope for v1 |
| Real-time / live data in slides | "Always current" sounds valuable | PowerPoint is a static format; live data requires complex integrations (OLE, data connections); python-pptx does not support live data connections | Generate fresh report on demand instead |
| Highly configurable templates / theming | Users might want custom branding | Template configuration systems are complex to build and maintain; most users never change defaults | Hardcode a clean, neutral theme; revisit if multiple users ever adopt the skill |
| Google Slides or PDF output | Broader compatibility | Adds a second output path, doubles testing surface, requires different libraries (google-api-python-client or PDF renderer) | PowerPoint only per PROJECT.md; .pptx opens in Google Slides if truly needed |
| Commit-level detail beyond PR context | "Show every commit" feels thorough | Commit noise obscures the meaningful unit (the PR); weekly meetings care about shipped work, not individual commits | Surface commit counts as a metric; keep commit messages out of the deck |
| AI-generated narrative prose per PR | Sounds impressive | Requires an LLM call per PR, adds latency, costs API tokens, risks hallucinating PR context when commit messages are terse | Use PR title + description directly; they already contain the human-written summary |

## Feature Dependencies

```
[Time window scoping]
    └──required by──> [PR list with title/repo/status]
    └──required by──> [Commit count per repo]
    └──required by──> [Activity categorization]
    └──required by──> [Work timeline slide]

[Activity categorization]
    └──required by──> [Breakdown chart (bug/feature/tool)]
    └──required by──> [Summary slide]

[PR list with title/repo/status]
    └──required by──> [PR detail table slide]
    └──required by──> [Work timeline slide]
    └──required by──> [Breakdown chart]

[Multi-repo aggregation]
    └──feeds into──> [PR list]
    └──feeds into──> [Commit count per repo]

[.pptx output]
    └──required by──> [PR detail table slide]
    └──required by──> [Summary slide]
    └──required by──> [Breakdown chart]
    └──required by──> [Work timeline slide]
    └──required by──> [Clean minimal design]
```

### Dependency Notes

- **Time window scoping required by everything:** All data queries depend on a resolved start/end datetime; the time window must be computed before any gh CLI call is made.
- **Activity categorization required by breakdown chart and summary:** The chart and the summary bullet "X bug fixes, Y features" both depend on having categorized the PR list; categorization must run before slide generation.
- **PR list required by three slides:** The detail table, the timeline, and the breakdown chart all consume the PR list; the PR fetch is the critical path.
- **Multi-repo aggregation feeds everything:** The org has multiple repos; a single-repo query would silently miss work. Aggregation must happen at the data layer, not the presentation layer.

## MVP Definition

### Launch With (v1)

Minimum viable product — what's needed to validate the concept.

- [ ] Time window computation (previous Wednesday through Tuesday noon) — the clock all other features depend on
- [ ] Multi-repo PR fetch for `metabolomics-us` org, scoped to current user — the core data source
- [ ] Commit count per repo in the same window — supplementary metric, low effort, expected
- [ ] Activity categorization by label + commit message keywords (bug / feature / tool) — enables the breakdown view
- [ ] Summary slide with counts and 3-5 key highlights — the most important single slide; what a manager reads first
- [ ] PR detail table slide (title, repo, status, description) — the most actionable slide; replaces manual GitHub browsing
- [ ] Breakdown chart slide (bug vs feature vs tool counts) — single chart, justifies the categorization effort
- [ ] .pptx saved to local working directory — required output format per PROJECT.md

### Add After Validation (v1.x)

Features to add once core is working.

- [ ] Work timeline slide (when PRs merged across the week) — add if users find the summary + table slides insufficient for meeting pacing questions
- [ ] Cleaner visual design pass — add if the initial output looks visually cluttered in real meeting use

### Future Consideration (v2+)

Features to defer until product-market fit is established.

- [ ] Configurable time windows — defer; Wednesday–Tuesday is hardcoded and correct for the stated use case
- [ ] Multiple output formats (PDF, Google Slides) — defer; .pptx is sufficient and opens in Google Slides anyway
- [ ] Team-level reporting — defer; fundamentally different use case requiring different data and permissions

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Time window scoping | HIGH | LOW | P1 |
| Multi-repo PR fetch | HIGH | LOW | P1 |
| Activity categorization | HIGH | MEDIUM | P1 |
| Summary slide | HIGH | LOW | P1 |
| PR detail table slide | HIGH | LOW | P1 |
| Breakdown chart slide | MEDIUM | LOW | P1 |
| Commit count per repo | MEDIUM | LOW | P1 |
| Work timeline slide | MEDIUM | MEDIUM | P2 |
| Clean visual design | MEDIUM | MEDIUM | P2 |
| Configurable time windows | LOW | MEDIUM | P3 |
| Multi-format output | LOW | HIGH | P3 |

**Priority key:**
- P1: Must have for launch
- P2: Should have, add when possible
- P3: Nice to have, future consideration

## Competitor Feature Analysis

| Feature | GitDailies | QuantEcon Action | Gitmore | Our Approach |
|---------|------------|-----------------|---------|--------------|
| Time window | Daily/weekly/monthly | Weekly (org-wide) | Daily/weekly/custom | Fixed Wednesday–Tuesday aligned to meeting |
| Output format | Web/Slack/email | GitHub comment markdown | Slack/email | Local .pptx |
| PR categorization | By label | None | AI-classified | Keyword heuristic (label + commit message) |
| Per-user scoping | Yes | Team aggregate | Both | Author-only (personal prep) |
| Charts/visualizations | Yes (web dashboard) | Summary tables only | Metrics trend | Charts embedded in .pptx slides |
| Meeting-ready output | No (requires copy-paste) | No | No | Yes — .pptx opens directly in meeting |
| Invocation | Scheduled/push | GitHub Actions trigger | Scheduled | Manual Claude Code slash command |

## Sources

- [GitDailies report content documentation](https://gitdailies.com/docs/reports/content/) — HIGH confidence, official docs
- [Gitmore GitHub reporting features](https://gitmore.io/git-reporting/tool/github) — MEDIUM confidence, marketing page
- [GitHub Pulse documentation](https://docs.github.com/en/repositories/viewing-activity-and-data-for-your-repository/using-pulse-to-view-a-summary-of-repository-activity) — HIGH confidence, official GitHub docs
- [QuantEcon action-weekly-report](https://github.com/QuantEcon/action-weekly-report) — HIGH confidence, open source reference implementation
- [python-pptx documentation](https://python-pptx.readthedocs.io/) — HIGH confidence, official library docs
- [GitHub Activity Digest & Notification Tools 2026](https://gitmore.io/blog/github-activity-digest-notification-tools) — MEDIUM confidence, industry overview
- [Atlassian project status report guide](https://www.atlassian.com/agile/project-management/status-report) — HIGH confidence, widely cited best practice source
- [Top 5 Software Development Weekly Status Report Templates](https://www.slideteam.net/blog/top-5-software-development-weekly-status-report-templates-with-examples-and-samples) — MEDIUM confidence, template analysis

---
*Feature research for: weekly GitHub activity report + PowerPoint generation (mos:progress skill)*
*Researched: 2026-03-10*
