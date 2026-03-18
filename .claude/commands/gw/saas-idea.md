---
name: saas-idea
description: Harvest trending SaaS opportunities from the internet, score and rank them, then deep-dive into the best idea with full business plan, marketing playbook, and implementation prompts
argument-hint: "[--focus <niche>] [--fresh] [--budget low|medium|high] [--pick <N>] [--skip-gsd]"
---

## Step 0 — Update check

Resolve the gw-skills repo directory and run its update check script:

```bash
GW_REPO="$(cd "$(readlink ~/.claude/commands/gw)/../../.." 2>/dev/null && pwd)" || GW_REPO="$HOME/.gw-skills"
bash "$GW_REPO/check-update.sh" 2>/dev/null || true
```

If the output contains `UPDATE_AVAILABLE`, tell the user how many commits behind they are and ask: "gw-skills has updates available. Run /gw:update to install them, or continue?" If they want to update, invoke `/gw:update` and stop. Otherwise continue. If the script is missing or fails, skip silently.

---

You are an orchestrator for SaaS idea discovery and validation. You harvest trending signals from the internet, score and rank SaaS opportunities, and generate comprehensive deep-dive deliverables for the best ideas. Follow these steps precisely.

Parse the arguments: "$ARGUMENTS"
- If "--focus <niche>" is present, set FOCUS=niche (string). Default: empty (no filter)
- If "--fresh" is present, set FORCE_FRESH=true. Default: false
- If "--budget <level>" is present, set BUDGET=level (one of: low, medium, high). Default: medium
- If "--pick <N>" is present, set PICK_ID=N (integer). Default: empty (interactive)
- If "--skip-gsd" is present, set SKIP_GSD=true. Default: false

### Budget semantics

The BUDGET flag modifies behavior in Phases 2-4:

| Budget | Team context | Feasibility bias | Tech spec scope | Revenue projections |
|--------|-------------|-------------------|-----------------|---------------------|
| `low` | Solo dev with AI tooling | Strongly favor ideas one person can ship in 2-4 weeks | Minimal infra, free-tier services only | Conservative, bootstrapped |
| `medium` | 2-5 person team with AI tooling | Favor ideas shippable in 4-8 weeks | Moderate infra, paid services OK | Moderate, some paid acquisition budget |
| `high` | Funded team (5-15) | Larger scope OK, 8-16 week MVPs acceptable | Full infra, enterprise services | Aggressive, investor-backed growth |

---

## Step 1 — Pre-flight

### 1a. Check for existing data

Check if `.saas-ideas/` directory exists. If it does and `--pick` was NOT set and `--fresh` was NOT set:
- Check which files exist: `REPORT.md`, `SHORTLIST.md`
- Build the prompt dynamically based on what exists:
  - Always offer: "Harvest fresh data"
  - If `SHORTLIST.md` exists: also offer "Re-use existing shortlist"
  - If `REPORT.md` exists: also offer "View existing REPORT.md"
- Handle each choice:
  - If they choose to view (and `REPORT.md` exists): read and present `.saas-ideas/REPORT.md` and stop.
  - If they choose to re-use (and `SHORTLIST.md` exists): skip to interactive selection on existing `SHORTLIST.md` (skip Phase 1 and Phase 2).
  - If they choose fresh: continue to Phase 1.

### 1b. Initialize history

If `history.json` does not exist in `.saas-ideas/`, create it with `{"runs": []}` and treat all ideas as new.

### 1c. Handle --pick

If PICK_ID is set:
- Read `.saas-ideas/SHORTLIST.md`. If it does not exist, tell the user "No previous run found. Run `/gw:saas-idea` first without `--pick`." and stop.
- Validate PICK_ID is between 1 and 10. If out of range, tell the user and stop.
- Check `history.json` for the most recent run date. If older than 7 days, warn: "Previous shortlist is {N} days old. Results may be stale. Continue anyway? [y/n]"
- If the user continues, skip to Phase 3 with the selected idea.

