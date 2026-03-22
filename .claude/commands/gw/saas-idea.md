---
name: saas-idea
description: Harvest trending SaaS opportunities from the internet, score and rank them, then deep-dive into the best idea with full business plan, marketing playbook, and implementation prompts
argument-hint: "[--focus <niche>] [--fresh] [--budget low|medium|high] [--pick <N>] [--skip-planning] [--skip-gsd] [--auto] [--build] [--verify] [--team auto|ask|N] [--skip-debate] [--no-branch]"
---

## Step 0 — Preamble

Resolve the gw-skills repo path, then read and follow `$GW_REPO/.claude/commands/gw/_shared/preamble.md` for update check and GSD project detection:

```bash
GW_REPO="$(cd "$(readlink ~/.claude/commands/gw)/../../.." 2>/dev/null && pwd)" || GW_REPO="$HOME/.gw-skills"
```

GW_REPO persists for the duration of this skill run — do not re-resolve it in later steps.

---

## Step 0.5 — Branch Isolation

Set `SKILL_NAME="saas-idea"`.

Read and follow `$GW_REPO/.claude/commands/gw/_shared/branch-first.md` for branch creation.

---

You are an orchestrator for SaaS idea discovery and validation. You harvest trending signals from the internet, score and rank SaaS opportunities, and generate comprehensive deep-dive deliverables for the best ideas. Follow these steps precisely.

Parse the arguments: "$ARGUMENTS"
- If "--focus <niche>" is present, set FOCUS=niche (string). Default: empty (no filter)
- If "--fresh" is present, set FORCE_FRESH=true. Default: false
- If "--budget <level>" is present, set BUDGET=level (one of: low, medium, high). Default: medium
- If "--pick <N>" is present, set PICK_ID=N (integer). Default: empty (interactive)
- If "--skip-planning" or "--skip-gsd" is present, set SKIP_PLANNING=true. Default: false
- If "--auto" is present, set AUTO_SELECT=true. Default: false
- If "--build" is present, set BUILD_MODE=true AND AUTO_SELECT=true (build implies auto). Default: false
- If "--verify" is present, set VERIFY_MODE=true. Default: false
- If "--team X" is present: if X is a number, set TEAM_MODE=auto and TEAM_SIZE_OVERRIDE=X (clamped to 3-10). If X is "auto" or "ask", set TEAM_MODE=X. Default: auto
- If "--skip-debate" is present, set SKIP_DEBATE=true. Default: false
- If "--no-branch" is present, set NO_BRANCH=true. Default: false. Skips branch isolation (see Step 0.5).

### Flag validation

- If `--build` AND (`--skip-planning` or `--skip-gsd`) are both present: warn "⚠ --build requires a planning tool but --skip-planning was set. Disabling build mode." Set BUILD_MODE=false, keep SKIP_PLANNING=true.
- If `--build` is present: also set VERIFY_MODE=true (build always verifies before building).
- If `--pick` is present: also set AUTO_SELECT=true (pick implies auto — skip interactive selection).

### Budget semantics

The BUDGET flag modifies behavior in Phases 2-4:

| Budget | Team context | Feasibility bias | Tech spec scope | Revenue projections |
|--------|-------------|-------------------|-----------------|---------------------|
| `low` | Solo dev with AI tooling | Strongly favor ideas one person can ship in 2-4 weeks | Minimal infra, free-tier services only | Conservative, bootstrapped |
| `medium` | 2-5 person team with AI tooling | Favor ideas shippable in 4-8 weeks | Moderate infra, paid services OK | Moderate, some paid acquisition budget |
| `high` | Funded team (5-15) | Larger scope OK, 8-16 week MVPs acceptable | Full infra, enterprise services | Aggressive, investor-backed growth |

### Cost-optimization principle (all tiers)

Budget tiers govern team size and timeline, but the *starting point* for every tier is near-zero cost. Apply these 5 rules regardless of budget level:

1. **Free tier first** — default to free-tier services. Only upgrade when a free tier's hard limit is actually hit (not speculatively).
2. **Serverless before provisioned** — prefer pay-per-use (Lambda, API Gateway, Neon serverless) over always-on compute (ECS, Fargate, RDS provisioned). Idle compute = wasted money.
3. **Validate before spending** — no paid services, ad spend, or infra upgrades until at least 1 paying customer or 100+ validated signups.
4. **Cost monitoring from day 1** — every deployment includes AWS Cost Explorer alerts, Stripe dashboard review, monthly burn-rate check.
5. **Open-source over SaaS when equivalent** — if a self-hosted OSS tool replaces a paid SaaS with <2 hours setup, prefer it.

---

## Step 1 — Pre-flight

### Pre-flight routing

Automatic decision tree — at most one prompt before work begins:

1. If `--pick N` was set: skip directly to Phase 3 deep-dive with idea #N from the existing SHORTLIST.md. If SHORTLIST.md doesn't exist, print "No shortlist found. Run a full harvest first." and stop.
2. If `--fresh` was set: proceed to Phase 1 (harvest), ignoring any cached data.
3. If `--auto` was set: use cached data if < 24h old (skip to Phase 2), otherwise harvest fresh. No prompts.
4. If `.saas-ideas/SHORTLIST.md` exists and is < 24h old: ask ONE question: "Recent shortlist found (<age>). Re-use existing data [r] or harvest fresh [f]?"
   - `[r]`: skip to Phase 2 (scoring) with existing data
   - `[f]`: proceed to Phase 1 (harvest)
5. Otherwise: proceed to Phase 1 (harvest) with no prompt.

### Initialize history

If `history.json` does not exist in `.saas-ideas/`, create it with `{"runs": []}` and treat all ideas as new.

### Create working directories

```bash
mkdir -p .saas-ideas/harvest .saas-ideas/deep-dive
```

---

## Phase 1 — Parallel Harvest

Launch 6 background agents to harvest trending signals from different internet sources. Each agent writes its findings to a dedicated file in `.saas-ideas/harvest/`.

### Source access strategy

| Source | Tool | Method |
|--------|------|--------|
| Hacker News | `WebFetch` | Fetch `https://news.ycombinator.com`, `https://news.ycombinator.com/show`, `https://news.ycombinator.com/ask` directly — plain HTML |
| IndieHackers | `WebSearch` | Search `site:indiehackers.com` + relevant keywords — may require auth |
| Product Hunt | `WebSearch` | Search `site:producthunt.com` + "launched today/this week" — JS-heavy |
| Reddit | `WebFetch` | Fetch `https://old.reddit.com/r/{subreddit}/top/?t=week` — old.reddit renders HTML. Fallback: `WebSearch` with `site:reddit.com` |
| Twitter/X | `WebSearch` | Search queries like "trending SaaS twitter 2026". Do NOT `WebFetch` twitter.com — requires auth. |
| Google Trends | `WebSearch` | Search `"google trends" rising searches {category}`. Do NOT `WebFetch` trends.google.com — JS-rendered. |
| GitHub Trending | `WebFetch` | Fetch `https://github.com/trending` and `https://github.com/trending?since=weekly` — plain HTML |
| TechCrunch/Verge/Ars | `WebSearch` + `WebFetch` | `WebSearch` for recent articles, then `WebFetch` top results |

### Focus filter propagation

When FOCUS is set, inject this block into every agent prompt as `{FOCUS_BLOCK}`:

> Focus your research on the **{FOCUS}** domain. Only surface signals directly relevant to {FOCUS}. Ignore signals from unrelated domains.

When FOCUS is empty, set `{FOCUS_BLOCK}` to an empty string (omit entirely).

### Building PREVIOUS_IDEAS

Read `history.json` and collect all idea titles from previous runs. Format them as a bullet list and inject as `{PREVIOUS_IDEAS}`. If `history.json` has no previous runs, set `{PREVIOUS_IDEAS}` to "None — this is the first run."

---

### Agent 1: HN + IndieHackers

Launch a background Agent (`subagent_type="general-purpose"`) with this prompt:

```
You are a trend researcher analyzing Hacker News and IndieHackers for SaaS opportunities.

{FOCUS_BLOCK}

**Source access:**
- WebFetch `https://news.ycombinator.com` (front page)
- WebFetch `https://news.ycombinator.com/show` (Show HN)
- WebFetch `https://news.ycombinator.com/ask` (Ask HN)
- WebSearch `site:indiehackers.com SaaS ideas 2026`
- WebSearch `site:indiehackers.com "revenue" OR "MRR" OR "launched"`

For any promising HN threads, WebFetch the comments page (e.g. `https://news.ycombinator.com/item?id=XXXXX`) to extract pain points from discussion.

**Previously surfaced ideas (skip these):** {PREVIOUS_IDEAS}

Research current trends, pain points, and opportunities. For each signal you find, extract structured data.

Write your findings to `.saas-ideas/harvest/01-hackernews-indiehackers.md` in this format:

```markdown
# HN + IndieHackers Harvest

**Date:** {today's date}
**Sources checked:** {list of URLs/queries used}
**Sources that failed:** {list of any that returned empty/error, with reason}

## Signals

### {Signal title}
**Source:** {URL}
**Category:** {devtools|healthcare|fintech|education|ecommerce|productivity|...}
**Signal type:** {trending|pain-point|launch|funding|search-demand|oss-opportunity}
**Strength:** high|medium|low
**Summary:** {2-3 sentences}
**SaaS angle:** {how this could become a SaaS product}
```

Aim for 5-15 signals. Quality over quantity.
```

---

### Agent 2: Product Hunt

Launch a background Agent (`subagent_type="general-purpose"`) with this prompt:

```
You are a trend researcher analyzing Product Hunt for SaaS opportunities.

{FOCUS_BLOCK}

**Source access:**
- WebSearch `site:producthunt.com "launched" SaaS 2026`
- WebSearch `site:producthunt.com "product of the day" OR "product of the week"`
- WebSearch `site:producthunt.com trending SaaS tools`
- WebSearch `producthunt.com top products this week`

For any highly upvoted launches, try WebFetch on the Product Hunt URL to get details. If it fails (JS-heavy), rely on the WebSearch snippets.

**Previously surfaced ideas (skip these):** {PREVIOUS_IDEAS}

Research current trends, pain points, and opportunities. For each signal you find, extract structured data.

Write your findings to `.saas-ideas/harvest/02-producthunt.md` in this format:

```markdown
# Product Hunt Harvest

**Date:** {today's date}
**Sources checked:** {list of URLs/queries used}
**Sources that failed:** {list of any that returned empty/error, with reason}

## Signals

### {Signal title}
**Source:** {URL}
**Category:** {devtools|healthcare|fintech|education|ecommerce|productivity|...}
**Signal type:** {trending|pain-point|launch|funding|search-demand|oss-opportunity}
**Strength:** high|medium|low
**Summary:** {2-3 sentences}
**SaaS angle:** {how this could become a SaaS product}
```

Aim for 5-15 signals. Quality over quantity.
```

---

### Agent 3: Reddit

Launch a background Agent (`subagent_type="general-purpose"`) with this prompt:

```
You are a trend researcher analyzing Reddit for SaaS opportunities.

