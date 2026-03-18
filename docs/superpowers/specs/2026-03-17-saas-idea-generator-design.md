# SaaS Idea Generator — Design Spec

**Date:** 2026-03-17
**Skill:** `/gw:saas-idea`
**Status:** Approved

## Overview

A Claude Code skill that harvests trending news, pain points, and opportunities from 8+ internet sources, scores them on a balanced scorecard, presents a ranked shortlist of SaaS ideas, then generates a full deep-dive for the selected idea — including business plan, marketing playbook, tech spec, implementation prompts, and pitch deck. Integrates with GSD and superpowers for immediate execution.

## Skill File Frontmatter

The skill file at `.claude/commands/gw/saas-idea.md` must include:

```yaml
---
name: saas-idea
description: Harvest trending SaaS opportunities from the internet, score and rank them, then deep-dive into the best idea with full business plan, marketing playbook, and implementation prompts
argument-hint: "[--focus <niche>] [--fresh] [--budget low|medium|high] [--pick <N>] [--skip-gsd]"
---
```

## Step 0 — Update Check

Resolve the gw-skills repo directory and run its update check script:

```bash
GW_REPO="$(cd "$(readlink ~/.claude/commands/gw)/../../.." 2>/dev/null && pwd)" || GW_REPO="$HOME/.gw-skills"
bash "$GW_REPO/check-update.sh" 2>/dev/null || true
```

If the output contains `UPDATE_AVAILABLE`, tell the user how many commits behind they are and ask: "gw-skills has updates available. Run /gw:update to install them, or continue?" If they want to update, invoke `/gw:update` and stop. Otherwise continue. If the script is missing or fails, skip silently.

---

## Step 1 — Parse Arguments & Pre-flight

Parse the arguments: "$ARGUMENTS"

- If `--focus <niche>` is present, set FOCUS=niche (string). Default: empty (no filter)
- If `--fresh` is present, set FORCE_FRESH=true. Default: false
- If `--budget <level>` is present, set BUDGET=level (one of: low, medium, high). Default: medium
- If `--pick <N>` is present, set PICK_ID=N (integer). Default: empty (interactive)
- If `--skip-gsd` is present, set SKIP_GSD=true. Default: false

### Budget semantics

The BUDGET flag modifies behavior in Phases 2-4:

| Budget | Team context | Feasibility bias | Tech spec scope | Revenue projections |
|--------|-------------|-------------------|-----------------|---------------------|
| `low` | Solo dev with AI tooling | Strongly favor ideas one person can ship in 2-4 weeks | Minimal infra, free-tier services only | Conservative, bootstrapped |
| `medium` | 2-5 person team with AI tooling | Favor ideas shippable in 4-8 weeks | Moderate infra, paid services OK | Moderate, some paid acquisition budget |
| `high` | Funded team (5-15) | Larger scope OK, 8-16 week MVPs acceptable | Full infra, enterprise services | Aggressive, investor-backed growth |

### Freshness check

1. If `history.json` does not exist, create it with `{"runs": []}` and treat all ideas as new.
2. If PICK_ID is set:
   - Read `.saas-ideas/SHORTLIST.md`. If it does not exist, tell user "No previous run found. Run `/gw:saas-idea` first without `--pick`." and stop.
   - Validate PICK_ID is between 1 and 10. If out of range, tell user and stop.
   - Check `history.json` for the most recent run date. If older than 7 days, warn: "Previous shortlist is {N} days old. Results may be stale. Continue anyway? [y/n]"
   - If user continues, skip to Phase 3 with the selected idea.
3. If FORCE_FRESH is false and `.saas-ideas/SHORTLIST.md` exists and is less than 24 hours old:
   - Ask user: "A recent shortlist exists (generated {time}). Re-use it and pick an idea, or harvest fresh data?"
   - If re-use: skip Phase 1 and Phase 2 synthesis, go straight to interactive selection on existing `SHORTLIST.md`.
   - If fresh: continue to Phase 1.
4. Otherwise, continue to Phase 1.

Run `mkdir -p .saas-ideas/harvest .saas-ideas/deep-dive`

---

## Skill Interface