### 1d. Freshness check

If FORCE_FRESH is false and `.saas-ideas/SHORTLIST.md` exists and is less than 24 hours old:
- Ask user: "A recent shortlist exists (generated {time}). Re-use it and pick an idea, or harvest fresh data?"
- If re-use: skip Phase 1 and Phase 2, go straight to interactive selection on existing `SHORTLIST.md`.
- If fresh: continue to Phase 1.

Otherwise, continue to Phase 1.

### 1e. Create working directories

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

Launch ALL 6 agents in a SINGLE message using the Agent tool. Each call must set `run_in_background=true`. Do not wait for one agent to finish before launching the next — they all run in parallel.

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
   - If fewer than 3 succeeded: tell the user which agents failed and why (file missing vs. zero signals). Offer to retry only the failed agents. Do not proceed until threshold is met.
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
| Feasibility | 20% | Can a team at the {BUDGET} level MVP this in the expected timeframe? AI is a force multiplier — a solo dev with Claude Code can ship what used to need 5 people. Reward ideas suited to AI-accelerated development. Budget semantics: low = 2-4 weeks solo dev, medium = 4-8 weeks small team, high = 8-16 weeks funded team. |
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

### Interactive selection

After the synthesis agent completes:

1. Read `.saas-ideas/SHORTLIST.md`
2. Print the top 10 as a numbered summary list:
   ```
   SaaS Idea Shortlist — Top 10
   ─────────────────────────────
    1. {Idea Name}  (Score: X.X/10) — {one-liner}
    2. {Idea Name}  (Score: X.X/10) — {one-liner}
    3. ...
   ```
3. Ask the user: **"Which idea do you want to deep-dive into? Enter a number (1-10)."**
4. Once the user selects a number, store the full entry for that idea as `SELECTED_IDEA` with all fields:
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
Calibrate to BUDGET tier:
- low: $0-500/month — focus on organic, maybe small Google Ads experiment
- medium: $500-3000/month — Google Ads + one social channel
- high: $3000-15000/month — multi-channel paid strategy

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
- **Database:** PostgreSQL (use managed service appropriate to BUDGET — RDS for medium/high, Supabase or Neon free tier for low)
- **Auth:** Google OAuth (via next-auth, passport-google-oauth20, or equivalent)
- **Payments:** Stripe (Checkout, Billing, or Payment Intents as appropriate)
- **Hosting:** AWS (ECS/Fargate for medium/high, Amplify or Lightsail for low)
- **Infrastructure as Code:** Terraform (all infra must be codified)
- **Domain:** Deploy as subdomain under `codingandmore.net` (e.g., `{app-name}.codingandmore.net`)

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

Calibrate non-mandatory services to BUDGET:
- low: free-tier services only, minimize vendor count
- medium: paid tiers OK where they save significant time
- high: best-in-class services, optimize for team velocity

## 6. Infrastructure (AWS + Terraform)

All infrastructure MUST be defined in Terraform. Provide Terraform module structure.

- **AWS deployment architecture:** describe the specific AWS services used (ECS/Fargate, RDS PostgreSQL, S3, CloudFront, Route53, ACM, etc.)
- **Domain:** configure as `{app-name}.codingandmore.net` via Route53 + ACM certificate
- **Terraform module layout:** list the `.tf` files and what each defines
- **CI/CD pipeline:** GitHub Actions → build → test → deploy to AWS
- **Environment strategy:** local (Docker Compose), staging (`staging.{app-name}.codingandmore.net`), production (`{app-name}.codingandmore.net`)
- Estimated monthly infrastructure cost at scale:

| Users | Compute | Database | Storage | Services | Total/month |
|-------|---------|----------|---------|----------|-------------|
| 0 (dev) | ... | ... | ... | ... | ... |
| 100 | ... | ... | ... | ... | ... |
| 1,000 | ... | ... | ... | ... | ... |
| 10,000 | ... | ... | ... | ... | ... |

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
- Use `superpowers:using-git-worktrees` for feature branches
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
| Feature branches | `superpowers:using-git-worktrees` |
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

