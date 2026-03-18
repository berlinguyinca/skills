# gw:saas-idea Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create the `/gw:saas-idea` skill file that orchestrates internet trend harvesting, SaaS idea scoring, and full deep-dive generation with business plan, marketing playbook, tech spec, implementation prompts, and pitch deck.

**Architecture:** Single skill file (`.claude/commands/gw/saas-idea.md`) containing orchestrator instructions that spawn parallel harvest agents, a synthesis agent, parallel deep-dive agents, and a pitch deck agent. Follows the same patterns as `analyze-app.md` and `weekly-review.md`.

**Tech Stack:** Claude Code skill markdown, Agent tool, WebSearch/WebFetch, python-pptx for pitch deck generation.

**Spec:** `docs/superpowers/specs/2026-03-17-saas-idea-generator-design.md`

**Reference files:**
- `.claude/commands/gw/analyze-app.md` — parallel agent pattern, error handling, GSD integration
- `.claude/commands/gw/weekly-review.md` — PowerPoint generation pattern, design system
- `.claude/commands/gw/merge-it.md` — argument parsing pattern
- `.claude/commands/gw/update.md` — Step 0 update check pattern

---

## File Structure

| Action | File | Responsibility |
|--------|------|---------------|
| Create | `.claude/commands/gw/saas-idea.md` | The skill file — all orchestrator instructions |
| Modify | `README.md` | Add skill to the Available Skills table and reference section |

This is a single-file implementation. The skill file is a markdown document containing instructions for Claude Code to follow when the user invokes `/gw:saas-idea`. All "code" is prompt engineering within this markdown file.

---

### Task 1: Skill file skeleton — frontmatter, Step 0, argument parsing, pre-flight

**Files:**
- Create: `.claude/commands/gw/saas-idea.md`

- [ ] **Step 1: Create the skill file with YAML frontmatter**

Write the file with frontmatter matching the spec:

```yaml
---
name: saas-idea
description: Harvest trending SaaS opportunities from the internet, score and rank them, then deep-dive into the best idea with full business plan, marketing playbook, and implementation prompts
argument-hint: "[--focus <niche>] [--fresh] [--budget low|medium|high] [--pick <N>] [--skip-gsd]"
---
```

- [ ] **Step 2: Add Step 0 — Update check**

Copy the update check boilerplate verbatim from `analyze-app.md` lines 7-17. This is identical across all `gw:` skills.

- [ ] **Step 3: Add introductory paragraph and argument parsing**

After the `---` separator, add:
- One-sentence role description: "You are an orchestrator for SaaS idea discovery and validation..."
- `Parse the arguments: "$ARGUMENTS"` block with all 5 flags (FOCUS, FORCE_FRESH, BUDGET, PICK_ID, SKIP_GSD) and their defaults
- Budget semantics table (low/medium/high → team context, feasibility bias, tech spec scope, revenue projections)

- [ ] **Step 4: Add pre-flight / freshness check logic**

Write the Step 1 section with:
- `history.json` initialization: if not exists, create with `{"runs": []}`
- `--pick N` handling: validate SHORTLIST.md exists, validate N is 1-10, check staleness (>7 days warning). **If PICK_ID is set and valid, extract the selected idea from SHORTLIST.md and skip directly to Phase 3** — do not run Phase 1 or Phase 2.
- Freshness check: if SHORTLIST.md <24h old and not `--fresh`, offer re-use
- `mkdir -p .saas-ideas/harvest .saas-ideas/deep-dive`

- [ ] **Step 5: Verify and commit**

Read the file back, verify frontmatter parses correctly, verify all flags are handled.

```bash
git add .claude/commands/gw/saas-idea.md
git commit -m "feat(saas-idea): add skill skeleton — frontmatter, update check, arg parsing, pre-flight"
```

---

### Task 2: Phase 1 — Parallel harvest agent prompts

**Files:**
- Modify: `.claude/commands/gw/saas-idea.md`

- [ ] **Step 1: Add the Phase 1 section header and source access strategy table**

Write the `## Phase 1 — Parallel Harvest` section with the source access strategy table from the spec (lines 118-131). This tells each agent which tool (WebSearch vs WebFetch) to use for each source and why.