**Command:** `/gw:saas-idea`

```
/gw:saas-idea [--focus <niche>] [--fresh] [--budget low|medium|high] [--pick <N>] [--skip-gsd]
```

| Flag | Description | Default |
|------|-------------|---------|
| `--focus <niche>` | Narrow research to a domain (e.g., "healthcare", "devtools", "education") | No filter — all domains |
| `--fresh` | Force fresh harvest even if a recent run exists (<24h) | Re-use if <24h old |
| `--budget low\|medium\|high` | Team size/investment level (low=solo, medium=2-5, high=funded) | `medium` (2-5 people) |
| `--pick <N>` | Skip straight to deep-dive on idea #N from a previous run | Interactive selection |
| `--skip-gsd` | Skip GSD project/milestone creation | Auto-detect GSD |

**State directory:** `.saas-ideas/` in the current working directory.

```
.saas-ideas/
  harvest/                      # Raw research per source
    01-hackernews-indiehackers.md
    02-producthunt.md
    03-reddit.md
    04-twitter.md
    05-google-trends.md
    06-github-technews.md
  SHORTLIST.md                  # Scored & ranked top 10 ideas
  history.json                  # Past runs + selected ideas (for freshness)
  deep-dive/                    # Generated after selection
    BUSINESS-PLAN.md
    MARKETING-PLAYBOOK.md
    TECH-SPEC.md
    IMPLEMENTATION-PROMPTS.md
    pitch-deck.pptx
  REPORT.md                     # Executive summary tying it all together
```

---

## Phase 1: Parallel Harvest

Six background agents, each fetching from a cluster of sources. All launched in a single message with `run_in_background=true`.

### Source Access Strategy

Each agent must use the correct tool for each source:

| Source | Tool | Method |
|--------|------|--------|
| Hacker News | `WebFetch` | Fetch `https://news.ycombinator.com`, `https://news.ycombinator.com/show`, `https://news.ycombinator.com/ask` directly — these render as plain HTML |
| IndieHackers | `WebSearch` | Search `site:indiehackers.com` + relevant keywords — direct fetch may require auth |
| Product Hunt | `WebSearch` | Search `site:producthunt.com` + "launched today/this week" — PH pages are JS-heavy |
| Reddit | `WebFetch` | Fetch `https://old.reddit.com/r/{subreddit}/top/?t=week` — old.reddit renders as HTML. Fallback: `WebSearch` with `site:reddit.com` |
| Twitter/X | `WebSearch` | Search for trending discourse via `WebSearch` queries like "trending SaaS twitter 2026", "tech twitter discussion {topic}". Do NOT attempt to `WebFetch` twitter.com — it requires auth. |
| Google Trends | `WebSearch` | Search `"google trends" rising searches {category} 2026`, `"trending searches" {niche}`. Do NOT `WebFetch` trends.google.com — it is JS-rendered and will return empty content. |
| GitHub Trending | `WebFetch` | Fetch `https://github.com/trending` and `https://github.com/trending?since=weekly` — these render as HTML |
| TechCrunch / The Verge / Ars | `WebSearch` + `WebFetch` | `WebSearch` for recent articles, then `WebFetch` on top results for full content |

### Focus filter propagation

When FOCUS is set, each harvest agent receives: "Focus your research on the **{FOCUS}** domain. Only surface signals directly relevant to {FOCUS}. Ignore signals from unrelated domains."

When FOCUS is empty, agents search broadly across all domains.

### Agent assignments

| Agent | Sources | Extracts |
|-------|---------|----------|
| **HN + IndieHackers** | Hacker News front page, Show HN, Ask HN, IndieHackers top posts | Trending topics, pain points, revenue numbers shared |
| **Product Hunt** | Today's/this week's launches, trending products | New SaaS launches, categories getting traction, feature patterns |
| **Reddit** | r/SaaS, r/startups, r/Entrepreneur, r/microSaaS, r/IndieBiz | Complaints (= opportunities), "I wish X existed" posts, willingness to pay |
| **Twitter/X + Social** | Tech influencer discourse, trending hashtags | Buzz topics, emerging tools, gaps in the market |
| **Google Trends + SEO** | Google Trends rising searches, "how to" and "best X" queries | Search demand signals, growing niches, seasonal patterns |
| **GitHub + Tech News** | GitHub trending repos, TechCrunch, The Verge, Ars Technica | Open-source tools (= SaaS wrappers), funding announcements, industry shifts |

