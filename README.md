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
| `/gw:merge-it` | Ship current changes end-to-end: branch, PR, self-review, fix, generate presentation, merge. Includes post-merge log patrol if configured. |
| `/gw:worktree` | Manage git worktrees for concurrent feature development — create isolated workspaces, check status across all worktrees, merge all branches via PRs, and clean up after merge. |
| `/gw:merge-prs` | Discover, review, and integrate all `agent_merge`-labeled PRs into a single integration branch. Reads `.gw-intent.md` files to understand intent, resolves conflicts with AI assistance, runs tests after each merge, and creates a master integration PR. |
| `/gw:weekly-review` | Generate executive and technical PowerPoint presentations from GitHub activity (commits & PRs) across multiple orgs and repos. |
| `/gw:compete` | Competitive feature analysis with structured team debate, TDD test scaffolds, and implementation planning. |
| `/gw:research` | Multi-persona research with structured debate, parallel source investigation, and actionable output (report, PPTX, implementation, prototype). |
| `/gw:log-patrol` | Monitor production logs across SSH, CloudWatch, local files, and Docker — detects errors, classifies severity, correlates with codebase, generates reports, and creates GitHub issues with diagnosis plans. |
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

Generates executive and technical PowerPoint presentations from GitHub activity across multiple orgs and repos. Sources are saved to `~/.config/gw-skills/weekly-review.json` and reused automatically.

```
/gw:weekly-review --add metabolomics-us   # save a source
/gw:weekly-review                          # generate from all saved sources
/gw:weekly-review metabolomics-us          # one-off from a single source
```

See the skill file for full flag documentation.

### /gw:review-app

```
/gw:review-app [--skip-cloud] [--skip-planning] [--skip-testing] [--skip-security] [--skip-seo]
               [--skip-test-review] [--skip-defaults] [--skip-fix] [--skip-pptx] [--skip-recommend]
               [--skip-simplify] [--skip-test-gen]
               [--type web|server|cli|mobile|library|saas] [--scope full|recent|recent:N|timeframe:<spec>]
               [--team auto|ask|N] [--hire|--fire|--roster]
```

Run from inside any project directory. Auto-detects the app type and assembles a tailored specialist team from the shared workforce. Each specialist agent writes a report to `.analysis/`, then a synthesis agent merges all findings into `.analysis/REPORT.md`.

```
/gw:review-app                             # full run with auto-detected team
/gw:review-app --type saas --team ask      # force SaaS type, interactive team selection
/gw:review-app --scope recent:5            # analyze only last 5 commits
```

See the skill file for full flag documentation.

### /gw:audit-repo

```
/gw:audit-repo [<github-url>] [--deep] [--tools] [--refresh-threats] [--skip-pptx] [--skip-planning]
               [--publish] [--publish-repo <owner/repo>] [--publish-list]
```

Performs a security audit on a GitHub repository (or the current directory) to detect malicious code, credential theft, crypto attacks, backdoors, and supply chain risks. Produces dual reports: an executive summary with a pass/warn/fail verdict, and a full technical report with line-level evidence.

```
/gw:audit-repo https://github.com/some-user/suspicious-tool
/gw:audit-repo --deep                      # skip surface, go straight to deep scan
/gw:audit-repo --publish                   # publish findings to configured repo
```

See the skill file for full flag documentation.

### /gw:saas-idea

```
/gw:saas-idea [--focus <niche>] [--fresh] [--budget low|medium|high] [--pick <N>]
              [--skip-planning] [--auto] [--build] [--verify] [--team auto|ask|N] [--skip-debate]
```

Harvests trends from 8+ internet sources, scores SaaS ideas on a balanced scorecard, runs an optional team debate, and generates a deep-dive for the selected idea. Fixed tech stack: PostgreSQL, Google OAuth, Stripe, AWS, Terraform.

```
/gw:saas-idea                              # full run, all domains, with debate
/gw:saas-idea --focus devtools             # focus on developer tools
/gw:saas-idea --build --budget low         # full pipeline: harvest to build
```

See the skill file for full flag documentation.

### /gw:merge-it

```
/gw:merge-it [--skip-presentation] [--skip-review] [--skip-log-patrol]
             [--squash|--rebase] [--draft] [--reviewers <user,...>]
             [--labels <label,...>] [--base <branch>]
```

Run from any repo with uncommitted or staged changes. Ships your changes through a full workflow: branch, commit, push, PR, self-review, fix, presentation, merge. Includes post-merge log patrol if `.log-patrol/config.json` exists.

```
/gw:merge-it                               # full workflow
/gw:merge-it --squash --skip-presentation  # squash merge, no slides
/gw:merge-it --draft --reviewers alice,bob # draft PR with reviewers
```

See the skill file for full flag documentation.

### /gw:log-patrol

```
/gw:log-patrol [--add-source TYPE:CONN] [--remove-source IDX] [--list-sources]
               [--discover "PROMPT"] [--since DURATION] [--full]
               [--dry-run] [--skip-issues] [--repo owner/repo]
```

Monitors production logs across SSH, CloudWatch, local files, and Docker. Detects errors via pattern grep, classifies severity with AI, correlates with codebase, and generates GitHub issues with diagnosis plans. Tracks known errors across runs to avoid duplicates.

```
/gw:log-patrol                                          # full scan with issue creation
/gw:log-patrol --since 1h --dry-run                     # scan last hour, no issues
/gw:log-patrol --discover "docker-compose Flask app"    # auto-discover sources
```

See the skill file for full flag documentation.

### /gw:compete

```
/gw:compete [--deep] [--refresh] [--skip-pptx] [--skip-planning] [--skip-tests] [--team auto|ask|N]
            [--add "Competitor"] [--remove "Competitor"] [--list]
```