- [ ] **Step 2: Add focus filter propagation instructions**

Write the focus filter block: when FOCUS is set, inject domain focus into each agent prompt. When empty, search broadly.

- [ ] **Step 3: Write the HN + IndieHackers agent prompt**

Full agent prompt including:
- Role: "You are a trend researcher analyzing Hacker News and IndieHackers..."
- Source access instructions: WebFetch for HN URLs, WebSearch for IndieHackers
- Focus filter injection point
- Freshness filter: list of previous ideas to skip
- Output format: write to `.saas-ideas/harvest/01-hackernews-indiehackers.md`
- Signal format template (from spec lines 154-169)

- [ ] **Step 4: Write the Product Hunt agent prompt**

Same structure as Step 3, adapted for Product Hunt:
- WebSearch with `site:producthunt.com` queries
- Focus on new launches, trending products, category patterns
- Output: `.saas-ideas/harvest/02-producthunt.md`

- [ ] **Step 5: Write the Reddit agent prompt**

- WebFetch on `old.reddit.com/r/{subreddit}/top/?t=week` for r/SaaS, r/startups, r/Entrepreneur, r/microSaaS, r/IndieBiz
- Fallback to WebSearch with `site:reddit.com`
- Focus on complaints, "I wish X existed", willingness to pay
- Output: `.saas-ideas/harvest/03-reddit.md`

- [ ] **Step 6: Write the Twitter/X + Social agent prompt**

- WebSearch only — do NOT WebFetch twitter.com (requires auth)
- Search queries: "trending SaaS twitter {year}", "tech twitter discussion {topic}"
- Focus on buzz topics, emerging tools, market gaps
- Output: `.saas-ideas/harvest/04-twitter.md`

- [ ] **Step 7: Write the Google Trends + SEO agent prompt**

- WebSearch only — do NOT WebFetch trends.google.com (JS-rendered)
- Search queries: `"google trends" rising searches {category}`, `"trending searches" {niche}`
- Focus on search demand signals, growing niches, seasonal patterns
- Output: `.saas-ideas/harvest/05-google-trends.md`

- [ ] **Step 8: Write the GitHub + Tech News agent prompt**

- WebFetch for `github.com/trending` and `github.com/trending?since=weekly`
- WebSearch + WebFetch for TechCrunch, The Verge, Ars Technica articles
- Focus on OSS tools (= SaaS wrapper opportunities), funding, industry shifts
- Output: `.saas-ideas/harvest/06-github-technews.md`

- [ ] **Step 9: Add the launch instruction block**

Write the orchestrator instruction to launch all 6 agents in a single message with `run_in_background=true`, using the Agent tool with `subagent_type="general-purpose"`.

- [ ] **Step 10: Add error handling and validation**

After all agents complete:
- Check each `.saas-ideas/harvest/*.md` exists and has `### ` signal headings
- Print status table: `[done]` or `[FAILED]` per agent
- Enforce ≥3/6 threshold. If <3: tell user, offer retry of failed agents only.
- If ≥3: continue, noting failures in synthesis prompt.

- [ ] **Step 11: Commit**

```bash
git add .claude/commands/gw/saas-idea.md
git commit -m "feat(saas-idea): add Phase 1 — parallel harvest agent prompts for 6 source clusters"
```

---

### Task 3: Phase 2 — Synthesis and scoring agent prompt

**Files:**
- Modify: `.claude/commands/gw/saas-idea.md`

- [ ] **Step 1: Add Phase 2 section header**

Write `## Phase 2 — Synthesis & Scoring` with the intro paragraph explaining this is a foreground synthesis agent.

- [ ] **Step 2: Write the synthesis agent prompt**

Full agent prompt including:
- Role: "You are a SaaS strategist synthesizing market research signals into actionable business ideas..."
- Instructions to read all `.saas-ideas/harvest/*.md` files
- Receive BUDGET and FOCUS parameters
- Receive list of failed sources (from Phase 1 error check) so scoring accounts for incomplete coverage
- Step-by-step process:
  1. Cluster signals into 15-25 raw SaaS concepts
  2. Deduplicate against `history.json` `ideas_surfaced` arrays (case-insensitive match)
  3. Score on balanced scorecard (5 dimensions with weights from spec)
  4. Rank top 10
