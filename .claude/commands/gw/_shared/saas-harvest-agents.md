# SaaS Harvest Agent Prompts

6 parallel harvest agents for Phase 1 of gw:saas-idea.

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
