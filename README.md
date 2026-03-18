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
| `/gw:analyze-app` | Analyze any application across specialist dimensions (UX, security, architecture, etc.) with role-adapted agents. Auto-detects app type (web, server, cli, mobile, library) and spawns 5-6 parallel specialists. |
| `/gw:saas-idea` | Harvest trending SaaS opportunities from the internet, score and rank them, then deep-dive with full business plan, marketing playbook, tech spec, implementation prompts, and pitch deck. Targets complete prototype deployment on AWS with PostgreSQL, Stripe, and Google OAuth. |
| `/gw:merge-it` | Ship current changes end-to-end: branch, PR, self-review, fix, generate presentation, merge. |
| `/gw:weekly-review` | Generate executive and technical PowerPoint presentations from GitHub activity (commits & PRs) across multiple orgs and repos. |
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

Output files are saved to the current working directory as `weekly-review-executive-YYYY-MM-DD.pptx` and `weekly-review-technical-YYYY-MM-DD.pptx`.

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

### /gw:analyze-app

```
/gw:analyze-app [--skip-cloud] [--skip-gsd] [--type web|server|cli|mobile|library]
```

Run from inside any project directory. Auto-detects the app type and spawns 5-6 parallel specialist agents (UX, security, architecture, performance, etc.) that each write a report to `.analysis/`. A synthesis agent then merges all findings into a prioritized `.analysis/REPORT.md`.

| Flag | Description |
|------|-------------|
| `--skip-cloud` | Skip cloud/infrastructure cost analysis |
| `--skip-gsd` | Skip automatic GSD project/milestone creation |
| `--type <type>` | Force app type instead of auto-detecting (`web`, `server`, `cli`, `mobile`, `library`) |

If GSD is installed, automatically creates a project or milestone from the recommended improvement phases.

### /gw:saas-idea

```
/gw:saas-idea [--focus <niche>] [--fresh] [--budget low|medium|high] [--pick <N>] [--skip-gsd]
```

Harvests trends from 8+ internet sources (Hacker News, Product Hunt, Reddit, Twitter/X, Google Trends, GitHub Trending, tech news, IndieHackers), scores SaaS ideas on a balanced scorecard (market demand, feasibility, revenue potential, competition, uniqueness), and generates a deep-dive for the selected idea.

**Fixed tech stack:** PostgreSQL, Google OAuth, Stripe, AWS, Terraform. Deployed as subdomain under `codingandmore.net`.

**Output files** are saved to `.saas-ideas/` in the current directory:
- `SHORTLIST.md` — Top 10 ranked ideas with scores
- `deep-dive/BUSINESS-PLAN.md` — Full business plan with competitive analysis
- `deep-dive/MARKETING-PLAYBOOK.md` — Go-to-market playbook with 10+ related forums
- `deep-dive/TECH-SPEC.md` — Architecture & MVP spec
- `deep-dive/IMPLEMENTATION-PROMPTS.md` — Ready-to-use Claude Code prompts for building
- `deep-dive/pitch-deck.pptx` — Investor/co-founder pitch deck
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

#### Examples

```
/gw:saas-idea                          # full run, all domains
/gw:saas-idea --focus devtools         # focus on developer tools
/gw:saas-idea --pick 3                 # deep-dive on idea #3 from last run
/gw:saas-idea --fresh --budget low     # force fresh harvest, solo dev scope
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

### /gw:update

```
/gw:update
```

Pulls the latest version of gw-skills from GitHub. All skills auto-check for updates when run, so this is usually not needed manually.