- BUDGET-aware feasibility scoring (reference budget semantics table)
- AI force multiplier note in feasibility dimension
- Output format: write `.saas-ideas/SHORTLIST.md` using the exact template from spec

- [ ] **Step 3: Add the interactive selection prompt**

After synthesis agent completes:
- Read `SHORTLIST.md`
- Print top 10 as a numbered list with scores and one-liners
- Ask: "Which idea do you want to deep-dive into? Enter a number (1-10)."
- Store the selected idea details for Phase 3

- [ ] **Step 4: Commit**

```bash
git add .claude/commands/gw/saas-idea.md
git commit -m "feat(saas-idea): add Phase 2 — synthesis agent with balanced scorecard scoring"
```

---

### Task 4: Phase 3 — Parallel deep-dive agent prompts

**Files:**
- Modify: `.claude/commands/gw/saas-idea.md`

- [ ] **Step 1: Add Phase 3 section header**

Write `## Phase 3 — Parallel Deep-Dive` with intro: four background agents launched in one message.

- [ ] **Step 2: Write the Business Plan agent prompt**

Full prompt including:
- Role: "You are a business strategist creating a comprehensive business plan for a SaaS product..."
- Receives: selected idea entry from SHORTLIST.md, BUDGET parameter
- All 10 sections from spec (problem, solution, audience, market size, competition, business model, revenue projections, metrics, risk, moat)
- Revenue projections calibrated to BUDGET level
- Use WebSearch to research competitors and market size
- Output: write to `.saas-ideas/deep-dive/BUSINESS-PLAN.md`

- [ ] **Step 3: Write the Marketing Playbook agent prompt**

Full prompt including:
- Role: "You are a growth marketing strategist creating a go-to-market playbook..."
- All 10 sections from spec (positioning, landing page, SEO, content calendar, launch, emails, social, partnerships, paid, community)
- Paid acquisition budget scaled to BUDGET level
- Use WebSearch to research keywords and competitor marketing
- Output: write to `.saas-ideas/deep-dive/MARKETING-PLAYBOOK.md`

- [ ] **Step 4: Write the Tech Spec agent prompt**

Full prompt including:
- Role: "You are a technical architect designing the MVP for a SaaS product..."
- All 8 sections from spec (stack, architecture, MVP scope, data model, services, infra, AI leverage, timeline)
- Stack and infra recommendations calibrated to BUDGET (free-tier for low, paid OK for medium/high)
- Timeline calibrated to BUDGET team size with AI tooling
- Output: write to `.saas-ideas/deep-dive/TECH-SPEC.md`

- [ ] **Step 5: Write the Implementation Prompts agent prompt**

Full prompt including:
- Role: "You are an AI workflow designer creating ready-to-paste prompts for Claude Code..."
- All 5 prompt categories from spec (project init, phase-by-phase, marketing execution, testing, launch checklist)
- Each prompt must be self-contained with full context
- Superpowers skill references table embedded in each phase prompt as instructional text
- GSD `/gsd:new-project` initialization prompt
- Output: write to `.saas-ideas/deep-dive/IMPLEMENTATION-PROMPTS.md`

- [ ] **Step 6: Add the launch instruction block**

Orchestrator launches all 4 agents in a single message with `run_in_background=true`.

- [ ] **Step 7: Add completion check**

After all agents complete:
- Verify all 4 `.saas-ideas/deep-dive/*.md` files exist and have content
- Print status table
- If a critical agent (Business Plan or Tech Spec) fails, offer to retry that agent before proceeding to Phase 4, since the pitch deck and GSD integration depend on their output
- If a non-critical agent (Marketing or Prompts) fails, note it and continue with available files

- [ ] **Step 8: Commit**

```bash
git add .claude/commands/gw/saas-idea.md
git commit -m "feat(saas-idea): add Phase 3 — parallel deep-dive agents (business, marketing, tech, prompts)"
```

---

### Task 5: Phase 4 — Pitch deck, report, history, GSD integration

**Files:**
- Modify: `.claude/commands/gw/saas-idea.md`

- [ ] **Step 1: Add Phase 4 section header**

Write `## Phase 4 — Final Assembly` with note: "Phase 4 is orchestrator-driven. Only Step 1 uses a subagent."