### Harvest Output Format

Each agent writes to `.saas-ideas/harvest/NN-slug.md`:

```markdown
# {Source Cluster} Harvest

**Date:** YYYY-MM-DD
**Sources checked:** {list of URLs/queries used}
**Sources that failed:** {list of any sources that returned empty/error, with reason}

## Signals

### {Signal title}
**Source:** {URL}
**Category:** {devtools|healthcare|fintech|education|ecommerce|productivity|...}
**Signal type:** {trending|pain-point|launch|funding|search-demand|oss-opportunity}
**Strength:** high|medium|low
**Summary:** {2-3 sentences}
**SaaS angle:** {how this could become a SaaS product}
```

### Freshness Filter

Before harvesting, the orchestrator reads `history.json`. Each agent receives a list of previously surfaced ideas/signals (from `ideas_surfaced` arrays in past runs) and is instructed: "These ideas were surfaced in previous runs. Do NOT re-surface them. Focus on what is NEW since then. Ideas are matched by normalized name (case-insensitive, trimmed)."

### Error Handling

After all harvest agents complete, check each `.saas-ideas/harvest/*.md` file exists and has at least one `### ` signal heading. Mark each as `[done]` or `[FAILED]`.

**Minimum threshold:** At least 3 of 6 harvest agents must succeed. If fewer than 3 succeed:
- Tell the user which sources failed and why
- Ask: "Only {N}/6 sources returned data. Continue with partial results, or retry?"
- If retry, re-launch only the failed agents

If 3+ succeed, continue to Phase 2 with available data. Note which sources failed in the synthesis prompt so the scoring agent can account for incomplete coverage.

---

## Phase 2: Synthesis & Scoring

A **foreground synthesis agent** reads all `.saas-ideas/harvest/*.md` files and produces `.saas-ideas/SHORTLIST.md`.

The synthesis agent receives the BUDGET and FOCUS parameters to calibrate scoring.

### Process

1. **Cluster signals into ideas** — group related signals into distinct SaaS concepts (target: 15-25 raw ideas)
2. **Deduplicate against history** — compare against `history.json` `ideas_surfaced` arrays using case-insensitive normalized name matching. Drop previously presented ideas.
3. **Score each idea** on a balanced scorecard:

| Dimension | Weight | Measures |
|-----------|--------|----------|
| Market Demand | 25% | Number of signals, signal strength, search volume, community buzz |
| Feasibility | 20% | Can a team at the BUDGET level MVP this in the expected timeframe (see Budget semantics table)? AI is a force multiplier — a solo dev with Claude Code can ship what used to need 5 people. Score should reward ideas suited to AI-accelerated development. |
| Revenue Potential | 25% | Proven willingness to pay, clear monetization model, market size indicators |
| Competition | 15% | How crowded? Are incumbents vulnerable? Is there a wedge? |
| Uniqueness | 15% | Novel combination of trends? Fresh angle? |

Each dimension scored 1-10, weighted, producing a composite score out of 10.

4. **Rank and present top 10**

### Shortlist Format

```markdown
# SaaS Idea Shortlist

**Generated:** YYYY-MM-DD
**Signals analyzed:** {N} from {N} sources ({N} sources failed)
**Focus filter:** {FOCUS or "none"}
**Budget:** {BUDGET}
**Raw ideas clustered:** {N}
**After dedup/filtering:** {N}

## Rankings

### #1 — {Idea Name} (Score: 8.4/10)
**One-liner:** {what it is in one sentence}
**Category:** {devtools|healthcare|...}
**Signals:** {which harvest sources flagged this, with signal types}
| Demand | Feasibility | Revenue | Competition | Uniqueness |
|--------|-------------|---------|-------------|------------|
| 9      | 7           | 8       | 8           | 9          |
**Why it ranks #1:** {2-3 sentences}
**Key risk:** {biggest uncertainty}

### #2 — {Idea Name} (Score: 7.9/10)
...
```