{FOCUS_BLOCK}

**Source access:**
- WebFetch `https://old.reddit.com/r/SaaS/top/?t=week`
- WebFetch `https://old.reddit.com/r/startups/top/?t=week`
- WebFetch `https://old.reddit.com/r/Entrepreneur/top/?t=week`
- WebFetch `https://old.reddit.com/r/microsaas/top/?t=week`
- WebFetch `https://old.reddit.com/r/IndieBiz/top/?t=week`

If any WebFetch call fails, fall back to `WebSearch` with `site:reddit.com r/{subreddit} SaaS`.

For highly upvoted threads, WebFetch the full thread URL (old.reddit.com version) to extract pain points and ideas from comments.

**Previously surfaced ideas (skip these):** {PREVIOUS_IDEAS}

Research current trends, pain points, and opportunities. For each signal you find, extract structured data.

Write your findings to `.saas-ideas/harvest/03-reddit.md` in this format:

```markdown
# Reddit Harvest

**Date:** {today's date}
**Sources checked:** {list of URLs/queries used}
**Sources that failed:** {list of any that returned empty/error, with reason}

## Signals

### {Signal title}
**Source:** {URL}
**Category:** {devtools|healthcare|fintech|education|ecommerce|productivity|...}
**Signal type:** {trending|pain-point|launch|funding|search-demand|oss-opportunity}
**Strength:** high|medium|low
**Summary:** {2-3 sentences}
**SaaS angle:** {how this could become a SaaS product}
```

Aim for 5-15 signals. Quality over quantity.
```

---

### Agent 4: Twitter/X + Social

Launch a background Agent (`subagent_type="general-purpose"`) with this prompt:

```
You are a trend researcher analyzing Twitter/X and social media for SaaS opportunities.

{FOCUS_BLOCK}

**Source access:**
- WebSearch `trending SaaS twitter 2026`
- WebSearch `"SaaS idea" OR "micro SaaS" site:twitter.com OR site:x.com`
- WebSearch `SaaS trends 2026 social media`
- WebSearch `"building in public" SaaS launch 2026`
- WebSearch `"just launched" SaaS OR "side project" 2026`

Do NOT attempt to WebFetch twitter.com or x.com — these require authentication and will fail.

**Previously surfaced ideas (skip these):** {PREVIOUS_IDEAS}

Research current trends, pain points, and opportunities. For each signal you find, extract structured data.

Write your findings to `.saas-ideas/harvest/04-twitter.md` in this format:

```markdown
# Twitter/X + Social Harvest

**Date:** {today's date}
**Sources checked:** {list of URLs/queries used}
**Sources that failed:** {list of any that returned empty/error, with reason}

## Signals

### {Signal title}
**Source:** {URL}
**Category:** {devtools|healthcare|fintech|education|ecommerce|productivity|...}
**Signal type:** {trending|pain-point|launch|funding|search-demand|oss-opportunity}
**Strength:** high|medium|low
**Summary:** {2-3 sentences}
**SaaS angle:** {how this could become a SaaS product}
```

Aim for 5-15 signals. Quality over quantity.
```

---

### Agent 5: Google Trends + SEO

Launch a background Agent (`subagent_type="general-purpose"`) with this prompt:

```
You are a trend researcher analyzing Google Trends and SEO signals for SaaS opportunities.

{FOCUS_BLOCK}

**Source access:**
- WebSearch `"google trends" rising searches SaaS 2026`
- WebSearch `"google trends" breakout topics software tools`
- WebSearch `fastest growing SaaS categories 2026`
- WebSearch `"search volume" increasing SaaS tools 2026`
- WebSearch `emerging software niches 2026 underserved`

Do NOT attempt to WebFetch trends.google.com — it is JS-rendered and will return empty content.

**Previously surfaced ideas (skip these):** {PREVIOUS_IDEAS}

Research current trends, pain points, and opportunities. For each signal you find, extract structured data.

Write your findings to `.saas-ideas/harvest/05-google-trends.md` in this format:

```markdown
# Google Trends + SEO Harvest

**Date:** {today's date}
**Sources checked:** {list of URLs/queries used}
**Sources that failed:** {list of any that returned empty/error, with reason}

## Signals

### {Signal title}
**Source:** {URL}
**Category:** {devtools|healthcare|fintech|education|ecommerce|productivity|...}
**Signal type:** {trending|pain-point|launch|funding|search-demand|oss-opportunity}
**Strength:** high|medium|low
**Summary:** {2-3 sentences}
**SaaS angle:** {how this could become a SaaS product}
```

Aim for 5-15 signals. Quality over quantity.
```

---

### Agent 6: GitHub + Tech News

Launch a background Agent (`subagent_type="general-purpose"`) with this prompt:

```
You are a trend researcher analyzing GitHub Trending and tech news sites for SaaS opportunities.

{FOCUS_BLOCK}