- [ ] **Step 2: Write the Pitch Deck agent prompt**

Foreground agent prompt including:
- Role: "You are a presentation designer creating a pitch deck..."
- Read all 4 deep-dive files
- Generate Python script using python-pptx
- Execution chain: `uv run --with python-pptx` → `pip install python-pptx` → HTML fallback
- Design system: dark blue (#1B2A4A) headers, white body, accent blue (#3B82F6), Calibri fonts
- All 10 slides from spec with content mapping
- Output: `.saas-ideas/deep-dive/pitch-deck.pptx`

Reference the `weekly-review.md` Python rendering pattern (lines ~650-849) for the exact execution approach.

- [ ] **Step 3: Write Step 2 — Executive Report**

Orchestrator instructions to write `.saas-ideas/REPORT.md` using the exact template from spec (lines 351-377). Include BUDGET and FOCUS in the header.

- [ ] **Step 4: Write Step 3 — Update History**

Orchestrator instructions to:
- Read `history.json`
- Append new run entry with date, ideas_surfaced (all 10), selected, focus, budget, score
- Write back to `history.json`

- [ ] **Step 5: Write Step 4 — GSD Integration**

Orchestrator instructions matching the spec (lines 394-404):
- Skip if SKIP_GSD is true
- Check for `~/.claude/commands/gsd/`
- Branch on `.planning/PROJECT.md` existence
- Include superpowers workflow note in project context

- [ ] **Step 6: Write Step 5 — Present Results**

Orchestrator prints:
- Executive Summary from REPORT.md
- File listing with sizes
- Pitch deck path
- GSD status if applicable

- [ ] **Step 7: Commit**

```bash
git add .claude/commands/gw/saas-idea.md
git commit -m "feat(saas-idea): add Phase 4 — pitch deck, report, history tracking, GSD integration"
```

---

### Task 6: Update README.md

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Add to Available Skills table**

Add a new row to the table at line ~20:

```markdown
| `/gw:saas-idea` | Harvest trending SaaS opportunities from the internet, score and rank them, then deep-dive with full business plan, marketing playbook, tech spec, implementation prompts, and pitch deck. |
```

- [ ] **Step 2: Add Skill Reference section**

Add a new `### /gw:saas-idea` section after the `/gw:analyze-app` reference (around line 112) with:
- Usage syntax
- Description paragraph
- Flags table (all 5 flags with descriptions and defaults)
- Output files description
- Example usage patterns (ad-hoc, focused, re-pick, fresh)

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: add gw:saas-idea to README — skill reference and usage examples"
```

---

### Task 7: End-to-end smoke test

**Files:**
- No file changes — verification only

- [ ] **Step 1: Verify skill file is accessible**

```bash
ls -la ~/.claude/commands/gw/saas-idea.md
```

Since `~/.claude/commands/gw/` is a symlink to the repo's `.claude/commands/gw/`, the new file should be accessible automatically.

- [ ] **Step 2: Verify skill file structure**

Read the complete skill file and verify:
- YAML frontmatter parses correctly (name, description, argument-hint)
- Step 0 update check is present
- All 5 argument flags are parsed
- Budget semantics table is present
- Pre-flight freshness logic is complete
- Phase 1 has all 6 agent prompts with correct output paths
- Phase 1 has error handling with ≥3/6 threshold
- Phase 2 has synthesis prompt with scoring dimensions and weights
- Phase 2 has interactive selection
- Phase 3 has all 4 deep-dive agent prompts
- Phase 4 has pitch deck, report, history, GSD, and presentation steps
- All file paths are consistent across phases

- [ ] **Step 3: Verify README is consistent**

Read README.md and verify the new skill entry matches the skill file's frontmatter and capabilities.

- [ ] **Step 4: Run a dry test**

Invoke `/gw:saas-idea --focus devtools` to verify:
- Update check runs (or skips gracefully)
- Arguments parse correctly
- Pre-flight creates `.saas-ideas/` directory structure
- Harvest agents launch and produce output files
- Synthesis produces SHORTLIST.md

Note: This is a live test that will make real web requests. Stop after verifying the shortlist is produced correctly. Do not proceed to deep-dive unless the user wants to.
