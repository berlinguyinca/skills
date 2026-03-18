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