**Source access:**
- WebFetch `https://github.com/trending` (today's trending repos)
- WebFetch `https://github.com/trending?since=weekly` (this week's trending repos)
- WebSearch `site:techcrunch.com SaaS startup launch 2026`
- WebSearch `site:theverge.com software tools 2026`
- WebSearch `site:arstechnica.com SaaS OR "developer tools" 2026`

For any promising WebSearch results from tech news sites, WebFetch the article URL to get full details.

Look for OSS projects gaining traction that could inspire SaaS wrappers, hosted versions, or complementary tools.

**Previously surfaced ideas (skip these):** {PREVIOUS_IDEAS}

Research current trends, pain points, and opportunities. For each signal you find, extract structured data.

Write your findings to `.saas-ideas/harvest/06-github-technews.md` in this format:

```markdown
# GitHub + Tech News Harvest

**Date:** {today's date}
**Sources checked:** {list of URLs/queries used}
**Sources that failed:** {list of any that returned empty/error, with reason}

## Signals

### {Signal title}
**Source:** {URL}
**Category:** {devtools|healthcare|fintech|education|ecommerce|productivity|...}
**Signal type:** {trending|pain-point|launch|funding|search-demand|oss-opportunity}
**Strength:** high|medium|low
**Summary:** {2-3 sentences}
**SaaS angle:** {how this could become a SaaS product}
```

Aim for 5-15 signals. Quality over quantity.
```

---

### Launch all harvest agents

Apply `superpowers:dispatching-parallel-agents` pattern — Launch ALL 6 agents in a SINGLE message using the Agent tool. Each call must set `run_in_background=true`. Do not wait for one agent to finish before launching the next — they all run in parallel.

After launching, you will be notified as each background agent completes. Wait for ALL 6 to finish before proceeding.

---

### Harvest validation

After all agents complete, validate the harvest results:

1. Check each expected file exists and has at least one `### ` signal heading:
   - `.saas-ideas/harvest/01-hackernews-indiehackers.md`
   - `.saas-ideas/harvest/02-producthunt.md`
   - `.saas-ideas/harvest/03-reddit.md`
   - `.saas-ideas/harvest/04-twitter.md`
   - `.saas-ideas/harvest/05-google-trends.md`
   - `.saas-ideas/harvest/06-github-technews.md`

2. Print a status table:
   ```
   Harvest Status:
   [done]   01-hackernews-indiehackers.md   ({N} signals)
   [done]   02-producthunt.md               ({N} signals)
   [FAILED] 03-reddit.md                    (file missing)
   [done]   04-twitter.md                   ({N} signals)
   ...
   ```
   Count signals by grepping for `### ` headings under the `## Signals` section in each file.

3. Apply minimum threshold: at least 3 out of 6 agents must succeed.
   - If fewer than 3 succeeded: tell the user which agents failed and why (file missing vs. zero signals). Offer to retry only the failed agents (max 2 retries per failed agent). After 2 failures for the same agent, continue with available reports. Do not proceed until threshold is met or all retries are exhausted.
   - If 3 or more succeeded: continue to Phase 2. Note any failures in the Phase 2 synthesis prompt so the synthesizer knows which sources are missing.

---

## Phase 2 — Synthesis & Scoring

Launch a single foreground Agent (subagent_type="general-purpose") to synthesize harvest data into a ranked shortlist of SaaS ideas.

Pass the following context into the agent prompt:
- **BUDGET** — the budget tier parsed in Step 0 (`low`, `medium`, or `high`)
- **FOCUS** — the focus filter parsed in Step 0 (or `"none"` if not provided)
- **FAILED_SOURCES** — the list of harvest source filenames that failed validation in Phase 1

### Synthesis agent prompt

```
You are a SaaS opportunity analyst. Your job is to synthesize raw market signals into a ranked shortlist of SaaS product ideas.

**Budget tier:** {BUDGET}
**Focus filter:** {FOCUS}
**Failed harvest sources:** {FAILED_SOURCES}

Follow these steps in order:

### 1. Read harvest data

Read all available `.saas-ideas/harvest/*.md` files. Parse out every signal (each `### ` heading under the `## Signals` section in each file). Track which source file each signal came from.

### 2. Read history for deduplication

Read `.saas-ideas/history.json`. If the file does not exist, treat it as empty (no prior history). Extract all entries from the `ideas_surfaced` arrays across all runs.

### 3. Cluster signals into ideas

Group related signals across sources into distinct SaaS concepts. Look for:
- Multiple sources mentioning the same pain point
- Complementary signals (e.g., a trending GitHub repo + a Reddit complaint + a ProductHunt launch in the same space)
- Emerging patterns that suggest unmet demand

Target 15-25 raw ideas. Each idea should have:
- A clear, concise name
- A one-sentence description
- A category (e.g., devtools, healthcare, fintech, ecommerce, education, productivity, creator-economy, etc.)
- The list of source signals that support it

If FOCUS is not "none", bias clustering toward the focus area — but still include strong ideas outside the focus if the signals are compelling.

### 4. Deduplicate against history

Compare each idea name against names in `history.json` `ideas_surfaced` arrays using case-insensitive normalized matching (strip whitespace, lowercase, ignore punctuation differences). Drop any idea that has been previously surfaced.

### 5. Score each idea

Score every remaining idea on this balanced scorecard:

| Dimension | Weight | What to measure |
|-----------|--------|-----------------|
| Market Demand | 25% | Number of signals, signal strength, search volume indicators, community buzz |
| Feasibility | 20% | Can a team at the {BUDGET} level MVP this in the expected timeframe? AI is a force multiplier — a solo dev with Claude Code can ship what used to need 5 people. Reward ideas suited to AI-accelerated development. Budget semantics: low = 2-4 weeks solo dev, medium = 4-8 weeks small team, high = 8-16 weeks funded team. **Strongly favor ideas that can validate with near-zero infrastructure cost** (free-tier databases, serverless compute, no paid APIs for MVP). Ideas requiring expensive infra just to prototype score lower. |
| Revenue Potential | 25% | Proven willingness to pay, clear monetization model, market size indicators |
| Competition | 15% | How crowded is the space? Are incumbents vulnerable? Is there a differentiation wedge? |
| Uniqueness | 15% | Novel combination of trends? Fresh angle? Contrarian insight? |

Score each dimension 1-10. Compute the composite score as:
`composite = (demand * 0.25) + (feasibility * 0.20) + (revenue * 0.25) + (competition * 0.15) + (uniqueness * 0.15)`

### 6. Rank and write shortlist

Sort ideas by composite score descending. Write the top 10 to `.saas-ideas/SHORTLIST.md` in this exact format:

```markdown
# SaaS Idea Shortlist

**Generated:** YYYY-MM-DD
**Signals analyzed:** {N} from {N} sources ({N} sources failed)
**Focus filter:** {FOCUS or "none"}
**Budget:** {BUDGET}
**Raw ideas clustered:** {N}
**After dedup/filtering:** {N}

## Rankings

### #1 — {Idea Name} (Score: X.X/10)
**One-liner:** {what it is in one sentence}
**Category:** {devtools|healthcare|...}
**Signals:** {which harvest sources flagged this, with signal types}
| Demand | Feasibility | Revenue | Competition | Uniqueness |
|--------|-------------|---------|-------------|------------|
| 9      | 7           | 8       | 8           | 9          |
**Why it ranks #1:** {2-3 sentences}
**Key risk:** {biggest uncertainty}

### #2 — {Idea Name} (Score: X.X/10)
**One-liner:** {what it is in one sentence}
**Category:** {devtools|healthcare|...}
**Signals:** {which harvest sources flagged this, with signal types}
| Demand | Feasibility | Revenue | Competition | Uniqueness |
|--------|-------------|---------|-------------|------------|
| 8      | 8           | 7       | 7           | 8          |
**Why it ranks #2:** {2-3 sentences}
**Key risk:** {biggest uncertainty}

...and so on through #10
```

Replace YYYY-MM-DD with today's actual date. Fill all {N} placeholders with real counts.
```

---

## Phase 2.5 — Idea Debate

Skip this phase if `SKIP_DEBATE=true` OR `AUTO_SELECT=true` (--auto and --build imply speed — skip debate).

### 2.5a. Team Assembly

**Team suggestion table for this skill:**

| CONTEXT | Suggested Team |
|---------|---------------|
| saas-idea | Business Analyst, Financial Analyst, Product Manager, Devil's Advocate, Software Architect |

Context line for approval gate: `SaaS Idea: {IDEA_NAME}`

Read and follow `$GW_REPO/.claude/commands/gw/_shared/team-assembly.md` using the table above for team suggestions.

### 2.5c. Round 1 — Position Statements

```bash
mkdir -p .saas-ideas/debate/round1 .saas-ideas/debate/round2
```

Launch all team agents in parallel (`run_in_background=true`). Each agent reads `.saas-ideas/SHORTLIST.md` (top 5 ideas) and writes their position to `.saas-ideas/debate/round1/{PERSONA_SLUG}.md`.

Agent prompt template:

```
You are {PERSONA_NAME}, a specialist with the following profile:
- Background: {PERSONA_BACKGROUND}
- Perspective: {PERSONA_PERSPECTIVE}
- Priorities: {PERSONA_PRIORITIES}
- Debate style: {PERSONA_DEBATE_STYLE}

## Context

You are evaluating SaaS ideas from a shortlist.

## Your Task

1. Read the SaaS idea shortlist at `.saas-ideas/SHORTLIST.md` (focus on the top 5 ideas).
2. From your specialist perspective, which idea would you pursue and why?
3. Flag red flags on any ideas — risks others might miss.
4. Provide a feasibility and risk assessment for your top pick.

## Output

Write your position to: `.saas-ideas/debate/round1/{PERSONA_SLUG}.md`

Use this format:

---
persona: {PERSONA_NAME}
round: 1
date: {TODAY_DATE}
---

# Round 1 — Position Statement: {PERSONA_NAME}

## My Pick: #{N} — {Idea Name}

**Why (from my perspective):** {explanation}

## Red Flags

- **#{N} {Idea Name}:** {concern from this persona's perspective}

## Feasibility & Risk Assessment

- **Technical feasibility:** {assessment}
- **Market risk:** {assessment}
- **Revenue timeline:** {assessment}
```

### 2.5d. Round 2 — Cross-Examination

The supervisor (orchestrator) reads all Round 1 positions. Identifies the top 3 disagreements — ideas where agents strongly disagree. The devil's advocate challenges the strongest consensus.

Launch all team agents again in parallel (`run_in_background=true`) with:
- Their persona details
- All colleagues' Round 1 positions (concatenated)
- The identified disagreements
- A devil's advocate challenge targeting THIS persona's stance

Each writes to `.saas-ideas/debate/round2/{PERSONA_SLUG}.md`:

```
---
persona: {PERSONA_NAME}
round: 2
date: {TODAY_DATE}
---

# Round 2 — Cross-Examination: {PERSONA_NAME}

## Response to Disagreements

{Respond to each identified disagreement — hold, concede, or refine}

## Response to Devil's Advocate Challenge

{Rebuttal or concession}

## Mind Changes

- {What changed, if anything}

## Updated Pick (if changed)

{State updated pick or "Unchanged"}
```

### 2.5e. Round 3 — Supervisor Synthesis

A single foreground agent reads ALL Round 1 + Round 2 files and writes `.saas-ideas/CONSENSUS.md`:

```markdown
# Idea Debate Consensus

**Date:** {date}
**Team:** {N} specialists, 2 debate rounds
**Shortlist evaluated:** Top 5 ideas from SHORTLIST.md

## Consensus Recommendation

**Idea:** #{N} — {Idea Name}
**Consensus strength:** {N}/{N} specialists agree
**Why:** {synthesis of arguments}

## Risk-Adjusted Ranking

| Rank | Idea | Original Score | Debate Adjustment | Key Insight |
|------|------|---------------|-------------------|-------------|
| 1 | {name} | X.X | +/- Y | {what the debate revealed} |
| 2 | {name} | X.X | +/- Y | {insight} |
| ... | ... | ... | ... | ... |

## What Would Change the Recommendation

- {condition that would shift the consensus}

## Dissenting Views

- {persona}: {their disagreement and why it matters}
```

### 2.5f. Present results

Show the debate consensus alongside the shortlist. If the debate consensus #1 differs from the scoring #1, highlight the discrepancy. The debate consensus #1 becomes the default selection (overriding the scoring #1 for the recommendation).

### Idea selection

After the synthesis agent completes:

1. Read `.saas-ideas/SHORTLIST.md`

**If AUTO_SELECT is true (or PICK_ID is set):**

2. Determine selection: use PICK_ID if set, otherwise default to #1.
3. Print: `"Auto-selected #{N}: {Idea Name} (Score: X.X/10) — {one-liner}"`
4. Store the full entry for that idea as `SELECTED_IDEA` (see fields below).
5. Proceed directly to Phase 3. No user interaction.

**If AUTO_SELECT is false:**

2. Apply `superpowers:brainstorming` "explore approaches" pattern — present the top 3 ideas with trade-offs:

   ```
   SaaS Idea Shortlist — Top 10
   ─────────────────────────────
    1. {Idea Name}  (Score: X.X/10) — {one-liner}
    2. {Idea Name}  (Score: X.X/10) — {one-liner}
    3. ...
   ```

   Then for the top 3, present a comparison:

   ```
   Top 3 — Trade-off Analysis
   ───────────────────────────
   #1 {Name} — Key strength: {strength}. Key risk: {risk}. Best for: {user type}.
   #2 {Name} — Key strength: {strength}. Key risk: {risk}. Best for: {user type}.
   #3 {Name} — Key strength: {strength}. Key risk: {risk}. Best for: {user type}.

   Recommendation: #{N} — {reasoning}
   ```

3. Ask the user: **"Which idea do you want to deep-dive into? Enter a number (1-10), or press Enter for the recommendation."**
4. If the user presses Enter (empty response), use the recommended idea.

**In both cases**, store the full entry for the selected idea as `SELECTED_IDEA` with all fields:
   - `name` — the idea name
   - `one_liner` — the one-sentence description
   - `category` — the category tag
   - `signals` — the source signals summary
   - `scores` — all five dimension scores and the composite
   - `ranking_rationale` — the "Why it ranks" text
   - `key_risk` — the biggest uncertainty

   This `SELECTED_IDEA` context will be passed to Phase 3 for deep-dive analysis.

---

## Phase 3 — Parallel Deep-Dive

After the user selects an idea, launch 4 background agents in parallel to create detailed deliverables. Each agent receives the following context:

- **SELECTED_IDEA** — the full idea entry from SHORTLIST.md (name, one_liner, category, signals, scores, ranking_rationale, key_risk)
- **BUDGET** — the budget tier (`low`, `medium`, or `high`)
- **FOCUS** — the focus filter (or `"none"` if not set)

All output files go into `.saas-ideas/deep-dive/`.

---

### Agent 1: Business Plan

Launch a background Agent (`subagent_type="general-purpose"`) with this prompt:

```
You are a SaaS business strategist. Your job is to write a comprehensive business plan for a SaaS product idea.

**Selected idea:**
{SELECTED_IDEA}

**Budget tier:** {BUDGET}
**Focus domain:** {FOCUS}

Use WebSearch to research competitors, market size, and industry benchmarks relevant to this idea. Ground your analysis in real data wherever possible.

Write a business plan covering ALL 10 sections below. Be specific and actionable — no generic platitudes.

## 1. Problem Statement
- What pain exists? Be specific about the workflow or situation.
- Who feels it? (roles, company sizes, industries)
- How do they cope today? (current workarounds, manual processes, existing tools that fall short)

## 2. Solution
- What the product does — describe the core value proposition in concrete terms.
- Key differentiators — what makes this different from existing solutions?
- The "aha moment" — what does a user experience in their first session that hooks them?

## 3. Target Audience
- Primary persona: name, role, demographics, goals, frustrations, willingness to pay
- Secondary persona: same structure
- Anti-personas: who is this NOT for?

## 4. Market Size
- TAM (Total Addressable Market) — with reasoning and sources
- SAM (Serviceable Addressable Market) — geographic/segment focus
- SOM (Serviceable Obtainable Market) — realistic year-1 capture
- Use WebSearch to find real market size data, industry reports, and comparable company revenues.

## 5. Competitive Landscape
- Direct competitors: 3-5 products with pricing, strengths, weaknesses
- Indirect alternatives: spreadsheets, manual processes, adjacent tools
- Positioning matrix: 2x2 grid (e.g., simplicity vs. power, price vs. features)
- Use WebSearch to research each competitor.

## 6. Business Model
- Pricing tiers: Free, Pro, Enterprise — with specific price points
- Feature gating strategy: what's free vs. paid?
- Annual vs. monthly pricing and discount strategy
- Upsell and expansion revenue paths

## 7. Revenue Projections
Calibrate to BUDGET tier:
- low: bootstrapped solo dev, organic growth only
- medium: small team, modest paid acquisition budget
- high: funded team, aggressive growth spend

Provide conservative / moderate / aggressive projections for months 1-12:
| Month | Conservative MRR | Moderate MRR | Aggressive MRR |
|-------|-----------------|--------------|-----------------|
| 1     | ...             | ...          | ...             |
| ...   | ...             | ...          | ...             |
| 12    | ...             | ...          | ...             |

Show assumptions (conversion rates, traffic, churn) for each scenario.

### Cost to first dollar

Before projecting revenue growth, establish what it costs to earn the first $1:

| Cost Category | Target | Notes |
|---|---|---|
| Infrastructure | $0/mo | Free tiers only (Neon, Lambda, Cloudflare) |
| Marketing | $0 | Organic only (content, community, Show HN) |
| Third-party services | $0/mo | Free tiers only (Resend, PostHog, Sentry) |
| **Total to first $1 revenue** | **$0** | Validate pricing before spending anything |

Do not project aggressive growth until the first 10 paying customers validate pricing.

## 8. Key Metrics
- Customer Acquisition Cost (CAC) target by channel
- Lifetime Value (LTV) target and calculation
- LTV:CAC ratio target
- Monthly churn rate target
- Trial-to-paid conversion target
- Activation rate target (what counts as "activated")
- Conversion funnel benchmarks: visitor → signup → activated → paid

## 9. Risk Analysis
Top 5 risks, each with:
- Description of the risk
- Likelihood (high/medium/low)
- Impact (high/medium/low)
- Mitigation strategy
- Early warning indicators

## 10. Moat Strategy
How to build defensibility over time:
- Data moat: does usage generate proprietary data?
- Network effects: does the product get better with more users?
- Integration moat: can you become embedded in workflows?
- Brand moat: can you own a category or community?
- Switching cost moat: what makes leaving painful?

Identify which moat types are most viable for this specific idea and outline concrete steps to build them in the first 12 months.

Write the complete business plan to `.saas-ideas/deep-dive/BUSINESS-PLAN.md`.
```

---

### Agent 2: Marketing Playbook

Launch a background Agent (`subagent_type="general-purpose"`) with this prompt:

```
You are a SaaS marketing strategist. Your job is to write a comprehensive marketing playbook for a SaaS product idea.

**Selected idea:**
{SELECTED_IDEA}

**Budget tier:** {BUDGET}
**Focus domain:** {FOCUS}

Use WebSearch to research SEO keywords, competitor marketing strategies, and community platforms relevant to this idea. Ground your recommendations in real data.

Write a marketing playbook covering ALL 10 sections below. Be specific — include actual copy, actual keywords, actual schedules.

## 1. Brand Positioning
- Tagline: one punchy line (provide 3 options)
- Value proposition: the "for [audience], who [need], [product] is a [category] that [benefit], unlike [alternative], we [differentiator]" framework
- Messaging framework: key messages for each persona, tone of voice guide
- Brand personality: 3-5 adjectives that define the brand voice

## 2. Landing Page Copy
- Hero section: headline, subheadline, CTA button text
- Social proof section: testimonial templates, trust signals
- Features section: 3-4 key features with benefit-oriented descriptions
- FAQ section: 5-7 common objections addressed
- Final CTA section: urgency-driven close
- Provide the full copy, ready to use.

## 3. SEO Strategy
- 20+ target keywords with estimated monthly search volume (use WebSearch to validate)
- Categorize as: head terms, long-tail, question-based, comparison
- Content pillar plan: 3-4 pillars with 5+ cluster topics each
- Technical SEO checklist for launch
- Link building strategy: 10 concrete outreach targets

## 4. Content Calendar
12-week plan organized by week:
| Week | Blog Post | Social Media | Video/Other |
|------|-----------|-------------|-------------|
| 1    | ...       | ...         | ...         |
| ...  | ...       | ...         | ...         |
| 12   | ...       | ...         | ...         |

Include specific titles, not just categories. Mix educational, promotional, and community content.

## 5. Launch Strategy

### Pre-launch (2 weeks before)
- Build waitlist landing page
- Start teaser content on social media
- Seed beta users for testimonials
- Prepare launch assets

### Launch day
- Product Hunt launch: title, tagline, description, first comment, hunter strategy
- Hacker News: Show HN post strategy, title options, optimal posting time
- Reddit: which subreddits, post formats, engagement strategy
- Twitter/X: launch thread template (10 tweets)

### Post-launch (2 weeks after)
- Follow-up content
- User feedback collection
- PR outreach
- Momentum maintenance

## 6. Email Sequences
Write actual subject lines and brief outlines for each email:

### Welcome sequence (5 emails)
| # | Timing | Subject | Goal |
|---|--------|---------|------|
| 1 | Immediate | ... | ... |
| 2 | Day 1 | ... | ... |
| 3 | Day 3 | ... | ... |
| 4 | Day 5 | ... | ... |
| 5 | Day 7 | ... | ... |

### Trial-to-paid sequence (7 emails)
Same format — focus on value demonstration, social proof, urgency.

### Churn prevention sequence (3 emails)
Same format — re-engage at risk users.

## 7. Social Media Playbook
For each platform (Twitter/X, LinkedIn, Reddit, YouTube):
- Content types that work
- Posting cadence
- Content templates (provide 3 per platform)
- Engagement strategy
- Growth tactics specific to that platform

## 8. Partnership Opportunities
- Integration partners: 5-10 tools in the ecosystem, integration ideas, co-marketing potential
- Co-marketing: guest posts, podcast appearances, webinar swaps
- Affiliate program: structure, commission rates, recruitment strategy
- API/marketplace strategy if applicable

## 9. Paid Acquisition

### Organic-first mandate (all tiers)

Before any paid spend:
1. Exhaust free channels first (content marketing, community engagement, social media, Product Hunt launch, Show HN, relevant subreddits/forums)
2. Validate product-market fit with at least 10 organic paying customers
3. Only then test paid acquisition with small $50-100 experiments to measure CAC
4. Scale paid only when an organic CAC baseline exists for comparison

Calibrate to BUDGET tier:
- low: $0/month — organic only, do NOT spend on ads. All growth through content, community, and word-of-mouth.
- medium: $500-3000/month — Google Ads + one social channel (only after 10 organic paying customers)
- high: $3000-15000/month — multi-channel paid strategy (only after organic CAC baseline established)

For each channel:
- Estimated CAC
- Target ROAS
- Budget allocation percentage
- Ad copy examples
- Audience targeting strategy

## 10. Community Building
- Platform choice: Discord vs. Slack vs. other (with rationale)
- Channel/room structure
- Community launch strategy: seed with 20-50 members
- Engagement playbook: weekly rituals, AMAs, challenges
- Feedback loop: how community input feeds product roadmap
- Ambassador program: structure, rewards, recruitment

## 11. Related Forums & Communities

Use WebSearch to find forums, communities, and online spaces where the target audience for this SaaS idea already congregates. For each, provide:

| Forum/Community | URL | Platform | Audience Size | Relevance | Engagement Strategy |
|-----------------|-----|----------|---------------|-----------|-------------------|
| ... | ... | Reddit/Discord/Slack/Forum/Facebook Group/etc. | ... | high/medium | How to participate authentically |

Find at least 10 relevant communities. Include:
- Subreddits where the target problem is discussed
- Discord/Slack communities in the niche
- Industry-specific forums (Stack Overflow tags, niche forums)
- Facebook/LinkedIn groups
- Indie hacker / maker communities where this idea could get early traction
- Any niche-specific Q&A sites or discussion boards

For each community, write a specific engagement strategy: what kind of posts to make, how to offer value before promoting, what content to share, and how to build reputation.

Write the complete marketing playbook to `.saas-ideas/deep-dive/MARKETING-PLAYBOOK.md`.
```

---

### Agent 3: Tech Spec

Launch a background Agent (`subagent_type="general-purpose"`) with this prompt:

```
You are a senior software architect. Your job is to write a comprehensive technical specification for building a SaaS MVP.

**Selected idea:**
{SELECTED_IDEA}

**Budget tier:** {BUDGET}
**Focus domain:** {FOCUS}

Use WebSearch to research current best practices, framework comparisons, and hosting costs relevant to this tech stack. Ground your recommendations in real data.

Write a technical specification covering ALL 8 sections below. Be concrete — name specific technologies, services, and tools.

## 1. Recommended Stack

The following technologies are MANDATORY — do not substitute:
- **Database:** PostgreSQL — default to Neon free tier for ALL tiers until >1,000 users or >500MB. Do not use RDS until the Neon free tier is a proven bottleneck.
- **Auth:** Google OAuth (via next-auth, passport-google-oauth20, or equivalent)
- **Payments:** Stripe (Checkout, Billing, or Payment Intents as appropriate)
- **Hosting:** AWS — default to Lambda + API Gateway for ALL tiers. Avoid ECS/Fargate until >1M requests/month sustained.
- **Frontend hosting:** S3 + CloudFront or Cloudflare Pages (free unlimited bandwidth). Prefer Cloudflare Pages for zero-cost CDN.
- **Infrastructure as Code:** Terraform (all infra must be codified)
- **Domain:** Deploy as subdomain under `codingandmore.net` (e.g., `{app-name}.codingandmore.net`)
- **Cost justification:** For every tech choice, justify that it is the cheapest option that meets requirements. If a cheaper alternative exists, use it.

Choose the remaining technologies optimized for:
- AI-assisted development speed (Claude Code, Cursor, Copilot compatibility)
- Solo/small-team productivity
- Time to MVP
- BUDGET constraints

For each layer, name the specific technology and give a 1-2 sentence rationale:
- **Frontend:** framework, UI library, styling
- **Backend:** language, framework, API style (REST/GraphQL/tRPC)
- **AI tooling:** which AI coding tools to use and how

## 2. Architecture Overview
- System diagram description: client, API, database, external services, async jobs
- Key services and their responsibilities
- Data flow: describe the primary user flows through the system
- API design: key endpoints or queries
- Real-time requirements (if any): WebSockets, SSE, polling

## 3. MVP Scope

### v1 (MVP) — ship this
- List every feature with a one-sentence description
- Be ruthless about what's in vs. out
- Define "done" for the MVP: what must work for the first user?

### v2 — next iteration
- Features deferred from v1 with reasoning

### v3 — future
- Aspirational features that require scale or data

## 4. Data Model
Define core entities with their fields and relationships:

For each entity:
- Entity name
- Key fields (name, type, constraints)
- Relationships (belongs_to, has_many, many_to_many)
- Indexes

Provide this as a structured list or pseudo-schema, not raw SQL.

## 5. Third-Party Services

MANDATORY services (do not substitute):
- **Auth:** Google OAuth
- **Payments:** Stripe
- **Hosting/Infra:** AWS + Terraform
- **Database:** PostgreSQL (AWS RDS, Supabase, or Neon)

For remaining services, recommend specific providers:

| Category | Service | Tier/Plan | Monthly Cost | Why |
|----------|---------|-----------|-------------|-----|
| Auth | Google OAuth | Free | $0 | Mandatory |
| Payments | Stripe | Standard | 2.9% + $0.30/txn | Mandatory |
| Database | PostgreSQL (RDS/Supabase/Neon) | ... | ... | Mandatory |
| Email (transactional) | ... | ... | ... | ... |
| Email (marketing) | ... | ... | ... | ... |
| Analytics | ... | ... | ... | ... |
| Error monitoring | ... | ... | ... | ... |
| Logging | ... | ... | ... | ... |
| File storage | ... | ... | ... | ... |

**Free-tier defaults (apply at launch for ALL tiers, including high):**

| Category | Free-Tier Default | Free Limit | Upgrade Trigger |
|---|---|---|---|
| Email (transactional) | Resend | 3K emails/mo | >3K/mo |
| Analytics | PostHog | 1M events/mo | >1M events |
| Error monitoring | Sentry | 5K events/mo | >5K/mo |
| Logging | AWS CloudWatch | 5GB ingest/mo | >5GB |
| File storage | AWS S3 | 5GB + 20K GET/mo | >5GB |
| Uptime monitoring | BetterStack free | 5 monitors | >5 monitors |

Only upgrade to paid tiers when a free tier's hard limit is actually hit — not speculatively. Budget tiers govern how aggressively you scale *after* hitting limits, not the starting point.

## 6. Infrastructure (AWS + Terraform)

All infrastructure MUST be defined in Terraform. Provide Terraform module structure.

### Serverless-first architecture (all tiers)

Default to serverless components that cost $0 at idle:
- **Compute:** Lambda + API Gateway ($0 at idle, pay only per invocation)
- **Database:** Neon serverless PostgreSQL ($0 at idle, free tier generous for MVP)
- **CDN:** Cloudflare free tier (unlimited bandwidth, free DNS/SSL) — preferred over CloudFront
- **Static hosting:** S3 or Cloudflare Pages

Only provision always-on compute (ECS/Fargate, RDS) when sustained traffic makes serverless more expensive (typically >1M requests/month or >$50/mo Lambda spend).

- **Domain:** configure as `{app-name}.codingandmore.net` via Route53 + ACM certificate (or Cloudflare DNS)
- **Terraform module layout:** list the `.tf` files and what each defines
- **CI/CD pipeline:** GitHub Actions → build → test → deploy to AWS
- **Environment strategy:** local (Docker Compose), staging (`staging.{app-name}.codingandmore.net`), production (`{app-name}.codingandmore.net`)
- Estimated monthly infrastructure cost (serverless baseline):

| Users | Compute | Database | Storage | Services | Total/month |
|-------|---------|----------|---------|----------|-------------|
| 0-100 | $0 (Lambda free tier) | $0 (Neon free) | $0 (S3 free tier) | $0 (all free tiers) | **$0** |
| 1,000 | $1-5 | $0-19 | $0-5 | $5-8 | **$6-37** |
| 10,000 | $10-30 | $19-50 | $5-15 | $36-100 | **$70-195** |

## 7. AI Leverage Points

### AI for development acceleration
- Which development tasks benefit most from AI coding tools?
- Specific prompting strategies for this codebase
- Where AI-generated code needs careful review

### AI as product feature
- Where can AI features add product value? (if applicable)
- Build vs. buy for AI features
- Cost implications of AI API calls at scale

## 8. Timeline
Week-by-week MVP build plan calibrated for BUDGET:
- low: solo dev with AI tooling, 2-4 weeks
- medium: 2-5 person team with AI tooling, 4-8 weeks
- high: funded team (5-15), 8-16 weeks

| Week | Milestone | Key Deliverables | AI Tooling Notes |
|------|-----------|-----------------|-----------------|
| 1 | ... | ... | ... |
| 2 | ... | ... | ... |
| ... | ... | ... | ... |

Include buffer time and identify the critical path.

Write the complete technical specification to `.saas-ideas/deep-dive/TECH-SPEC.md`.
```

---

### Agent 4: Implementation Prompts

Launch a background Agent (`subagent_type="general-purpose"`) with this prompt:

```
You are a prompt engineer specializing in AI-assisted software development. Your job is to write a set of self-contained implementation prompts that a developer can use to build a SaaS MVP step by step using Claude Code.

**Selected idea:**
{SELECTED_IDEA}

**Budget tier:** {BUDGET}
**Focus domain:** {FOCUS}

Each prompt you write must be fully self-contained — it should include all necessary context so a developer can paste it directly and get working results. Do not reference external documents within the prompts themselves; embed all needed context inline.

**MANDATORY stack (hardcoded in all prompts):**
- Database: PostgreSQL
- Auth: Google OAuth
- Payments: Stripe
- Hosting: AWS
- Infrastructure: Terraform
- Domain: `{app-name}.codingandmore.net`

**Cost optimization defaults (hardcoded in all prompts):**
- Database: Neon free tier (serverless PostgreSQL, $0 at idle)
- Compute: Lambda + API Gateway ($0 at idle)
- CDN: Cloudflare free tier (unlimited bandwidth, free DNS/SSL)
- Email: Resend free tier (3K emails/mo)
- Analytics: PostHog free tier (1M events/mo)
- Error monitoring: Sentry free tier (5K events/mo)
- Cost alerts: AWS Cost Explorer alerts at $5/mo and $20/mo thresholds
- Cost tracking: `COST-LOG.md` in repo root — updated monthly with actual spend per service
- **Cost verification acceptance criteria:** $0/month at <100 users

**Phase 0 (before building features):** Set up cost monitoring — AWS Cost Explorer alerts, Stripe dashboard, `COST-LOG.md` initialized with $0 baseline.

**Goal: Complete working prototype.** The prompts should aim to produce fully deployable code, not just scaffolding. Each phase prompt should generate actual working code that can be tested and deployed.

Write implementation prompts covering ALL 5 categories below.

## 1. Project Initialization Prompt

Write a single comprehensive prompt for `/gsd:new-project` that sets up the entire project from scratch. It must include:
- Project name and description
- Tech stack decisions (reference SELECTED_IDEA context)
- Directory structure
- Initial dependencies
- Development environment setup
- Git initialization with conventional commits

## 2. Phase-by-Phase Build Prompts

Write one detailed prompt for each build phase. Each prompt should specify what to build, acceptance criteria, and which approach to use.

Include these phases (adapt based on the specific idea):

### Phase 1: Authentication & User Management
- What to implement: signup, login, password reset, user profile
- Use `superpowers:writing-plans` to plan the approach before coding
- Use `superpowers:test-driven-development` for all implementation work
- Acceptance criteria: user can sign up, log in, reset password

### Phase 2: Core Feature
- What to implement: the primary value-delivering feature of the product
- Use `superpowers:brainstorming` for any design decisions
- Use `superpowers:writing-plans` to plan the implementation
- Use `superpowers:test-driven-development` for all coding
- Use `superpowers:subagent-driven-development` for independent parallel tasks
- Acceptance criteria: specific to the idea

### Phase 3: Data Model & API
- What to implement: database schema, API endpoints, data validation
- Use `superpowers:writing-plans` before implementation
- Use `superpowers:test-driven-development` for all coding
- Acceptance criteria: all CRUD operations work, data validation enforced

### Phase 4: Billing & Subscriptions
- What to implement: pricing page, payment integration, subscription management
- Use `superpowers:writing-plans` before implementation
- Use `superpowers:test-driven-development` for all coding
- Acceptance criteria: user can subscribe, upgrade, downgrade, cancel

### Phase 5: Landing Page & Marketing Site
- What to implement: landing page, pricing page, about page, blog setup
- Use `superpowers:brainstorming` for design decisions
- Use `superpowers:writing-plans` before implementation
- Acceptance criteria: pages render correctly, CTA works, SEO basics in place

### Phase 6: Polish & Launch Prep
- What to implement: error handling, loading states, email notifications, analytics
- Use `superpowers:systematic-debugging` for any bug encounters
- Use `superpowers:requesting-code-review` after each milestone
- Use `superpowers:verification-before-completion` before merge/PR
- Acceptance criteria: no console errors, all happy paths tested, monitoring in place

For each phase prompt, also include:
- Use `/gw:worktree create <name>` for feature branch isolation
- Use `superpowers:finishing-a-development-branch` when the branch is complete

### Superpowers reference table

When working through these phases, apply the appropriate superpowers skill at each stage:

| Build Phase | Superpowers Skill Reference |
|-------------|----------------------------|
| Design decisions | `superpowers:brainstorming` |
| Before coding each phase | `superpowers:writing-plans` |
| All coding work | `superpowers:test-driven-development` |
| Independent parallel tasks | `superpowers:subagent-driven-development` |
| Bug encounters | `superpowers:systematic-debugging` |
| After each milestone | `superpowers:requesting-code-review` |
| Before merge/PR | `superpowers:verification-before-completion` |
| Feature branches | `/gw:worktree create <name>` |
| Branch completion | `superpowers:finishing-a-development-branch` |

## 3. Marketing Execution Prompts

Write prompts for:
- Landing page copywriting: generate all copy for the landing page based on the marketing playbook
- Blog post generation: prompt template for generating SEO-optimized blog posts with topic, keywords, and audience parameters
- Email sequence writing: prompt for generating the complete email sequences (welcome, trial-to-paid, churn prevention)

Each prompt must be self-contained with all context embedded.

## 4. Testing Prompts

Write prompts for:
- Unit test generation: prompt for generating comprehensive unit tests for each module
- Integration test generation: prompt for API endpoint and database integration tests
- E2E test generation: prompt for critical user flow end-to-end tests
- Load test setup: prompt for setting up basic load testing

Each prompt must specify the testing framework, patterns, and coverage targets.

## 5. Launch Checklist

Write an actionable, ordered checklist for launch day:
- Pre-launch verification steps (DNS, SSL, monitoring, backups)
- Launch sequence (when to post where, in what order)
- Post-launch monitoring (what to watch for in the first 24 hours)
- Rollback plan (what to do if something breaks)
- Day-2 follow-up actions

The checklist should be concrete steps, not vague advice.

Write the complete implementation prompts document to `.saas-ideas/deep-dive/IMPLEMENTATION-PROMPTS.md`.
```

---

### Launch all deep-dive agents

Apply `superpowers:dispatching-parallel-agents` pattern — Launch ALL 4 agents in a SINGLE message using the Agent tool. Each call must set `run_in_background=true`. Do not wait for one agent to finish before launching the next — they all run in parallel.

After launching, you will be notified as each background agent completes. Wait for ALL 4 to finish before proceeding.

---

### Deep-dive validation

After all 4 agents complete, validate the results:

1. Check each expected file exists and has substantive content (more than 20 lines):
   - `.saas-ideas/deep-dive/BUSINESS-PLAN.md`
   - `.saas-ideas/deep-dive/MARKETING-PLAYBOOK.md`
   - `.saas-ideas/deep-dive/TECH-SPEC.md`
   - `.saas-ideas/deep-dive/IMPLEMENTATION-PROMPTS.md`

2. Print a status table:
   ```
   Deep-Dive Status:
   [done]   BUSINESS-PLAN.md          ({N} lines)
   [done]   MARKETING-PLAYBOOK.md     ({N} lines)
   [done]   TECH-SPEC.md              ({N} lines)
   [FAILED] IMPLEMENTATION-PROMPTS.md (file missing)
   ```

3. Apply criticality-aware retry logic:
   - **CRITICAL agents** (Business Plan, Tech Spec): if either fails, offer to retry before proceeding (max 2 retries per agent). These are essential for the downstream deliverables. If BOTH Business Plan AND Tech Spec fail after retries, stop and tell the user: "Critical deliverables could not be generated. Check network/context limits and retry with `/gw:saas-idea --pick N`."
   - **Non-critical agents** (Marketing Playbook, Implementation Prompts): if either fails, note the failure and continue. The user can regenerate these later.

---

## Phase 3.5 — Coherence Verification (conditional)

**Skip this phase entirely if VERIFY_MODE is false.** Only run when VERIFY_MODE is true.

Apply `superpowers:verification-before-completion` — launch a single **foreground** Agent (`subagent_type="general-purpose"`) that reads all deep-dive artifacts and checks cross-document coherence.

### Verification agent prompt

```
You are a quality assurance analyst. Your job is to verify coherence across SaaS idea deliverables before proceeding to final assembly.

Read the following files:
- `.saas-ideas/deep-dive/TECH-SPEC.md`
- `.saas-ideas/deep-dive/IMPLEMENTATION-PROMPTS.md`
- `.saas-ideas/deep-dive/BUSINESS-PLAN.md`

Run these 4 coherence checks and report results:

### Check 1: Mandatory Stack
Verify that ALL of the following appear in BOTH TECH-SPEC.md AND IMPLEMENTATION-PROMPTS.md:
- PostgreSQL (database)
- Google OAuth (auth)
- Stripe (payments)
- AWS (hosting)
- Terraform (infrastructure)
- codingandmore.net (domain)

### Check 2: Phase Alignment
Verify that the timeline phases/milestones in TECH-SPEC.md (Section 8: Timeline) align with the build phases in IMPLEMENTATION-PROMPTS.md (Section 2: Phase-by-Phase Build Prompts). Check that:
- The number of phases is consistent (or logically mapped)
- Phase descriptions cover the same scope
- No major feature appears in one document but is missing from the other

### Check 3: Budget Consistency
Verify that the BUDGET tier is applied consistently:
- Revenue projections in BUSINESS-PLAN.md match the budget tier assumptions
- Infrastructure costs in TECH-SPEC.md match the budget tier
- Team size assumptions are consistent across all documents
- Timeline estimates are calibrated to the budget tier

### Check 4: Idea Coherence
Verify that the idea name, description, and core value proposition are consistent across all three documents. No document should describe a fundamentally different product.

Write the verification report to `.saas-ideas/deep-dive/VERIFICATION.md` in this format:

```markdown
# Coherence Verification Report

**Date:** {today's date}
**Idea:** {idea name}

## Results

| Check | Status | Details |
|-------|--------|---------|
| Mandatory Stack | PASS/FAIL | {which items are present/missing in which files} |
| Phase Alignment | PASS/FAIL | {alignment summary or mismatches found} |
| Budget Consistency | PASS/FAIL | {consistency summary or contradictions found} |
| Idea Coherence | PASS/FAIL | {coherence summary or discrepancies found} |

## Summary
{overall assessment — all pass, or list of issues to address}
```
```

After the verification agent completes:

1. Read `.saas-ideas/deep-dive/VERIFICATION.md` and print the results table to the user.
2. **If BUILD_MODE is true and any check is FAIL:** Ask the user "Verification found issues (see above). Continue to build anyway? [y/n]". If the user says no, stop and let them fix the artifacts manually.
3. **If all checks PASS or BUILD_MODE is false:** Continue to Phase 4.

---

## Phase 4 — Final Assembly

Phase 4 is orchestrator-driven. Only Step 1 uses a subagent. Steps 2-5 are executed directly by the orchestrator.

### Step 1 — Pitch Deck (foreground subagent)

Launch a single **foreground** Agent (subagent_type="general-purpose") with this prompt:

"You are a pitch deck designer. Read ALL deep-dive files from `.saas-ideas/deep-dive/`:
- `BUSINESS-PLAN.md`
- `MARKETING-PLAYBOOK.md`
- `TECH-SPEC.md`
- `IMPLEMENTATION-PROMPTS.md`

Generate a complete Python script that uses `python-pptx` to create a 10-slide investor pitch deck saved to `docs/gw/pitch-deck.pptx`.

**Design system** (canonical gw-skills palette):
```
PRIMARY      = RGBColor(0x2C, 0x3E, 0x50)  # dark blue-gray — titles, headers
SECONDARY    = RGBColor(0x34, 0x49, 0x5E)  # medium blue-gray — body text
ACCENT       = RGBColor(0x34, 0x98, 0xDB)  # bright blue — highlights, KPIs
SUCCESS      = RGBColor(0x27, 0xAE, 0x60)  # green — good health, positive signals
DANGER       = RGBColor(0xE7, 0x4C, 0x3C)  # red — risks, critical issues
WARNING      = RGBColor(0xF3, 0x9C, 0x12)  # amber — warnings, cautions
MUTED        = RGBColor(0x95, 0xA5, 0xA6)  # gray — captions, labels
BG_WHITE     = RGBColor(0xFF, 0xFF, 0xFF)
BG_LIGHT     = RGBColor(0xF8, 0xF9, 0xFA)
```

- Font: Calibri throughout
- Slide dimensions: 16:9 widescreen (13.333" x 7.5")
- Accent bar: 0.06" wide ACCENT strip at left edge of every slide
- Layout: Title + subtitle top bar on each slide, content area with generous margins (at least 0.75" on all sides), slide numbers bottom-right

**10 slides:**

| # | Slide | Content |
|---|-------|---------|
| 1 | **Title** | Idea name (32pt bold, dark blue), tagline (18pt, accent blue), date (14pt, gray) centered on slide |
| 2 | **The Problem** | Pain point description with supporting market stats. Use bullet points with accent blue markers. Include a pull-quote style callout for the most compelling stat. |
| 3 | **The Solution** | What it does in one sentence (large text), then 3-4 key differentiators as icon-style bullet points |
| 4 | **Market Opportunity** | TAM/SAM/SOM as three nested rounded rectangles (largest to smallest), each labeled with dollar amounts. Source data from BUSINESS-PLAN.md market analysis. |
| 5 | **Business Model** | Pricing tiers as a comparison table (light gray alternating rows). Revenue projections note below. |
| 6 | **Competitive Landscape** | 2x2 positioning matrix with axes labeled. Place competitors and the product as positioned shapes. Source from BUSINESS-PLAN.md competitive analysis. |
| 7 | **Go-to-Market** | Launch strategy as a horizontal timeline with 4-5 phases. Each phase is a rounded rectangle with title and key action. Source from MARKETING-PLAYBOOK.md. |
| 8 | **Tech Architecture** | Stack diagram showing frontend/backend/infra layers as stacked rounded rectangles. Highlight: PostgreSQL, Google OAuth, Stripe, AWS, Terraform. MVP timeline as bullet points. Include note: 'AI-accelerated development → deployed at {app-name}.codingandmore.net'. Source from TECH-SPEC.md. |
| 9 | **Traction Plan** | Month-by-month growth targets for months 1-6 as a simple table. Key milestones highlighted in accent blue. |
| 10 | **The Ask / Next Steps** | What's needed to start — bullet points for resources, budget, timeline. Bold call-to-action at bottom. |

**Important Python implementation details:**
- Import `json`, `os`, `sys` at the top
- Use `from pptx import Presentation` and related imports from `python-pptx`
- Use `from pptx.util import Inches, Pt, Emu` and `from pptx.dml.color import RGBColor`
- Use `from pptx.enum.text import PP_ALIGN` and `from pptx.enum.shapes import MSO_SHAPE`
- Create helper functions: `add_title_bar(slide, title, subtitle)`, `add_slide_number(slide, num)`, `set_cell_style(cell, bold, color)`
- Each slide should be a separate function for clarity
- The script must be self-contained — read the markdown files, extract relevant content, and build all 10 slides
- Write the output file to `docs/gw/pitch-deck.pptx`
- Print the absolute path of the generated file on success

Write the script to `/tmp/saas_pitch_deck_gen.py`, then execute it.

**Execution chain:**

1. Try:
   ```bash
   mkdir -p docs/gw
   uv run --with python-pptx python3 /tmp/saas_pitch_deck_gen.py
   ```

2. If `uv` is not available or fails, fall back to:
   ```bash
   pip install python-pptx && python3 /tmp/saas_pitch_deck_gen.py
   ```

3. If both fail, generate an HTML file at `docs/gw/pitch-deck.html` instead with the same 10-slide content as a styled HTML presentation. Note the limitation to the user: 'Generated HTML pitch deck as fallback — python-pptx was not available.'

If the Python script fails: show the error output, examine the script for issues, fix, and retry once. If it fails again, fall back to HTML."

---

### Step 2 — Executive Report (orchestrator writes directly)

Read all deep-dive files from `.saas-ideas/deep-dive/`. Also read `.saas-ideas/SHORTLIST.md` for the selected idea details. Write `.saas-ideas/REPORT.md` with this structure:

```markdown
# SaaS Idea Report: {Idea Name}

**Generated:** {today's date}
**Score:** {X}/10
**Tagline:** {one-liner}
**Budget:** {BUDGET}
**Focus:** {FOCUS or "none"}

## Executive Summary
{3-5 sentences — what the product does, why the market needs it, how big the opportunity is, how fast you can ship an MVP}

## Deliverables
| File | Description |
|------|-------------|
| SHORTLIST.md | Top 10 ranked ideas with scores |
| deep-dive/BUSINESS-PLAN.md | Full business plan |
| deep-dive/MARKETING-PLAYBOOK.md | Go-to-market playbook |
| deep-dive/TECH-SPEC.md | Architecture & MVP spec |
| deep-dive/IMPLEMENTATION-PROMPTS.md | Ready-to-use Claude Code prompts |
| docs/gw/pitch-deck.pptx | Investor/co-founder pitch deck |

## Quick Start
1. Review the business plan
2. Run the project init prompt from IMPLEMENTATION-PROMPTS.md
3. Follow the phase-by-phase prompts to build the MVP
```

Replace all `{...}` placeholders with actual values extracted from the deep-dive files and shortlist. The executive summary should be substantive — not generic filler.

---

### Step 3 — Update History (orchestrator writes directly)

Read `.saas-ideas/history.json`. If the file does not exist, create it with `{"runs": []}`.

Parse the existing JSON, then **append** a new entry to the `runs` array:

```json
{
  "date": "YYYY-MM-DD",
  "ideas_surfaced": ["Idea Name 1", "Idea Name 2", "...all 10 from shortlist..."],
  "selected": "Selected Idea Name",
  "focus": "FOCUS value or null",
  "budget": "BUDGET value",
  "score": 8.4
}
```

Populate the fields:
- `date`: today's date
- `ideas_surfaced`: all 10 idea names from SHORTLIST.md
- `selected`: the #1 ranked idea that was deep-dived
- `focus`: the FOCUS argument value, or `null` if none was provided
- `budget`: the BUDGET argument value
- `score`: the composite score of the selected idea

Write the updated JSON back to `.saas-ideas/history.json`. Do NOT overwrite previous entries — the `runs` array accumulates across invocations.

---

### Step 4 — Implementation Bridge (orchestrator)

Skip this step if SKIP_PLANNING is true.

#### 4a. Generate project files

**If BUILD_MODE is true:** Auto-generate CLAUDE.md and SPEC.md silently (no prompt), then continue to 4c.

**If BUILD_MODE is false:** Ask the user:

```
Generate project files for implementation?

This will create:
  - CLAUDE.md — project context, tech stack (PostgreSQL, Google OAuth, Stripe, AWS, Terraform), constraints
  - SPEC.md  — requirements, user flows, data model, API design, success criteria

Source: .saas-ideas/deep-dive/ (Business Plan, Tech Spec, Marketing Playbook, Implementation Prompts)

Generate and choose workflow [y], or go straight to planning [g], or skip [n]?
```

**If [n]:** Skip to Step 5.

**If [g]:** Skip to 4c (GSD integration).

**If [y]:** Generate both files:

**Generate `.saas-ideas/CLAUDE.md`:**

Read all deep-dive artifacts. Write `.saas-ideas/CLAUDE.md` with this structure:

```markdown
<!-- Generated by gw:saas-idea on {date} from .saas-ideas/deep-dive/ artifacts -->

# {Idea Name}

## What This Is
{From REPORT.md Executive Summary}

## Tech Stack
{From TECH-SPEC.md Section 1 — the mandatory stack defaults to PostgreSQL, Google OAuth, Stripe, AWS, Terraform per user preferences}
{List each technology with one-line rationale from TECH-SPEC.md}

## Architecture
{From TECH-SPEC.md Section 2 — system diagram, key services, data flow}

## Constraints
- **Budget:** {BUDGET tier} — {timeline and team size implications}
- **Domain:** Deploy as subdomain under codingandmore.net
- **Mandatory stack:** PostgreSQL, Google OAuth, Stripe, AWS, Terraform (non-negotiable)
- **Cost:** $0/month target at <100 users (free-tier-first principle)
{From BUSINESS-PLAN.md Section 9 — top risks as constraints}

## Coding Conventions
- Use TDD for all features (`superpowers:test-driven-development`)
- Plan before coding (`superpowers:writing-plans`)
- Verify before claiming done (`superpowers:verification-before-completion`)
- Debug systematically (`superpowers:systematic-debugging`)
- Commit frequently with conventional commits
- Cost verification: $0/month at <100 users

## Recommended Skills
- `superpowers:writing-plans` — plan multi-step tasks before coding
- `superpowers:test-driven-development` — TDD for all implementation
- `superpowers:verification-before-completion` — verify before claiming done
- `superpowers:systematic-debugging` — for any failures
- `superpowers:brainstorming` — for design decisions
- `/gw:worktree create <name>` — for feature branch isolation
- `gw:review-app` — quality analysis after implementation
- `gw:compete` — competitive analysis for positioning

## Key Decisions
{From BUSINESS-PLAN.md — pricing model, target audience, go-to-market}
{From TECH-SPEC.md — architecture choices, build vs buy}
{From debate CONSENSUS.md — if debate ran, key debate outcomes}

## External Services
{From TECH-SPEC.md Section 5 — third-party services table}
{From BUSINESS-PLAN.md Section 6 — payment/billing setup}

## Deployment
{From TECH-SPEC.md Section 6 — AWS infrastructure, Terraform modules, CI/CD}
- Domain: {app-name}.codingandmore.net
- Environments: local (Docker Compose), staging, production

## References
- Business Plan: `.saas-ideas/deep-dive/BUSINESS-PLAN.md`
- Tech Spec: `.saas-ideas/deep-dive/TECH-SPEC.md`
- Marketing Playbook: `.saas-ideas/deep-dive/MARKETING-PLAYBOOK.md`
- Implementation Prompts: `.saas-ideas/deep-dive/IMPLEMENTATION-PROMPTS.md`
- Shortlist: `.saas-ideas/SHORTLIST.md`
- Report: `.saas-ideas/REPORT.md`
```

**Generate `.saas-ideas/SPEC.md`:**

Read all deep-dive artifacts. Write `.saas-ideas/SPEC.md` with this structure:

```markdown
# {Idea Name} — Specification

**Generated:** {date}
**Source:** gw:saas-idea deep-dive artifacts
**Score:** {composite score}/10
**Budget:** {BUDGET tier}

## Goal
{From REPORT.md Executive Summary — one sentence}

## Requirements

### Core Features (MVP)
{From TECH-SPEC.md Section 3 (MVP Scope) — each v1 feature becomes a checkbox}
- [ ] {Feature 1}
- [ ] {Feature 2}

### Authentication
- [ ] Google OAuth sign-in
- [ ] Session management
- [ ] User profile

### Billing & Payments
{From TECH-SPEC.md + BUSINESS-PLAN.md Section 6}
- [ ] Stripe integration
- [ ] Pricing tiers: {from BUSINESS-PLAN.md}
- [ ] Subscription management

### Technical Requirements
- [ ] PostgreSQL database with migrations
- [ ] AWS Lambda + API Gateway deployment
- [ ] Terraform infrastructure
- [ ] CI/CD pipeline (GitHub Actions)
- [ ] Cost monitoring ($0/month target at <100 users)

### Non-Functional Requirements
- [ ] Sub-second response for core flows
- [ ] 99.9% uptime target
- [ ] HTTPS everywhere
- [ ] Input validation on all endpoints

## User Flows
{From MARKETING-PLAYBOOK.md — onboarding flow, core feature flow, payment flow}

### Flow 1: Onboarding
1. User lands on {app-name}.codingandmore.net
2. Clicks "Sign in with Google"
3. Sees onboarding wizard
4. Reaches "aha moment"

### Flow 2: Core Feature
{From TECH-SPEC.md Section 3 — the primary value-delivering flow}

### Flow 3: Payment
1. User hits feature gate
2. Sees pricing page
3. Selects tier, enters Stripe Checkout
4. Returns to upgraded account

## Data Model
{From TECH-SPEC.md Section 4 — entities, fields, relationships}

## API Design
{From TECH-SPEC.md Section 2 — key endpoints}

## Out of Scope
{From TECH-SPEC.md Section 3 v3 features}
{From debate trap features if debate ran}

## Success Criteria
- [ ] User can sign up via Google OAuth
- [ ] User can perform core feature
- [ ] User can subscribe via Stripe
- [ ] Deployed to {app-name}.codingandmore.net
- [ ] $0/month infrastructure cost at <100 users
{From IMPLEMENTATION-PROMPTS.md — acceptance criteria per phase}

## Implementation Phases
{From TECH-SPEC.md Section 8 — week-by-week timeline}

## References
- `.saas-ideas/deep-dive/BUSINESS-PLAN.md`
- `.saas-ideas/deep-dive/TECH-SPEC.md`
- `.saas-ideas/deep-dive/MARKETING-PLAYBOOK.md`
- `.saas-ideas/deep-dive/IMPLEMENTATION-PROMPTS.md`
```

#### 4b. Copy to project root and choose workflow

**Copy logic for CLAUDE.md:**
- If `CLAUDE.md` exists at project root, ask: "CLAUDE.md already exists. Overwrite [o], merge [m], or keep in .saas-ideas/ only [k]?"
  - **Overwrite:** replace entirely
  - **Merge:** append a `## Generated by gw:saas-idea` section to the existing file
  - **Keep:** don't copy
- If it doesn't exist, copy directly. "Project root" = current working directory.

**Copy logic for SPEC.md:**
- If `SPEC.md` exists at project root, ask: "SPEC.md already exists. Overwrite [o], or keep in .saas-ideas/ only [k]?"
  - **Overwrite:** replace entirely
  - **Keep:** don't copy
  - No merge option — merging two requirement specs creates duplicates.
- If it doesn't exist, copy directly.

Then ask (skip this prompt if BUILD_MODE is true — auto-continue to 4c):

```
Generated:
  .saas-ideas/CLAUDE.md  ({N} lines)
  .saas-ideas/SPEC.md    ({N} lines)
  Copied to project root: ./CLAUDE.md, ./SPEC.md

How would you like to proceed with implementation?
  [p] Superpowers — invoke superpowers:writing-plans with SPEC.md (recommended)
  [g] GSD — create project/milestone from tech spec (alternative)
  [d] Done — files generated, handle implementation manually
```

**If [p]:** Tell the user: "Invoking superpowers:writing-plans. The plan will use CLAUDE.md for project context and SPEC.md for requirements." Then invoke the Skill tool: `Skill(skill="superpowers:writing-plans")`.

**If [g]:** Continue to 4c.

**If [d]:** Skip to Step 5.

#### 4c. GSD integration (alternative)

**If BUILD_MODE is true:** Print "GSD integration deferred to Phase 5 (build mode)." and skip to Step 5. Phase 5 handles the full GSD auto-chain.

**If BUILD_MODE is false:** Proceed with shallow GSD init below.

Check if `~/.claude/commands/gsd/` exists. If it does:

1. Check if `.planning/PROJECT.md` exists (i.e., GSD project already initialized).
   - **If yes (brownfield/existing project):** Automatically invoke `/gsd:new-milestone` and reference `.saas-ideas/deep-dive/TECH-SPEC.md` as the requirements source. Tell the user you are creating a new GSD milestone from the tech spec phases. Include project context: "This project was generated by /gw:saas-idea. Apply superpowers at each phase: brainstorming → writing-plans → test-driven-development → verification-before-completion. Full superpowers workflow: brainstorm → plan → TDD → review → verify for each phase."
   - **If no (greenfield):** Automatically invoke `/gsd:new-project` and reference `.saas-ideas/deep-dive/TECH-SPEC.md` as the requirements source. Tell the user you are creating a GSD project from the tech spec. Include project context: "This project was generated by /gw:saas-idea. Apply superpowers at each phase: brainstorming → writing-plans → test-driven-development → verification-before-completion. Full superpowers workflow: brainstorm → plan → TDD → review → verify for each phase."

If GSD commands don't exist, say: "GSD not installed. Use [p] Superpowers instead, or find the full plan in `.saas-ideas/`." and stop.

**Prototype generation goal:** The GSD project/milestone should target generating a **complete working prototype** — not just plans. The implementation prompts and GSD phases should aim to produce deployable code with:
- Working auth (Google OAuth)
- Working payments (Stripe integration)
- Core feature functionality
- PostgreSQL database with migrations
- Terraform configs for AWS deployment
- Deployed to `{app-name}.codingandmore.net`

Tell the user: "GSD will scaffold a project targeting a fully deployable prototype at `{app-name}.codingandmore.net`."

#### Error handling for Step 4

- If `.saas-ideas/deep-dive/TECH-SPEC.md` or `.saas-ideas/deep-dive/BUSINESS-PLAN.md` do not exist: "Cannot generate project files — deep-dive artifacts are missing. Run the full saas-idea workflow first or use `--pick N` to regenerate."
- If file copy fails (permissions): generate in `.saas-ideas/` only, tell user: "Could not copy to project root (permission denied). Files available at .saas-ideas/CLAUDE.md and .saas-ideas/SPEC.md."
- If superpowers:writing-plans is not available when [p] is selected: "superpowers:writing-plans not found. The files are ready at {paths} — invoke the skill manually when available."

---

### Step 4.5 — Parallel Build (optional)

Generate a build manifest from the deep-dive artifacts and offer parallel worktree execution.

1. Read `TECH-SPEC.md` from `.saas-ideas/deep-dive/`
2. Read `IMPLEMENTATION-PROMPTS.md` from `.saas-ideas/deep-dive/`
3. Parse the 6 build phases into features:

| Feature | Dependencies | Description source |
|---------|-------------|-------------------|
| `auth` | none | Phase 1 from IMPLEMENTATION-PROMPTS.md |
| `landing-page` | none | Phase 5 from IMPLEMENTATION-PROMPTS.md |
| `core-feature` | `auth` | Phase 2 from IMPLEMENTATION-PROMPTS.md |
| `data-api` | `core-feature` | Phase 3 from IMPLEMENTATION-PROMPTS.md |
| `billing` | `core-feature` | Phase 4 from IMPLEMENTATION-PROMPTS.md |
| `polish` | `auth`, `core-feature`, `data-api`, `billing`, `landing-page` | Phase 6 from IMPLEMENTATION-PROMPTS.md |

4. For each feature:
   - Extract `description` from the corresponding phase prompt in IMPLEMENTATION-PROMPTS.md
   - Extract `acceptance_tests` from the phase's "Verify" or "Success criteria" section
   - Set `spec_file` to `.saas-ideas/deep-dive/TECH-SPEC.md`
5. Set `tech_stack` from the hardcoded stack: `{"db": "PostgreSQL", "auth": "Google OAuth", "payments": "Stripe", "cloud": "AWS", "iac": "Terraform", "domain": "codingandmore.net"}`
6. Set `project` to the slugified idea name from the deep-dive
7. Write manifest to `.saas-ideas/build-manifest.json`
8. Commit the manifest: `git add .saas-ideas/build-manifest.json && git commit -m "feat: generate build manifest for parallel execution"`

Ask the user:

```
Build manifest generated with 6 features in 4 waves:
  Wave 1: auth, landing-page
  Wave 2: core-feature
  Wave 3: data-api, billing
  Wave 4: polish

Build all features in parallel worktrees with TDD? [y] / Generate manifest only (already saved) [m] / Skip [s]
```

- `[y]`: invoke `/gw:worktree execute .saas-ideas/build-manifest.json`
- `[m]`: tell user: "Manifest saved. Run `/gw:worktree execute .saas-ideas/build-manifest.json` when ready."
- `[s]`: continue to Step 5

---

### Step 5 — Present Results (orchestrator)

Print the following to the user:

1. **Executive Summary** — read and display the Executive Summary section from `.saas-ideas/REPORT.md`

2. **File listing** — list all generated files with sizes:
   ```
   Generated Files:
     .saas-ideas/SHORTLIST.md              ({N} KB)
     .saas-ideas/REPORT.md                 ({N} KB)
     .saas-ideas/history.json              ({N} KB)
     .saas-ideas/deep-dive/BUSINESS-PLAN.md       ({N} KB)
     .saas-ideas/deep-dive/MARKETING-PLAYBOOK.md  ({N} KB)
     .saas-ideas/deep-dive/TECH-SPEC.md           ({N} KB)
     .saas-ideas/deep-dive/IMPLEMENTATION-PROMPTS.md ({N} KB)
     docs/gw/pitch-deck.pptx                      ({N} KB)
     .saas-ideas/CLAUDE.md                          ({N} KB)  {if generated}
     .saas-ideas/SPEC.md                            ({N} KB)  {if generated}
     ./CLAUDE.md                                    (copied to project root)  {if copied}
     ./SPEC.md                                      (copied to project root)  {if copied}
   ```

3. Print: "Pitch deck saved to `docs/gw/pitch-deck.pptx`"

4. If VERIFY_MODE was true: read `.saas-ideas/deep-dive/VERIFICATION.md` and include a one-line verification summary (e.g., "Verification: 4/4 checks passed" or "Verification: 3/4 checks passed — Budget Consistency FAIL").

5. If BUILD_MODE was true: print "GSD project is building — check progress with `/gsd:progress`."

6. If GSD was invoked in Step 4 (shallow init, not build mode), note whether a project or milestone was created and where to find it.

7. If any Phase 3 agents failed (non-critical), remind the user which files are missing and that they can re-run the skill with the same arguments to regenerate them.

8. Print the full pipeline command hint:
   ```
   Tip: To run the full pipeline next time:
     /gw:saas-idea --build --budget low
     /gw:saas-idea --build --budget low --focus devtools
     /gw:saas-idea --auto --verify
   ```

---

### Step 5.5 — Persona Contribution

Skip this step if `CREATED_PERSONAS` is empty.

Present the created personas:

```
New persona(s) created during this run:
  - {Name1} (workforce/{slug1}.md)
  - {Name2} (workforce/{slug2}.md)

Contribute to gw-skills defaults? This creates a PR to share with all users.
  Contribute [y], skip [n]?
```

If the user selects `[y]`:

1. Save the current directory and branch
2. `cd $GW_REPO`
3. Check for uncommitted changes — if the working tree is dirty, ask: "gw-skills repo has uncommitted changes. Stash them? [y/n]" If yes, `git stash`. If no, abort contribution.
4. Create a branch:
   - Single persona: `persona/{slug}`
   - Multiple personas: `persona/batch-YYYY-MM-DD`
5. For each persona in `CREATED_PERSONAS`:
   - Copy `workforce/{slug}.md` → `workforce/_defaults/{slug}.md`
6. Stage and commit:
   ```bash
   git add workforce/_defaults/
   git commit -m "feat(workforce): add {Name} persona

   Background: {background}
   Created inline during gw:saas-idea run."
   ```
   (For multiple personas, list all names in the commit message.)
7. Push: `git push -u origin {branch}`
8. Create PR:
   ```bash
   gh pr create --title "Add {Name} persona to defaults" --body "$(cat <<'EOF'
   ## New Persona: {Name}

   **Background:** {background}
   **Skills used by:** gw:compete, gw:research, gw:review-app, gw:saas-idea
   **Created:** Inline during gw:saas-idea run on {date}

   Generated with [Claude Code](https://claude.com/claude-code)
   EOF
   )"
   ```
9. If stashed in step 3, `git stash pop`
10. Return to the original directory and branch
11. Print the PR URL

---

## Phase 5 — Build Execution (conditional)

**Skip this phase entirely unless ALL of the following are true:**
- BUILD_MODE is true
- SKIP_PLANNING is false
- `~/.claude/commands/gsd/` exists (GSD is installed)

If any condition is false, the skill ends after Step 5 (Present Results).

---

### Step 1 — Synthesize GSD Idea Document

Read `.saas-ideas/deep-dive/TECH-SPEC.md` and `.saas-ideas/deep-dive/BUSINESS-PLAN.md`. Write `.saas-ideas/deep-dive/GSD-IDEA-DOC.md` with the following structure:

```markdown
# GSD Idea Document: {Idea Name}

**Generated by:** /gw:saas-idea --build
**Date:** {today's date}
**Budget:** {BUDGET}

## Problem & Solution
{Extract problem statement and solution from BUSINESS-PLAN.md Sections 1-2. Keep concise — 1 paragraph each.}

## Mandatory Stack
- **Database:** PostgreSQL (Neon free tier)
- **Auth:** Google OAuth
- **Payments:** Stripe
- **Hosting:** AWS (Lambda + API Gateway)
- **Infrastructure:** Terraform
- **Domain:** {app-name}.codingandmore.net
- **CDN:** Cloudflare free tier
- **Cost target:** $0/month at <100 users

## MVP Scope
{Copy verbatim from TECH-SPEC.md Section 3 — v1 (MVP) features only}

## Data Model
{Copy verbatim from TECH-SPEC.md Section 4}

## Build Timeline
{Copy verbatim from TECH-SPEC.md Section 8 — week-by-week timeline}

## Superpowers Workflow (mandatory for every phase)
Apply these superpowers skills at each GSD phase:
1. `superpowers:brainstorming` — before design decisions
2. `superpowers:writing-plans` — before coding each phase
3. `superpowers:test-driven-development` — all implementation work
4. `superpowers:subagent-driven-development` — parallel independent tasks
5. `superpowers:systematic-debugging` — on any bug encounters
6. `superpowers:requesting-code-review` — after each milestone
7. `superpowers:verification-before-completion` — before merge/PR
8. `/gw:worktree create <name>` — for feature branches
```

---

### Step 2 — Launch GSD Auto-Chain

Invoke `/gsd:new-project --auto` and reference `@.saas-ideas/deep-dive/GSD-IDEA-DOC.md` as the project context document.

GSD's `--auto` chain handles the full lifecycle:
- Research → requirements → roadmap (auto-approved)
- For each phase: discuss → plan → execute (auto-advanced)
- Each phase naturally invokes superpowers through GSD's execution (TDD, code review, verification)

Print: "Launching GSD auto-chain for {Idea Name}. This will research, plan, and build the MVP automatically. Monitor progress with `/gsd:progress`."

---

### Step 3 — Post-Build Summary

After GSD auto-chain completes (or if the user checks back later), print:

```
Build Status: {Idea Name}
──────────────────────────
GSD Project: .planning/PROJECT.md
Phases: {N completed} / {N total}
Last Phase: {phase name} — {status}

Generated Files:
  .saas-ideas/deep-dive/GSD-IDEA-DOC.md   ({N} KB)
  .planning/PROJECT.md                      ({N} KB)
  .planning/ROADMAP.md                      ({N} KB)

Next Steps:
  - Check progress: /gsd:progress
  - Resume work: /gsd:resume-work
  - Verify completed phases: /gsd:verify-work
```

---

## Step 8.5 — Intent Commit & Auto-PR

Read and follow `$GW_REPO/.claude/commands/gw/_shared/intent-commit.md` to write and commit the `.gw-intent.md` file.

Then read and follow `$GW_REPO/.claude/commands/gw/_shared/auto-pr.md` to create a PR with the `agent_merge` label.

---

## Final — Session Summary

Print a summary of all files created during this session:

```
Session complete. Generated files:
  [new]   .saas-ideas/SHORTLIST.md
  [new]   .saas-ideas/CONSENSUS.md                (if debate ran)
  [new]   .saas-ideas/deep-dive/BUSINESS-PLAN.md
  [new]   .saas-ideas/deep-dive/MARKETING-PLAYBOOK.md
  [new]   .saas-ideas/deep-dive/TECH-SPEC.md
  [new]   .saas-ideas/deep-dive/IMPLEMENTATION-PROMPTS.md
  [new]   docs/gw/pitch-deck.pptx
  [new]   .saas-ideas/REPORT.md
  [new]   build-manifest.json                      (--skip-planning to skip)
  [skip]  <description of skipped output> (--skip-flag)
  ...

Total: N files created, N skipped
```

List each file that was created with `[new]` and each output that was skipped (due to --skip flags) with `[skip]`.
