# SaaS Idea Generator — Design Spec

**Date:** 2026-03-17
**Skill:** `/gw:saas-idea`
**Status:** Approved

## Overview

A Claude Code skill that harvests trending news, pain points, and opportunities from 8+ internet sources, scores them on a balanced scorecard, presents a ranked shortlist of SaaS ideas, then generates a full deep-dive for the selected idea — including business plan, marketing playbook, tech spec, implementation prompts, and pitch deck. Integrates with GSD and superpowers for immediate execution.

## Skill Interface

**Command:** `/gw:saas-idea`

```
/gw:saas-idea [--focus <niche>] [--fresh] [--budget low|medium|high] [--pick <N>]
```

| Flag | Description | Default |
|------|-------------|---------|
| `--focus <niche>` | Narrow research to a domain (e.g., "healthcare", "devtools", "education") | No filter — all domains |
| `--fresh` | Force fresh harvest even if a recent run exists (<24h) | Re-use if <24h old |
| `--budget low\|medium\|high` | Team size/investment level (low=solo, medium=2-5, high=funded) | `medium` (2-5 people) |
| `--pick <N>` | Skip straight to deep-dive on idea #N from a previous run | Interactive selection |

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

Six background agents, each fetching from a cluster of sources using `WebSearch` and `WebFetch`. All launched in a single message with `run_in_background=true`.

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
**Sources checked:** {list of URLs/queries}

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

Before harvesting, the orchestrator reads `history.json`. Each agent receives a list of previously surfaced ideas/signals and is instructed to skip them and focus on what's new.

---

## Phase 2: Synthesis & Scoring

A **foreground synthesis agent** reads all `.saas-ideas/harvest/*.md` files and produces `.saas-ideas/SHORTLIST.md`.

### Process

1. **Cluster signals into ideas** — group related signals into distinct SaaS concepts (target: 15-25 raw ideas)
2. **Deduplicate against history** — compare against `history.json`, drop previously presented ideas
3. **Score each idea** on a balanced scorecard:

| Dimension | Weight | Measures |
|-----------|--------|----------|
| Market Demand | 25% | Number of signals, signal strength, search volume, community buzz |
| Feasibility | 20% | Can a small team (or solo dev with AI tooling) MVP this in 4-8 weeks? AI is a force multiplier — a solo dev with Claude Code can ship what used to need 5 people. Score should reward ideas suited to AI-accelerated development. |
| Revenue Potential | 25% | Proven willingness to pay, clear monetization model, market size indicators |
| Competition | 15% | How crowded? Are incumbents vulnerable? Is there a wedge? |
| Uniqueness | 15% | Novel combination of trends? Fresh angle? |

Each dimension scored 1-10, weighted, producing a composite score out of 10.

4. **Rank and present top 10**

### Shortlist Format

```markdown
# SaaS Idea Shortlist

**Generated:** YYYY-MM-DD
**Signals analyzed:** {N} from {N} sources
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

After the user picks an idea, **four background agents** run in parallel:

### Agent 1: Business Plan (`deep-dive/BUSINESS-PLAN.md`)

- **Problem statement** — what pain exists, who feels it, how they cope today
- **Solution** — what the product does, key differentiators
- **Target audience** — primary and secondary personas with demographics
- **Market size** — TAM/SAM/SOM estimates with reasoning
- **Competitive landscape** — direct competitors, indirect alternatives, positioning matrix
- **Business model** — pricing tiers (free/pro/enterprise), feature gating strategy
- **Revenue projections** — conservative/moderate/aggressive scenarios for months 1-12
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
- **Paid acquisition** — channel recommendations, estimated CAC per channel, budget allocation
- **Community building** — Discord/Slack strategy, user feedback loops, ambassador program

### Agent 3: Tech Spec (`deep-dive/TECH-SPEC.md`)

- **Recommended stack** with rationale (considering AI-assisted development speed)
- **Architecture overview** — system diagram, key services, data flow
- **MVP scope** — what's in v1, what's deferred to v2/v3
- **Data model** — core entities and relationships
- **Third-party services** — auth, payments, email, analytics, monitoring
- **Infrastructure** — hosting, CI/CD, estimated monthly cost at 0/100/1000/10000 users
- **AI leverage points** — where AI tools accelerate development, where AI features add product value
- **Timeline** — week-by-week MVP build plan calibrated for a small team with AI tooling

### Agent 4: Implementation Prompts (`deep-dive/IMPLEMENTATION-PROMPTS.md`)

Ready-to-paste prompts for Claude Code / GSD:

- **Project initialization prompt** — for `/gsd:new-project` with full context
- **Phase-by-phase prompts** — one prompt per build phase (auth, core feature, billing, landing page, etc.)
- **Marketing execution prompts** — for generating landing page copy, blog posts, email sequences
- **Testing prompts** — for generating test suites
- **Launch checklist** — actionable steps for launch day

Each prompt is self-contained and includes all context from the business plan and tech spec.

### Superpowers Integration in Prompts

Each phase prompt in `IMPLEMENTATION-PROMPTS.md` references the appropriate superpowers skill:

| Build Phase | Superpowers Skill |
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

### Step 1: Pitch Deck (foreground agent)

Reads all four deep-dive files and generates `deep-dive/pitch-deck.pptx` using Python `python-pptx` (same pattern as `gw:weekly-review`):

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

Clean, professional design system consistent with existing `gw:` presentation skills.

### Step 2: Executive Report (`REPORT.md`)

```markdown
# SaaS Idea Report: {Idea Name}

