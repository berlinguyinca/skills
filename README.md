# gw-skills

A collection of Claude Code skills by Gert Wohlgemuth. All skills are prefixed `gw:` and available as slash commands in Claude Code.

## Install

```bash
git clone https://github.com/berlinguyinca/skills.git ~/.gw-skills && ~/.gw-skills/install.sh
```

## Uninstall

```bash
~/.gw-skills/uninstall.sh && rm -rf ~/.gw-skills
rm -rf ~/.config/gw-skills  # remove saved config (source list, etc.)
```

## Available Skills

| Skill | Description |
|-------|-------------|
| `/gw:review-app` | Review any application across specialist dimensions (UX, security, architecture, etc.) with role-adapted agents. Auto-detects app type (web, server, cli, mobile, library, saas) and assembles a tailored team from the shared workforce. |
| `/gw:audit-repo` | Security audit for GitHub repositories — checks for malicious code, credential theft, crypto attacks, backdoors, and supply chain risks before local use. |
| `/gw:saas-idea` | Harvest trending SaaS opportunities from the internet, score and rank them, then deep-dive with full business plan, marketing playbook, tech spec, implementation prompts, and pitch deck. Targets complete prototype deployment on AWS with PostgreSQL, Stripe, and Google OAuth. |
| `/gw:merge-it` | Ship current changes end-to-end: branch, PR, self-review, fix, generate presentation, merge. |
| `/gw:weekly-review` | Generate executive and technical PowerPoint presentations from GitHub activity (commits & PRs) across multiple orgs and repos. |
| `/gw:compete` | Competitive feature analysis with structured team debate, TDD test scaffolds, and implementation planning. |
| `/gw:research` | Multi-persona research with structured debate, parallel source investigation, and actionable output (report, PPTX, implementation, prototype). |
| `/gw:workforce` | Manage the shared persona workforce used by all four team-driven skills (`gw:compete`, `gw:research`, `gw:review-app`, `gw:saas-idea`) — hire, fire, edit, and list personas. |
| `/gw:update` | Update all gw-skills to the latest version. |

## Updating

Skills automatically check for updates when you run them. If updates are available, you'll be asked whether to update before continuing.

You can also update manually at any time:

```
/gw:update
```

New skills are available immediately — no reinstall needed.

## How It Works

`install.sh` symlinks `.claude/commands/gw/` into `~/.claude/commands/gw/`, making all skills available globally in Claude Code. Since it's a symlink, `git pull` delivers new skills instantly.

## Skill Reference

### /gw:weekly-review

```
/gw:weekly-review [<org-or-repo>] [--from YYYY-MM-DD] [--to YYYY-MM-DD] [--author USERNAME]
/gw:weekly-review --add <org-or-repo>
/gw:weekly-review --remove <org-or-repo>
/gw:weekly-review --list
```

Generates two PowerPoint presentations from GitHub activity:
- **Executive deck** (max 5 slides) — plain English, no jargon, focused on user/lab impact
- **Technical deck** (max 30 slides) — detailed per-PR breakdowns, stats, charts, for IT staff

Output files are saved to `docs/gw/weekly-review-executive-YYYY-MM-DD.pptx` and `docs/gw/weekly-review-technical-YYYY-MM-DD.pptx`.

#### Multi-source support

You can track activity across multiple GitHub orgs and personal repos simultaneously. Sources are saved to `~/.config/gw-skills/weekly-review.json` and reused automatically.

**Setup (one-time):**
```
/gw:weekly-review --add metabolomics-us
/gw:weekly-review --add berlinguyinca/personal-project
/gw:weekly-review --add other-org
```

**Generate report from all saved sources:**
```
/gw:weekly-review
```

**One-off report from a single source (does not affect saved config):**
```
/gw:weekly-review metabolomics-us
```

**Manage saved sources:**
```
/gw:weekly-review --list              # show all saved sources
/gw:weekly-review --remove other-org  # remove a source
```

#### Options