Auto-detects competitors from README and dependencies, researches them with parallel agents, runs structured debate (3 rounds with devil's advocate), and produces a prioritized feature implementation plan with TDD test scaffolds.

```
/gw:compete                                # full run, auto-detect everything
/gw:compete --deep                         # deep research with forum crawling
/gw:compete --add "Notion" --add "Coda"    # register competitors
```

See the skill file for full flag documentation.

### /gw:research

```
/gw:research <question> [--standalone] [--deep] [--team auto|ask|N] [--skip-pptx] [--skip-planning]
```

Takes a research question, assembles a specialist team, runs parallel research with persona-specific sources, conducts 3-round structured debate, and asks what to do with the findings. Output formats include PowerPoint, Markdown report, implementation plan, working prototype, or custom.

```
/gw:research What is the best approach to real-time data sync?
/gw:research --deep "Should we migrate from REST to GraphQL?"
/gw:research --standalone "Latest advances in transformer architectures?"
```

See the skill file for full flag documentation.

### /gw:workforce

```
/gw:workforce [--hire "Name" --background "..."] [--fire "Name"] [--edit "Name"] [--roster]
              [--analyze-slug <slug>] [--analyze-categories "..."] [--analyze-tags "..."]
```

Manages the shared persona workforce used by all team-driven skills. 37 default personas ship with the skill (23 with analysis capabilities). With no arguments, shows the full roster with skill participation badges.

```
/gw:workforce                                                          # show roster
/gw:workforce --hire "Chemist" --background "20 years in analytical chemistry"
/gw:workforce --fire "Chemist"
```

See the skill file for full flag documentation.

### /gw:update

```
/gw:update
```

Pulls the latest version of gw-skills from GitHub. All skills auto-check for updates when run, so this is usually not needed manually.

### /gw:worktree

```
/gw:worktree create <name> [--purpose "description"]
/gw:worktree status
/gw:worktree merge-all
/gw:worktree cleanup [name]
/gw:worktree execute <manifest-path>
```

Manage git worktrees for concurrent feature development. Each worktree gets its own branch and isolated workspace, allowing parallel work on multiple features. The `execute` subcommand reads feature manifests (generated by other skills) and builds all features in parallel with TDD.

```
/gw:worktree create auth-system --purpose "OAuth2 login flow"
/gw:worktree status                        # check progress across all worktrees
/gw:worktree merge-all                     # merge everything via PRs
```

See the skill file for full flag documentation.

### /gw:merge-prs

```
/gw:merge-prs [--dry-run] [--label <label>] [--skip-tests] [--base <branch>]
```

Discover and integrate all PRs labeled `agent_merge` into a single integration branch. Each PR's `.gw-intent.md` file is read to understand intent. PRs are merged one by one with AI-assisted conflict resolution and optional test runs between merges. The result is a master integration PR against the base branch.

```
/gw:merge-prs                          # full integration workflow
/gw:merge-prs --dry-run                # list agent_merge PRs without merging
/gw:merge-prs --skip-tests             # skip test runs between merges
```

## Concurrent Execution

Skills that produce artifacts (`research`, `compete`, `review-app`, `saas-idea`, `audit-repo`) automatically create an isolated branch for each execution. This allows multiple Claude Code sessions to run skills concurrently without conflicts.

### How it works

1. Each skill run creates a branch: `gw/<skill-name>/<date>-<short-id>`
2. All work happens on that branch
3. A `.gw-intent.md` file is committed to document purpose and decisions
4. A PR is auto-created with the `agent_merge` label
5. `/gw:merge-prs` integrates all agent PRs into one integration branch

### Example: three skills in parallel

```bash
# Terminal 1
/gw:research "market analysis for X"

# Terminal 2
/gw:compete --deep

# Terminal 3
/gw:review-app

# After all complete:
/gw:merge-prs
```

### Opting out

Use `--no-branch` on any skill to skip branch isolation:

```
/gw:research "quick question" --no-branch
```

## Creating Custom Personas

Personas are Markdown files with YAML frontmatter that define specialist profiles. They live in `workforce/` (custom) or `workforce/_defaults/` (shipped). All team-driven skills load personas from both directories.

### Quick start

```
/gw:workforce --hire "Data Engineer" --background "10 years building ETL pipelines and data warehouses"
```

This auto-derives `perspective`, `priorities`, `debate_style`, and `search_skills` from the background.

**Required fields:** `name`, `background`, `perspective`, `priorities`, `debate_style`, `search_skills`

### search_skills reference

Choose 3-5 from: `github`, `context7`, `arxiv`, `academic`, `google-scholar`, `pubmed`, `journals`, `stackoverflow`, `tech-blogs`, `api-docs`, `financial-data`, `sec-filings`, `market-reports`, `news`, `reddit`, `forums`, `product-hunt`, `g2-reviews`, `cve-databases`, `owasp`, `cloud-docs`, `benchmarks`, `testing-resources`, `dribbble`, `design-blogs`, `figma-community`, `mdn`, `css-tricks`, `web-dev-resources`, `ux-research`, `nielsen-norman`, `trade-publications`, `youtube`, `counter-narrative-sources`, `methodology-guides`, `statistics-resources`

### Creating personas during skill runs

You can create new personas on-the-fly during any team-driven skill run by using `--team ask`. At the team approval gate, select `[n]` (create new), enter the persona name, and the skill auto-derives all fields via WebSearch. The persona is saved to `workforce/{slug}.md` and added to the team immediately. After the skill completes, you'll be offered the option to contribute new personas back to gw-skills defaults via a PR.

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