5. **Interactive selection** — print top 10 with scores and one-liners, ask: "Which idea do you want to deep-dive into? Enter a number (1-10)."

---

## Phase 3: Parallel Deep-Dive

After the user picks an idea, **four background agents** run in parallel. Each agent receives the selected idea's full entry from `SHORTLIST.md`, the BUDGET parameter, and the FOCUS context.

### Agent 1: Business Plan (`deep-dive/BUSINESS-PLAN.md`)

- **Problem statement** — what pain exists, who feels it, how they cope today
- **Solution** — what the product does, key differentiators
- **Target audience** — primary and secondary personas with demographics
- **Market size** — TAM/SAM/SOM estimates with reasoning
- **Competitive landscape** — direct competitors, indirect alternatives, positioning matrix
- **Business model** — pricing tiers (free/pro/enterprise), feature gating strategy
- **Revenue projections** — conservative/moderate/aggressive scenarios for months 1-12 (calibrated to BUDGET level)
- **Key metrics** — CAC, LTV, churn targets, conversion funnel benchmarks
- **Risk analysis** — top 5 risks with mitigation strategies
- **Moat strategy** — how to build defensibility over time (data, network effects, integrations, brand)

### Agent 2: Marketing Playbook (`deep-dive/MARKETING-PLAYBOOK.md`)

- **Brand positioning** — tagline, value prop, messaging framework
- **Landing page copy** — hero section, features, social proof templates, CTA
- **SEO strategy** — 20+ target keywords with estimated volume, content pillar plan
- **Content calendar** — 12-week plan: blog posts, social media, video topics
- **Launch strategy** — pre-launch, launch day, post-launch (Product Hunt, HN, Reddit, Twitter)
- **Email sequences** — welcome series (5 emails), trial-to-paid nurture (7 emails), churn prevention (3 emails)
- **Social media playbook** — platform-specific strategies, posting cadence, content templates
- **Partnership opportunities** — integration partners, co-marketing candidates, affiliate program design
- **Paid acquisition** — channel recommendations, estimated CAC per channel, budget allocation (scaled to BUDGET level)
- **Community building** — Discord/Slack strategy, user feedback loops, ambassador program

### Agent 3: Tech Spec (`deep-dive/TECH-SPEC.md`)

- **Recommended stack** with rationale (considering AI-assisted development speed and BUDGET level)
- **Architecture overview** — system diagram, key services, data flow
- **MVP scope** — what's in v1, what's deferred to v2/v3
- **Data model** — core entities and relationships
- **Third-party services** — auth, payments, email, analytics, monitoring (free-tier for low budget, paid OK for medium/high)
- **Infrastructure** — hosting, CI/CD, estimated monthly cost at 0/100/1000/10000 users
- **AI leverage points** — where AI tools accelerate development, where AI features add product value
- **Timeline** — week-by-week MVP build plan calibrated for the BUDGET team size with AI tooling

### Agent 4: Implementation Prompts (`deep-dive/IMPLEMENTATION-PROMPTS.md`)

Ready-to-paste prompts for Claude Code / GSD:

- **Project initialization prompt** — for `/gsd:new-project` with full context
- **Phase-by-phase prompts** — one prompt per build phase (auth, core feature, billing, landing page, etc.)
- **Marketing execution prompts** — for generating landing page copy, blog posts, email sequences
- **Testing prompts** — for generating test suites
- **Launch checklist** — actionable steps for launch day

Each prompt is self-contained and includes all context from the business plan and tech spec.

### Superpowers Integration in Prompts

Each phase prompt in `IMPLEMENTATION-PROMPTS.md` includes instructional text referencing the appropriate superpowers skill. These are references within the generated prompt text for the human to follow — they are NOT skill invocations by the saas-idea orchestrator itself.