| Flag | Description | Default |
|------|-------------|---------|
| `<org-or-repo>` | GitHub org name or `org/repo`. Overrides saved sources for this run. | Saved sources |
| `--from YYYY-MM-DD` | Start date (inclusive) | Last Wednesday |
| `--to YYYY-MM-DD` | End date (inclusive) | Today |
| `--author USERNAME` | GitHub username | Authenticated user |
| `--add SOURCE` | Save an org or repo to the sources list | |
| `--remove SOURCE` | Remove an org or repo from the sources list | |
| `--list` | Show all saved sources | |

### /gw:review-app

```
/gw:review-app [--skip-cloud] [--skip-gsd] [--skip-testing] [--skip-security] [--skip-seo]
               [--skip-test-review] [--skip-defaults] [--skip-fix] [--skip-pptx] [--skip-recommend]
               [--skip-simplify] [--skip-test-gen]
               [--type web|server|cli|mobile|library|saas] [--scope full|recent|recent:N|timeframe:<spec>]
               [--team auto|ask|N] [--hire|--fire|--roster]
```

Run from inside any project directory. Auto-detects the app type and assembles a tailored specialist team from the shared workforce (37 default personas, 23 analysis-capable). Specialists are loaded dynamically from persona files — mandatory analysts always run unless explicitly skipped. Each specialist agent writes a report to `.analysis/`, then a synthesis agent merges all findings into `.analysis/REPORT.md`. After fixes, runs code simplification on modified files and generates tests to enforce 80% coverage.

| Flag | Description | Default |
|------|-------------|---------|
| `--skip-cloud` | Skip cloud/infrastructure cost analysis | |
| `--skip-gsd` | Skip automatic GSD project/milestone creation | |
| `--skip-testing` | Skip testing/QA analysis | |
| `--skip-security` | Skip security analysis | |
| `--skip-seo` | Skip SEO analysis | |
| `--skip-test-review` | Skip test sense-checking | |
| `--skip-defaults` | Skip coding defaults enforcement | |
| `--skip-fix` | Skip catch-and-fix phase | |
| `--skip-pptx` | Skip PowerPoint generation | |
| `--skip-recommend` | Skip skill recommendations | |
| `--skip-simplify` | Skip code simplification after fixes | |
| `--skip-test-gen` | Skip test generation for coverage enforcement | |
| `--type <type>` | Force app type (`web`, `server`, `cli`, `mobile`, `library`, `saas`) | Auto-detect |
| `--scope <mode>` | Scope analysis (`full`, `recent`, `recent:N`, `timeframe:<spec>`) | `full` |
| `--team auto\|ask\|N` | Team assembly mode | `auto` |
| `--hire/--fire/--roster` | Redirect to `/gw:workforce` for persona management | |

**Workforce** specialists are loaded from persona files. `--team auto` (default) skips the approval gate and auto-proceeds. Use `--team ask` for interactive team selection.

If GSD is installed, automatically creates a project or milestone from the recommended improvement phases.

### /gw:audit-repo

```
/gw:audit-repo [<github-url>] [--deep] [--tools] [--refresh-threats] [--skip-pptx] [--skip-gsd]
               [--publish] [--publish-repo <owner/repo>] [--publish-list]
```

Performs a security audit on a GitHub repository (or the current directory) to detect malicious code, credential theft, crypto attacks, backdoors, and supply chain risks before you clone or use it locally. Analysis runs in two tiers: a fast surface scan that checks repo metadata, contributor patterns, and file signatures, followed by an optional deep scan that inspects every source file, dependency, and build script. Findings are classified into 6 threat categories (malicious code injection, credential/token theft, cryptominer/resource hijack, backdoor/reverse shell, supply chain attack, and data exfiltration). Threat intelligence is self-updating — patterns and indicators are cached locally and refreshed automatically so future audits benefit from prior findings. Produces dual reports: an executive summary with a pass/warn/fail verdict and risk assessment, and a full technical report with line-level evidence. Optional PowerPoint decks are generated for both audiences.

