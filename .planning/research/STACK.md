# Stack Research

**Domain:** Claude Code skill — GitHub org activity querying + PowerPoint generation
**Researched:** 2026-03-10
**Confidence:** HIGH (GitHub CLI verified against official CLI docs; python-pptx verified against PyPI + readthedocs; skill format verified against official Claude Code docs)

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Python | 3.11+ | Script runtime for data processing and PPTX generation | python-pptx is Python-only; Python is already present on macOS and is the de facto choice for this library pairing. No Node.js PPTX library has comparable feature coverage. |
| python-pptx | 1.0.2 | Generate .pptx files with slides, charts, tables | The only mature Python library for native PPTX creation. Version 1.0.x (released Aug 2024) is the current stable release. Runs without PowerPoint installed. |
| matplotlib | 3.10.x | Render bar charts and timeline visualizations as images | python-pptx native charts are limited for complex layouts. Matplotlib produces publication-quality images that embed as pictures in PPTX slides — more reliable than native chart objects. |
| GitHub CLI (`gh`) | system-installed | Query PRs and commits from the `metabolomics-us` org | Already present in the user's environment. `gh search prs` and `gh search commits` support `--owner`, `--author`, `--created`/`--author-date`, and `--json` output. Requires no extra auth setup beyond existing gh login. |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `uv` | latest | Run the Python script with dependencies without polluting global Python | Use `uv run --with python-pptx --with matplotlib script.py` to execute the skill script with zero setup. No manual `pip install` or venv management required. |
| `jq` | system | Filter and transform `gh` JSON output in shell | Use in the SKILL.md `!`backtick`` injection step to pre-process gh output before handing to Python. Optional — Python's `json` stdlib can replace it. |
| `datetime` (stdlib) | built-in | Calculate the Wednesday-to-Tuesday-noon time window | No external dependency needed. Python's `datetime` + `timedelta` handles the rolling window logic. |
| `subprocess` / `json` (stdlib) | built-in | Call `gh` CLI from within the Python script | The skill invokes Python; Python calls `gh` via `subprocess.run` and parses JSON. Keeps the tool chain simple. |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| Claude Code skill system | Host and invoke the `mos:progress` slash command | Store at `~/.claude/skills/mos-progress/SKILL.md` for personal (cross-project) availability. Use `disable-model-invocation: true` to prevent accidental auto-invocation. |
| `gh` CLI | GitHub data access | User already has this. Skill should verify `gh auth status` at runtime and surface a clear error if not authenticated. |
| Python (system or uv-managed) | Script execution | macOS ships Python 3; `uv` provides a clean isolated execution path. The skill SKILL.md instructs Claude to invoke via `uv run` or `python3`, depending on what's available. |

## Installation

```bash
# python-pptx and matplotlib (if managing manually)
pip install "python-pptx==1.0.2" "matplotlib>=3.10"

# Preferred: use uv for isolated execution (no install step needed)
uv run --with "python-pptx==1.0.2" --with "matplotlib>=3.10" generate_progress.py

# Install uv itself (if not present)
curl -LsSf https://astral.sh/uv/install.sh | sh
```

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| python-pptx | `pptx` (Node.js) | Never for this project — the Node.js ecosystem has no equivalent library with chart and table support |
| python-pptx | Aspose.Slides for Python | Only if you need advanced rendering fidelity or 3D charts; it's a paid commercial library |
| matplotlib (image embed) | python-pptx native charts | Use native charts only for simple single-series column/bar charts where you don't need custom styling; matplotlib gives better visual control and more chart types |
| `gh` CLI | GitHub REST API via `requests` | Use the REST API directly if `gh` is not available or if you need pagination beyond `gh`'s `--limit` cap (currently 1000 for PRs) |
| `gh` CLI | PyGitHub library | Use PyGitHub if you want a typed Python client; for this skill the `gh` CLI is simpler and requires no additional auth token management |
| `uv run` | `venv` + `pip` | Use venv+pip if the user has strong objections to uv; uv is strictly superior for a one-command invocation pattern |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| `python-pptx` < 1.0.0 (i.e., 0.6.x) | 0.6.x is the legacy branch; 1.0.0 introduced a breaking API cleanup. PyPI still serves 0.6.22 as "stable" in some docs — don't be misled. | `python-pptx==1.0.2` |
| `plotly` for chart generation | Plotly's static export requires a Kaleido binary or an Orca process, adding significant setup friction for a CLI skill. | `matplotlib` — pure Python, no binaries |
| `python-docx` | Word document library; no PPTX support. Commonly confused. | `python-pptx` |
| GitHub Search API (REST `search/commits`) | Rate-limited to 10 requests/minute unauthenticated; authenticated hits 30/min. Commits returned are from the index, which lags real data by up to 1 minute and misses some commits. | `gh search commits` (wraps search API correctly with auth) + `gh api graphql` for per-repo commit history |
| Node.js `officegen` / `pptxgenjs` | PptxGenJS is actively maintained but has no native chart-from-data support comparable to python-pptx + matplotlib. Would require switching the whole runtime to Node. | `python-pptx` |
| GitHub GraphQL API directly (without `gh`) | Requires managing tokens, pagination cursors, and inline GraphQL strings. Much more code than `gh` CLI wrappers. | `gh api graphql` or `gh search` subcommands |