Launch ALL 4 agents in a SINGLE message using the Agent tool. Each call must set `run_in_background=true`. Do not wait for one agent to finish before launching the next — they all run in parallel.

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
   - **CRITICAL agents** (Business Plan, Tech Spec): if either fails, offer to retry before proceeding to Phase 4. These are essential for the downstream deliverables.
   - **Non-critical agents** (Marketing Playbook, Implementation Prompts): if either fails, note the failure and continue to Phase 4. The user can regenerate these later.

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

Generate a complete Python script that uses `python-pptx` to create a 10-slide investor pitch deck saved to `.saas-ideas/deep-dive/pitch-deck.pptx`.

**Design system:**
- Colors: Dark blue `#1B2A4A` for headers, white `#FFFFFF` for body text, accent blue `#3B82F6` for highlights and emphasis, light gray `#F1F5F9` for alternating rows and backgrounds
- Fonts: Calibri for body text, Calibri Bold for headings
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
- Write the output file to `.saas-ideas/deep-dive/pitch-deck.pptx`
- Print the absolute path of the generated file on success

Write the script to `/tmp/saas_pitch_deck_gen.py`, then execute it.

**Execution chain:**

1. Try:
   ```bash
   uv run --with python-pptx python3 /tmp/saas_pitch_deck_gen.py
   ```

2. If `uv` is not available or fails, fall back to:
   ```bash
   pip install python-pptx && python3 /tmp/saas_pitch_deck_gen.py
   ```

3. If both fail, generate an HTML file at `.saas-ideas/deep-dive/pitch-deck.html` instead with the same 10-slide content as a styled HTML presentation. Note the limitation to the user: 'Generated HTML pitch deck as fallback — python-pptx was not available.'

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
| deep-dive/pitch-deck.pptx | Investor/co-founder pitch deck |

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

### Step 4 — GSD Integration (orchestrator)

Skip this step if SKIP_GSD is true.

Check if `~/.claude/commands/gsd/` exists. If it does:

1. Check if `.planning/PROJECT.md` exists (i.e., GSD project already initialized).
   - **If yes (brownfield/existing project):** Automatically invoke `/gsd:new-milestone` and reference `.saas-ideas/deep-dive/TECH-SPEC.md` as the requirements source. Tell the user you are creating a new GSD milestone from the tech spec phases. Include project context: "This project was generated by /gw:saas-idea. Superpowers workflow: brainstorm → plan → TDD → review → verify for each phase."
   - **If no (greenfield):** Automatically invoke `/gsd:new-project` and reference `.saas-ideas/deep-dive/TECH-SPEC.md` as the requirements source. Tell the user you are creating a GSD project from the tech spec. Include project context: "This project was generated by /gw:saas-idea. Superpowers workflow: brainstorm → plan → TDD → review → verify for each phase."

If GSD commands don't exist, say: "Full plan available in `.saas-ideas/`. Install GSD to auto-scaffold the project." and stop.

**Prototype generation goal:** The GSD project/milestone should target generating a **complete working prototype** — not just plans. The implementation prompts and GSD phases should aim to produce deployable code with:
- Working auth (Google OAuth)
- Working payments (Stripe integration)
- Core feature functionality
- PostgreSQL database with migrations
- Terraform configs for AWS deployment
- Deployed to `{app-name}.codingandmore.net`

Tell the user: "GSD will scaffold a project targeting a fully deployable prototype at `{app-name}.codingandmore.net`."

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
     .saas-ideas/deep-dive/pitch-deck.pptx        ({N} KB)
   ```

3. Print: "Pitch deck saved to `.saas-ideas/deep-dive/pitch-deck.pptx`"

4. If GSD was invoked in Step 4, note whether a project or milestone was created and where to find it.

5. If any Phase 3 agents failed (non-critical), remind the user which files are missing and that they can re-run the skill with the same arguments to regenerate them.