**Output files:**
- `.audit/REPORT.md` — Full technical security audit report
- `.audit/EXECUTIVE-SUMMARY.md` — Executive summary with verdict and risk assessment
- `docs/gw/audit-executive-{repo}-{date}.pptx` — Executive presentation
- `docs/gw/audit-technical-{repo}-{date}.pptx` — Technical presentation
- `~/.config/gw-skills/threat-intel.json` — Cached threat intelligence (auto-maintained)

#### Options

| Flag | Description | Default |
|------|-------------|---------|
| `<github-url>` | GitHub repository URL to audit | Current directory |
| `--deep` | Skip surface scan, go straight to deep source-level analysis | Surface first |
| `--tools` | Include external security tools (e.g., Semgrep, Trivy) if available | Off |
| `--refresh-threats` | Force refresh of cached threat intelligence | Auto (if >7d old) |
| `--skip-pptx` | Skip PowerPoint generation | |
| `--skip-gsd` | Skip GSD project/milestone creation | |
| `--publish` | Publish findings to configured audit findings repo | Off |
| `--publish-repo <owner/repo>` | Configure the GitHub repo for publishing audit findings | |
| `--publish-list` | List all previously published audit findings | |

#### Examples

```
/gw:audit-repo https://github.com/some-user/suspicious-tool
/gw:audit-repo                                    # audit current directory
/gw:audit-repo https://github.com/org/repo --deep  # skip surface, go straight to deep scan
/gw:audit-repo --tools                             # include external security tools
/gw:audit-repo --publish                           # publish findings to configured repo
/gw:audit-repo --publish-repo owner/audit-findings  # configure publish target
```

### /gw:saas-idea

```
/gw:saas-idea [--focus <niche>] [--fresh] [--budget low|medium|high] [--pick <N>]
              [--skip-gsd] [--auto] [--build] [--verify] [--team auto|ask|N] [--skip-debate]
```

Harvests trends from 8+ internet sources (Hacker News, Product Hunt, Reddit, Twitter/X, Google Trends, GitHub Trending, tech news, IndieHackers), scores SaaS ideas on a balanced scorecard (market demand, feasibility, revenue potential, competition, uniqueness), runs an optional team debate to stress-test the top ideas, and generates a deep-dive for the selected idea.

**Fixed tech stack:** PostgreSQL, Google OAuth, Stripe, AWS, Terraform. Deployed as subdomain under `codingandmore.net`.

**Output files** are saved to `.saas-ideas/` in the current directory:
- `SHORTLIST.md` — Top 10 ranked ideas with scores
- `CONSENSUS.md` — Team debate consensus (if debate enabled)
- `debate/round1/*.md` — Position statements per persona
- `debate/round2/*.md` — Cross-examination responses
- `deep-dive/BUSINESS-PLAN.md` — Full business plan with competitive analysis
- `deep-dive/MARKETING-PLAYBOOK.md` — Go-to-market playbook with 10+ related forums
- `deep-dive/TECH-SPEC.md` — Architecture & MVP spec
- `deep-dive/IMPLEMENTATION-PROMPTS.md` — Ready-to-use Claude Code prompts for building
- `docs/gw/pitch-deck.pptx` — Investor/co-founder pitch deck
- `REPORT.md` — Executive summary
- `history.json` — Run history for freshness tracking

#### Options

| Flag | Description | Default |
|------|-------------|---------|
| `--focus <niche>` | Narrow to a domain (e.g., "healthcare", "devtools") | All domains |
| `--fresh` | Force fresh harvest even if recent data exists | Re-use if <24h |
| `--budget low\|medium\|high` | Team size: solo / small team / funded | `medium` |
| `--pick <N>` | Deep-dive on idea #N from previous shortlist | Interactive |
| `--skip-gsd` | Skip GSD project/milestone creation | Auto-detect |
| `--auto` | Auto-select top idea, skip interactive prompts | Interactive |
| `--build` | Auto-select, verify, and build via GSD (implies --auto) | Interactive |
| `--verify` | Run coherence verification on deep-dive artifacts | Off |
| `--team auto\|ask\|N` | Debate team assembly mode | `auto` |
| `--skip-debate` | Skip the idea debate phase (Phase 2.5) | Debate enabled |

#### Examples