## Stack Patterns by Variant

**For PR data (the primary data source):**
- Use `gh search prs --author=@me --owner metabolomics-us --created ">=YYYY-MM-DD" --json title,repository,state,body,url,createdAt,closedAt,mergedAt,labels --limit 200`
- `--author=@me` resolves to the authenticated user automatically — no username hardcoding needed
- `--created` accepts GitHub date range syntax: `"2025-03-05..2025-03-11"` or `">=2025-03-05"`

**For commit data (supplementary — commits without PRs):**
- Use `gh search commits --author=@me --owner metabolomics-us --author-date ">=YYYY-MM-DD" --json repository,sha,commit --limit 200`
- Note: `gh search commits` uses the GitHub Search API, which indexes the default branch only. Commits on feature branches not yet merged to default may not appear.
- For merged PRs, the commit count is better obtained from `gh pr view <number> --json commits` on each PR.

**If commit counts per PR are needed:**
- `gh pr view <number> --json commits,additions,deletions` — returns full commit list for a single PR
- Fetch this for each PR returned by the search; acceptable for weekly volumes (typically < 50 PRs)

**For chart generation (bar charts + timeline):**
- Generate charts as PNG images using `matplotlib`, save to a `tempfile`, embed in the PPTX via `slide.shapes.add_picture()`
- Do NOT use python-pptx native `Chart` objects for the timeline — native charts don't support timeline/Gantt-style layouts. Use matplotlib for all charts to keep the code path consistent.

**For the SKILL.md invocation:**
- Use `!`backtick`` dynamic injection to pre-fetch `gh auth status` and surface errors before the Python script runs
- Store the Python script in `~/.claude/skills/mos-progress/scripts/generate_progress.py`
- Reference it with `${CLAUDE_SKILL_DIR}/scripts/generate_progress.py`

## Version Compatibility

| Package | Compatible With | Notes |
|---------|-----------------|-------|
| `python-pptx==1.0.2` | Python 3.8+ | No known issues on macOS Python 3.11/3.12. Requires `lxml`, `Pillow`, `XlsxWriter` (auto-installed via pip/uv). |
| `matplotlib>=3.10` | Python 3.9+ | Works alongside python-pptx with no conflicts. Uses `Agg` backend (non-interactive) for file output — no display required. Set `matplotlib.use('Agg')` before import to ensure headless operation. |
| `uv` latest | macOS arm64 + x86_64 | Handles Apple Silicon and Intel Macs transparently. |

## Sources

- [gh search prs — GitHub CLI Manual](https://cli.github.com/manual/gh_search_prs) — verified `--owner`, `--author`, `--created`, `--json` flags (HIGH confidence)
- [gh search commits — GitHub CLI Manual](https://cli.github.com/manual/gh_search_commits) — verified `--owner`, `--author`, `--author-date`, `--json` fields (HIGH confidence)
- [python-pptx on PyPI](https://pypi.org/project/python-pptx/) — confirmed version 1.0.2, released Aug 7, 2024 (HIGH confidence)
- [python-pptx Charts Documentation](https://python-pptx.readthedocs.io/en/latest/user/charts.html) — confirmed supported chart types and limitation on 3D/multi-plot/timeline charts (HIGH confidence)
- [Claude Code Skills Documentation](https://code.claude.com/docs/en/skills) — confirmed SKILL.md structure, `${CLAUDE_SKILL_DIR}`, `!`backtick`` injection, `disable-model-invocation` frontmatter (HIGH confidence)
- [matplotlib on PyPI](https://pypi.org/project/matplotlib/) — confirmed current version 3.10.x (HIGH confidence)
- [uv — Astral](https://github.com/astral-sh/uv) — confirmed `uv run --with` pattern for isolated script execution (MEDIUM confidence — verified via multiple secondary sources, not official docs directly)

---
*Stack research for: GitHub org activity reporting + PowerPoint generation (mos:progress skill)*
*Researched: 2026-03-10*
