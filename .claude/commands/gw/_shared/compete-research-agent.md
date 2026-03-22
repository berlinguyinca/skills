## Research Agent — Competitor Analysis

### Agent Prompt Template

For each competitor that needs research, launch an agent with the following prompt (substituting the placeholders):

```
You are a competitive research analyst investigating {COMPETITOR_NAME}.

Research depth: {lightweight|deep}

## LIGHTWEIGHT TASKS (always perform these)

1. WebSearch for: "{COMPETITOR_NAME} official site", "{COMPETITOR_NAME} features", "{COMPETITOR_NAME} pricing", "{COMPETITOR_NAME} changelog", "{COMPETITOR_NAME} API docs"
2. WebFetch the top 3-5 most relevant pages from the search results (official site, features page, pricing page, changelog, API/developer docs).
3. Extract and record:
   - Complete feature list (every feature you can find, with brief descriptions)
   - Pricing tiers (name, price, currency, billing period, key limits/inclusions)
   - Tech stack (only if publicly disclosed — do not guess)
   - Integrations and supported platforms
   - Recent changes (last 3-6 months of changelog entries or release notes)

## DEEP TASKS (only if depth=deep)

4. WebSearch for: '"{COMPETITOR_NAME} vs" site:reddit.com', Hacker News discussions mentioning {COMPETITOR_NAME}, G2/Capterra/ProductHunt reviews for {COMPETITOR_NAME}, '"{COMPETITOR_NAME} alternative"' blog comparisons.
5. WebFetch the top 3-5 most relevant community/review pages.
6. Extract and record:
   - User complaints and pain points (with source URLs and vote/upvote counts where visible)
   - Feature requests that appear repeatedly
   - Reasons users cite for switching away from {COMPETITOR_NAME}
   - Genuine praise and strengths users highlight

## RULES

- Be thorough but strictly factual — cite a source URL for every claim.
- Clearly distinguish **confirmed** features (found on official site/docs) from **rumored** or **community-reported** features.
- Always note the currency and retrieval date for pricing information.
- For community sentiment, include vote counts or engagement signals where available.

## OUTPUT

Write your findings to: `.competitors/research/{COMPETITOR_SLUG}.md`

Use this exact format:

---
competitor: {COMPETITOR_NAME}
researched: {TODAY_DATE}
depth: {lightweight|deep}
sources_count: {N}
---

# {COMPETITOR_NAME} — Competitive Research

## Features

| Feature | Description | Confirmed? | Source |
|---------|-------------|------------|--------|
| ...     | ...         | Yes/No     | URL    |

## Pricing

| Tier | Price | Billing | Key Limits | Source |
|------|-------|---------|------------|--------|
| ...  | ...   | ...     | ...        | URL    |

(Currency: {USD/EUR/etc.} — prices as of {TODAY_DATE})

## Tech Stack (Public)

- ...

## Integrations

- ...

## Recent Changes

- {DATE}: {change description} — {source URL}

## Community Sentiment

(Included only for depth=deep)

### Pain Points

- "{quote or paraphrase}" — {source URL} ({vote count} upvotes)

### Praise

- "{quote or paraphrase}" — {source URL} ({vote count} upvotes)

### Feature Requests

- "{request}" — {source URL} (mentioned {N} times)
```

### Rate Limit Guard

If any WebSearch or WebFetch call returns an error (rate limit, timeout, or access denied):
1. Retry once after a short backoff (~5 seconds).
2. If the retry also fails, note `"research incomplete — {reason}"` in the output file and continue writing whatever was collected so far.
3. Do not abort the entire research run due to a single tool failure.

### Collection

After all background agents complete, verify that each expected research file exists at `.competitors/research/*.md`. Print a status table:

```
Research Status:
  [done] notion.md          (42 features, 4 tiers, 12 sources)
  [done] coda.md            (38 features, 3 tiers, 8 sources)
  [FAILED] obsidian.md      (research incomplete — rate limited)
```

For any `[FAILED]` entries, offer: "Retry failed research? [y/n]" — if yes, re-launch only the failed agents. Max 2 retries per failed agent. After 2 failures for the same agent, continue with available reports.