| Build Phase | Superpowers Skill Reference |
|-------------|-------------------|
| Design decisions | `superpowers:brainstorming` |
| Before coding each phase | `superpowers:writing-plans` |
| All coding work | `superpowers:test-driven-development` |
| Independent parallel tasks | `superpowers:subagent-driven-development` |
| Bug encounters | `superpowers:systematic-debugging` |
| After each milestone | `superpowers:requesting-code-review` |
| Before merge/PR | `superpowers:verification-before-completion` |
| Feature branches | `superpowers:using-git-worktrees` |
| Branch completion | `superpowers:finishing-a-development-branch` |

---

## Phase 4: Pitch Deck & Final Report

Phase 4 is orchestrator-driven. Only Step 1 uses a subagent. Steps 2-4 are executed directly by the orchestrator.

### Step 1: Pitch Deck (foreground agent)

Launch a single foreground agent that reads all four deep-dive files and generates `deep-dive/pitch-deck.pptx`.

**Execution:** Use the same pattern as `gw:weekly-review`:
1. Try `uv run --with python-pptx python3 -c "..."` (inline script)
2. Fallback: `pip install python-pptx && python3 script.py`
3. Fallback: generate an HTML file instead and note the limitation

**Design system** (matches `gw:weekly-review` conventions):
- **Colors:** Dark blue (#1B2A4A) headers, white (#FFFFFF) body background, accent blue (#3B82F6) for highlights, light gray (#F1F5F9) for alt rows
- **Fonts:** Calibri for body, Calibri Bold for headings
- **Layout:** Title + subtitle top bar, content area with generous margins, slide numbers bottom-right

| Slide | Content |
|-------|---------|
| 1 | Title — idea name, tagline, date |
| 2 | The Problem — pain point with market stats |
| 3 | The Solution — what it does, key differentiators |
| 4 | Market Opportunity — TAM/SAM/SOM visual |
| 5 | Business Model — pricing tiers, revenue projections chart |
| 6 | Competitive Landscape — positioning matrix |
| 7 | Go-to-Market — launch strategy timeline |
| 8 | Tech Architecture — stack diagram, MVP timeline, AI-accelerated workflow note |
| 9 | Traction Plan — month-by-month growth targets |
| 10 | The Ask / Next Steps — what's needed to start |

### Step 2: Executive Report (orchestrator writes directly)

The orchestrator reads all deep-dive files and writes `.saas-ideas/REPORT.md`:

```markdown
# SaaS Idea Report: {Idea Name}

**Generated:** YYYY-MM-DD
**Score:** {X}/10
**Tagline:** {one-liner}
**Budget:** {BUDGET}
**Focus:** {FOCUS or "none"}

## Executive Summary
{3-5 sentences — what, why, how big, how fast}

## Deliverables
| File | Description |
|------|-------------|
| SHORTLIST.md | Top 10 ranked ideas with scores |
| deep-dive/BUSINESS-PLAN.md | Full business plan |
| deep-dive/MARKETING-PLAYBOOK.md | Go-to-market playbook |
| deep-dive/TECH-SPEC.md | Architecture & MVP spec |
| deep-dive/IMPLEMENTATION-PROMPTS.md | Ready-to-use Claude Code prompts |
| deep-dive/pitch-deck.pptx | Investor/co-founder pitch deck |

## Quick Start
1. Review the business plan
2. Run the project init prompt from IMPLEMENTATION-PROMPTS.md
3. Follow the phase-by-phase prompts to build the MVP
```

### Step 3: Update History (orchestrator writes directly)

Read `history.json`, append a new entry to the `runs` array, and write back:

```json
{
  "date": "YYYY-MM-DD",
  "ideas_surfaced": ["Idea Name 1", "Idea Name 2", "...all 10 from shortlist..."],
  "selected": "Selected Idea Name",
  "focus": "FOCUS or null",
  "budget": "BUDGET",
  "score": 8.4
}
```

### Step 4: GSD Integration (orchestrator)

Skip if SKIP_GSD is true.

Check if `~/.claude/commands/gsd/` exists. If it does:
- If `.planning/PROJECT.md` exists → invoke `/gsd:new-milestone` referencing `.saas-ideas/deep-dive/TECH-SPEC.md`
- If no `.planning/PROJECT.md` → invoke `/gsd:new-project` referencing `.saas-ideas/deep-dive/TECH-SPEC.md`

Project context includes: "This project was generated by /gw:saas-idea. Superpowers workflow: brainstorm → plan → TDD → review → verify for each phase."

If GSD commands don't exist, say: "Full plan available in `.saas-ideas/`. Install GSD to auto-scaffold the project." and stop.

### Step 5: Present Results (orchestrator)

1. Print the Executive Summary from REPORT.md
2. Print the file listing with sizes
3. Print: "Pitch deck saved to `.saas-ideas/deep-dive/pitch-deck.pptx`"
4. If GSD was invoked, note the project/milestone was created

---

## Architecture Summary

```
/gw:saas-idea
  │
  ├── Step 0: Update check
  ├── Step 1: Parse args, check freshness, load history
  │
  ├── Phase 1: Parallel Harvest (6 background agents)
  │   ├── HN + IndieHackers agent       → harvest/01-hackernews-indiehackers.md
  │   ├── Product Hunt agent            → harvest/02-producthunt.md
  │   ├── Reddit agent                  → harvest/03-reddit.md
  │   ├── Twitter/X agent               → harvest/04-twitter.md
  │   ├── Google Trends + SEO agent     → harvest/05-google-trends.md
  │   └── GitHub + Tech News agent      → harvest/06-github-technews.md
  │   └── [Error check: ≥3 must succeed]
  │
  ├── Phase 2: Synthesis & Scoring (1 foreground agent)
  │   ├── Cluster signals → ideas
  │   ├── Deduplicate against history.json
  │   ├── Score on 5 weighted dimensions (calibrated to BUDGET)
  │   ├── Rank top 10 → SHORTLIST.md
  │   └── Interactive selection prompt
  │
  ├── Phase 3: Parallel Deep-Dive (4 background agents)
  │   ├── Business Plan agent           → deep-dive/BUSINESS-PLAN.md
  │   ├── Marketing Playbook agent      → deep-dive/MARKETING-PLAYBOOK.md
  │   ├── Tech Spec agent               → deep-dive/TECH-SPEC.md
  │   └── Implementation Prompts agent  → deep-dive/IMPLEMENTATION-PROMPTS.md
  │
  ├── Phase 4: Final Assembly
  │   ├── Pitch Deck agent (foreground) → deep-dive/pitch-deck.pptx
  │   ├── Orchestrator writes REPORT.md
  │   ├── Orchestrator updates history.json
  │   ├── Orchestrator runs GSD integration (unless --skip-gsd)
  │   └── Orchestrator presents summary
  │
  └── Done
```

## Key Design Decisions

1. **AI as force multiplier** — Feasibility scoring accounts for AI-assisted development. A solo dev with Claude Code can ship what used to require a team of 5. Ideas suited to AI-accelerated development score higher.
2. **Freshness via history.json** — Prevents the skill from repeating ideas across runs. Supports both ad-hoc and regular usage patterns. Initialized as `{"runs": []}` on first run. Ideas matched case-insensitively.
3. **Parallel agent pattern** — Mirrors `gw:analyze-app` architecture. 6 parallel harvest agents + 4 parallel deep-dive agents minimizes wall-clock time.
4. **Explicit source access strategy** — Each source specifies whether to use `WebSearch` or `WebFetch`, avoiding failures on JS-heavy or auth-gated sites (Google Trends, Twitter).
5. **Error tolerance** — Harvest phase requires ≥3/6 agents to succeed, allowing graceful degradation when sources are unreachable.
6. **Budget-aware throughout** — The `--budget` flag propagates to feasibility scoring, tech spec infrastructure, revenue projections, and marketing spend recommendations.
7. **Superpowers integration** — Every implementation prompt references the appropriate superpowers skill as instructional text, ensuring disciplined TDD/planning/review workflows when building. These are references, not orchestrator invocations.
8. **GSD integration** — Seamless transition from idea to execution via `/gsd:new-project` or `/gsd:new-milestone`. Skippable with `--skip-gsd`.
9. **Self-contained prompts** — Implementation prompts include all context needed to execute without re-reading the business plan or tech spec.