**Generated:** YYYY-MM-DD
**Score:** {X}/10
**Tagline:** {one-liner}

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

### Step 3: Update History

Append to `history.json`:

```json
{
  "runs": [
    {
      "date": "YYYY-MM-DD",
      "ideas_surfaced": ["idea1", "idea2", "..."],
      "selected": "idea name",
      "focus": null,
      "score": 8.4
    }
  ]
}
```

### Step 4: GSD Integration

- If GSD installed + `.planning/PROJECT.md` exists → invoke `/gsd:new-milestone` referencing `TECH-SPEC.md`
- If GSD installed + no project → invoke `/gsd:new-project` referencing `TECH-SPEC.md`
- If no GSD → print: "Full plan available in `.saas-ideas/`. Install GSD to auto-scaffold the project."

Project context includes: "This project was generated by /gw:saas-idea. Superpowers workflow: brainstorm → plan → TDD → review → verify for each phase."

---

## Architecture Summary

```
/gw:saas-idea
  │
  ├── Step 0: Update check (same pattern as all gw: skills)
  ├── Step 1: Parse args, check freshness, load history
  │
  ├── Phase 1: Parallel Harvest (6 background agents)
  │   ├── HN + IndieHackers agent
  │   ├── Product Hunt agent
  │   ├── Reddit agent
  │   ├── Twitter/X agent
  │   ├── Google Trends + SEO agent
  │   └── GitHub + Tech News agent
  │
  ├── Phase 2: Synthesis & Scoring (1 foreground agent)
  │   ├── Cluster signals → ideas
  │   ├── Deduplicate against history
  │   ├── Score on 5 dimensions
  │   ├── Rank top 10 → SHORTLIST.md
  │   └── Interactive selection prompt
  │
  ├── Phase 3: Parallel Deep-Dive (4 background agents)
  │   ├── Business Plan agent → BUSINESS-PLAN.md
  │   ├── Marketing Playbook agent → MARKETING-PLAYBOOK.md
  │   ├── Tech Spec agent → TECH-SPEC.md
  │   └── Implementation Prompts agent → IMPLEMENTATION-PROMPTS.md
  │
  ├── Phase 4: Final Assembly (sequential)
  │   ├── Pitch Deck agent → pitch-deck.pptx
  │   ├── Write REPORT.md
  │   ├── Update history.json
  │   └── GSD integration
  │
  └── Done: Present summary + next steps
```

## Key Design Decisions

1. **AI as force multiplier** — Feasibility scoring accounts for AI-assisted development. A solo dev with Claude Code can ship what used to require a team of 5. Ideas suited to AI-accelerated development score higher.
2. **Freshness via history.json** — Prevents the skill from repeating ideas across runs. Supports both ad-hoc and regular usage patterns.
3. **Parallel agent pattern** — Mirrors `gw:analyze-app` architecture. 6 parallel harvest agents + 4 parallel deep-dive agents minimizes wall-clock time.
4. **Superpowers integration** — Every implementation prompt references the appropriate superpowers skill, ensuring disciplined TDD/planning/review workflows when building.
5. **GSD integration** — Seamless transition from idea to execution via `/gsd:new-project` or `/gsd:new-milestone`.
6. **Self-contained prompts** — Implementation prompts include all context needed to execute without re-reading the business plan or tech spec.