```
/gw:saas-idea                          # full run, all domains, with debate
/gw:saas-idea --focus devtools         # focus on developer tools
/gw:saas-idea --pick 3                 # deep-dive on idea #3 from last run
/gw:saas-idea --fresh --budget low     # force fresh harvest, solo dev scope
/gw:saas-idea --auto --skip-debate     # fast run: auto-select #1, no debate
/gw:saas-idea --build --budget low     # full pipeline: harvest → build (skips debate)
```

### /gw:merge-it

```
/gw:merge-it
```

Run from any repo with uncommitted or staged changes. Ships your changes through a full workflow:

1. Create branch and commit
2. Push and open PR
3. Self-review the diff (correctness, security, performance)
4. Propose fixes with an approval gate — **you decide** what gets applied
5. Apply approved fixes and generate a PowerPoint presentation of changes
6. Merge PR

### /gw:compete

```
/gw:compete [--deep] [--refresh] [--skip-pptx] [--skip-gsd] [--skip-tests] [--team auto|ask|N]
            [--add "Competitor"] [--remove "Competitor"] [--list]
```

Run from inside any project directory. Auto-detects competitors from README and dependencies, researches them with parallel agents, assembles a team of diverse personas for structured debate (3 rounds with devil's advocate), and produces a prioritized feature implementation plan with TDD test scaffolds.

**Output files** are saved to `.competitors/` in the current directory:
- `registry.json` — Registered competitors
- `research/{slug}.md` — Per-competitor research findings
- `feature-matrix.json` — Feature-by-feature comparison
- `debate/CONSENSUS.md` — Team debate synthesis
- `SELECTED.json` — User's feature selections
- `REPORT.md` — Full competitive analysis report
- `docs/gw/compete-report-YYYY-MM-DD.pptx` — Presentation

**Workforce** personas persist globally in the gw-skills repo (`workforce/` directory). 37 default personas ship with the skill; manage via `/gw:workforce`.

#### Options

| Flag | Description | Default |
|------|-------------|---------|
| `--deep` | Enable deep research (Reddit, HN, G2, forums) | Lightweight |
| `--refresh` | Force re-research even if cache is recent | Re-use if <7d |
| `--skip-pptx` | Skip PowerPoint generation | |
| `--skip-gsd` | Skip GSD project/milestone creation | |
| `--skip-tests` | Skip TDD test scaffold generation | |
| `--team auto\|ask\|N` | Team assembly mode (`auto` skips approval gate) | `auto` |
| `--add "Name"` | Register a competitor | |
| `--remove "Name"` | Remove a competitor | |
| `--list` | Show registered competitors | |

#### Examples

```
/gw:compete                                    # full run, auto-detect everything
/gw:compete --deep                             # deep research with forum crawling
/gw:compete --add "Notion" --add "Coda"        # register competitors
/gw:compete --team 8 --deep --skip-gsd         # large team, deep research, no GSD
```

### /gw:research

```
/gw:research <question> [--standalone] [--deep] [--team auto|ask|N] [--skip-pptx] [--skip-gsd]
```

Takes a research question, assembles a specialist team from the shared workforce, runs parallel research with persona-specific sources (each persona uses their `search_skills` to prioritize different source types), conducts 3-round structured debate (position statements, cross-examination with devil's advocate, supervisor synthesis), and asks what to do with the findings.

**Output formats** (choose one or more after research completes):
1. **PowerPoint** — presentation with findings and recommendations → `docs/gw/research-{slug}-YYYY-MM-DD.pptx`
2. **Report** — detailed Markdown report (optional .docx via pandoc) → `.research/{slug}/REPORT.md`
3. **Implement** — create GSD project/milestone from recommendations (project-contextual only)
4. **Prototype** — working code demonstrating the recommended approach → `.research/{slug}/prototype/`
5. **Custom** — describe what you want

**Research artifacts** are saved to `.research/YYYY-MM-DD-{slug}/`:
- `agents/{persona}.md` — per-persona research findings
- `debate/round1/{persona}.md` — position statements
- `debate/round2/{persona}.md` — cross-examination responses
- `CONSENSUS.md` — supervisor synthesis

**Workforce** personas are shared with `/gw:compete`. 37 default personas ship with the skill; manage via `/gw:workforce`.

#### Options

| Flag | Description | Default |
|------|-------------|---------|
| `<question>` | The research question (quoted or unquoted) | Interactive prompt |
| `--standalone` | Force standalone mode (ignore project context) | Auto-detect |
| `--deep` | Enable deep research (more sources, historical context, quantitative data) | Lightweight |
| `--team auto\|ask\|N` | Team assembly mode (`auto` skips approval gate) | `auto` |
| `--skip-pptx` | Skip PowerPoint generation | |
| `--skip-gsd` | Skip GSD project/milestone creation | |

#### Examples

```
/gw:research What is the best approach to real-time data sync?
/gw:research --deep "Should we migrate from REST to GraphQL?"
/gw:research --standalone "What are the latest advances in transformer architectures?"
/gw:research --team 8 --deep "How should we price our API?"
```

### /gw:workforce

```
/gw:workforce [--hire "Name" --background "..."] [--fire "Name"] [--edit "Name"] [--roster]
              [--analyze-slug <slug>] [--analyze-categories "..."] [--analyze-tags "..."]
```

Manages the shared persona workforce used by all four team-driven skills (`/gw:compete`, `/gw:research`, `/gw:review-app`, `/gw:saas-idea`). Personas persist globally in the gw-skills repo (`workforce/` directory). 37 default personas ship with the skill (23 with analysis capabilities).

With no arguments, shows the full roster with skill participation badges.

#### Options

| Flag | Description |
|------|-------------|
| `--hire "Name" --background "..."` | Create a new persona (auto-derives perspective, priorities, debate_style, search_skills) |
| `--fire "Name"` | Remove a custom persona (default personas cannot be fired) |
| `--edit "Name"` | Edit a custom persona's fields interactively |
| `--roster` | List all personas with search_skills and skill badges (default when no flags) |
| `--analyze-slug <slug>` | When hiring, make persona participate in `gw:review-app` |
| `--analyze-categories "..."` | Categories for analysis (required with --analyze-slug) |
| `--analyze-tags "..."` | APP_TYPE tags for analysis relevance (default: "all") |

#### Examples

```
/gw:workforce                                                          # show roster
/gw:workforce --hire "Chemist" --background "20 years in analytical chemistry"
/gw:workforce --hire "Chemist" --background "20 years in analytical chemistry" --analyze-slug chemistry --analyze-categories "Compound analysis, safety" --analyze-tags "all"
/gw:workforce --fire "Chemist"
/gw:workforce --edit "Chemist"
/gw:workforce --roster
```

### /gw:update

```
/gw:update
```

Pulls the latest version of gw-skills from GitHub. All skills auto-check for updates when run, so this is usually not needed manually.

## Creating Custom Personas

Personas are Markdown files with YAML frontmatter that define specialist profiles. They live in the `workforce/` directory (custom) or `workforce/_defaults/` (shipped with gw-skills). All team-driven skills (`gw:compete`, `gw:research`, `gw:review-app`, `gw:saas-idea`) load personas from both directories.

### Quick start

The easiest way to create a persona:

```
/gw:workforce --hire "Data Engineer" --background "10 years building ETL pipelines and data warehouses"
```

This auto-derives `perspective`, `priorities`, `debate_style`, and `search_skills` from the background.

### Manual creation

Create a file at `workforce/{slug}.md` with this structure:

```yaml
---
name: Data Engineer
background: 10 years building ETL pipelines, data warehouses, and real-time streaming systems
perspective: Data flow, pipeline reliability, schema evolution, query performance
priorities: Is the data pipeline reliable? Can we replay failures? What's the latency?
debate_style: Pipeline architecture analysis, SLA references, "show me the data lineage"
search_skills: github, tech-blogs, context7, stackoverflow, benchmarks
---
```

**Required fields:** `name`, `background`, `perspective`, `priorities`, `debate_style`, `search_skills`

### Making a persona participate in gw:review-app analysis

Add these fields to the frontmatter to enable analysis capabilities:

```yaml
analyze_slug: data-pipeline        # output file slug (e.g., .analysis/07-data-pipeline.md)
analyze_categories: "ETL reliability, schema evolution, query performance, data lineage"
analyze_tags: server,saas           # which APP_TYPEs this specialist is relevant to ("all" for universal)
analyze_mandatory: false            # true = always selected unless skipped
analyze_skip_flag: --skip-data      # the --skip flag that disables this specialist
```

### Adding specialist-specific instructions

Content after the frontmatter closing `---` is appended to the agent prompt when the persona runs in `gw:review-app`. Use this for detailed analysis instructions:

```yaml
---
name: Data Engineer
background: ...
analyze_slug: data-pipeline
analyze_categories: "ETL, schema, performance"
analyze_tags: server,saas
---

ADDITIONAL DATA PIPELINE INSTRUCTIONS:
- Check for idempotent pipeline runs (can we safely re-run?)
- Flag any raw SQL without parameterized queries as CRITICAL
- Check for schema migration tooling (Alembic, Flyway, Prisma Migrate)
- Pipeline without retry/dead-letter handling = WARNING
```

### search_skills reference

Choose 3-5 from: `github`, `context7`, `arxiv`, `academic`, `google-scholar`, `pubmed`, `journals`, `stackoverflow`, `tech-blogs`, `api-docs`, `financial-data`, `sec-filings`, `market-reports`, `news`, `reddit`, `forums`, `product-hunt`, `g2-reviews`, `cve-databases`, `owasp`, `cloud-docs`, `benchmarks`, `testing-resources`, `dribbble`, `design-blogs`, `figma-community`, `mdn`, `css-tricks`, `web-dev-resources`, `ux-research`, `nielsen-norman`, `trade-publications`, `youtube`, `counter-narrative-sources`, `methodology-guides`, `statistics-resources`

### Creating personas during skill runs

You can create new personas on-the-fly during any team-driven skill run (`/gw:compete`, `/gw:research`, `/gw:review-app`, `/gw:saas-idea`) without leaving the workflow:

1. Run any skill with `--team ask` to enable interactive team assembly
2. At the team approval gate, select `[n]` (create new)
3. Enter the persona name — the skill researches the role via WebSearch and auto-derives all persona fields
4. Review and confirm the auto-derived persona (or edit individual fields)
5. The persona is saved to `workforce/{slug}.md` and added to the team immediately
6. You can create multiple personas before accepting the team

After the skill completes, if any personas were created during the run, you'll be offered the option to contribute them back to gw-skills defaults via a PR. This copies the persona to `workforce/_defaults/`, creates a branch, and opens a pull request automatically.

For `/gw:review-app`, the creation flow additionally asks whether the persona should participate in analysis runs and prompts for `analyze_slug`, `analyze_categories`, and `analyze_tags` fields.

## Contributing Personas

Custom personas can be contributed back to gw-skills for everyone to use.

### How to contribute

1. **Fork the repo** on GitHub
2. **Create your persona** in `workforce/_defaults/` (not `workforce/` — that's for personal personas)
3. **Follow the naming convention:** `workforce/_defaults/{slug}.md` where slug is lowercase-hyphenated (e.g., `data-engineer.md`)
4. **Include all required fields** in the frontmatter
5. **Open a PR** with a clear description of what the persona does and which skills it enhances

### Contribution guidelines

- **One persona per file** — don't bundle multiple personas
- **Background should be specific** — "10 years in X" is better than "experienced in X"
- **search_skills must be relevant** — pick sources the persona would actually use
- **Test your persona** — run `/gw:workforce --roster` to verify it loads, then use it in a `/gw:research` or `/gw:compete` run
- **analysis fields are optional** — only add `analyze_*` fields if the persona should participate in `gw:review-app`
- **Don't modify existing default personas** — if you want to improve one, open an issue first

### PR template

```
## New Persona: {Name}

**Background:** {one-line summary}
**Skills used by:** gw:compete, gw:research {and/or gw:review-app if analyze_slug is set}
**Tested with:** {which skill you tested it with and a brief result}
```
