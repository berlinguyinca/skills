---
name: saas-idea
description: Harvest trending SaaS opportunities from the internet, score and rank them, then deep-dive into the best idea with full business plan, marketing playbook, and implementation prompts. Use when the user wants to find SaaS ideas, explore business opportunities, validate startup concepts, or generate a business plan.
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

- If `--build` AND (`--skip-planning` or `--skip-gsd`) are both present: warn "Warning: --build requires a planning tool but --skip-planning was set. Disabling build mode." Set BUILD_MODE=false, keep SKIP_PLANNING=true.
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
| Hacker News | `WebFetch` | Fetch HN front page, Show HN, Ask HN directly — plain HTML |
| IndieHackers | `WebSearch` | Search `site:indiehackers.com` + relevant keywords |
| Product Hunt | `WebSearch` | Search `site:producthunt.com` + "launched today/this week" — JS-heavy |
| Reddit | `WebFetch` | Fetch `old.reddit.com/r/{sub}/top/?t=week`. Fallback: `WebSearch` |
| Twitter/X | `WebSearch` | Do NOT `WebFetch` twitter.com — requires auth |
| Google Trends | `WebSearch` | Do NOT `WebFetch` trends.google.com — JS-rendered |
| GitHub Trending | `WebFetch` | Fetch `github.com/trending` — plain HTML |
| TechCrunch/Verge/Ars | `WebSearch` + `WebFetch` | Search then fetch top results |

### Focus filter propagation

When FOCUS is set, inject into every agent prompt as `{FOCUS_BLOCK}`:
> Focus your research on the **{FOCUS}** domain. Only surface signals directly relevant to {FOCUS}. Ignore signals from unrelated domains.

When FOCUS is empty, set `{FOCUS_BLOCK}` to an empty string.

### Building PREVIOUS_IDEAS

Read `history.json` and collect all idea titles from previous runs. Format as a bullet list and inject as `{PREVIOUS_IDEAS}`. If no previous runs, set to "None — this is the first run."

### Harvest agent prompts

Read and follow `$GW_REPO/.claude/commands/gw/_shared/saas-harvest-agents.md` for the 6 parallel harvest agent prompt templates.

### Launch all harvest agents

Apply `superpowers:dispatching-parallel-agents` pattern — Launch ALL 6 agents in a SINGLE message. Each call must set `run_in_background=true`. Wait for ALL 6 to finish before proceeding.

### Harvest validation

After all agents complete:

1. Check each expected file exists and has at least one `### ` signal heading in `.saas-ideas/harvest/`.
2. Print a status table showing each file, status ([done]/[FAILED]), and signal count.
3. At least 3 out of 6 agents must succeed. If fewer: retry failed agents (max 2 retries each). If 3+ succeeded: continue to Phase 2, noting failures for the synthesizer.

---

## Phase 2 — Synthesis & Scoring

Launch a single foreground Agent to synthesize harvest data into a ranked shortlist. Pass BUDGET, FOCUS, and FAILED_SOURCES into the agent prompt.

Read and follow `$GW_REPO/.claude/commands/gw/_shared/saas-scoring.md` for the synthesis agent prompt, balanced scorecard methodology, and SHORTLIST.md output format.

---

## Phase 2.5 — Idea Debate

Skip this phase if `SKIP_DEBATE=true` OR `AUTO_SELECT=true`.

### 2.5a. Team Assembly

**Team suggestion table for this skill:**

| CONTEXT | Suggested Team |
|---------|---------------|
| saas-idea | Business Analyst, Financial Analyst, Product Manager, Devil's Advocate, Software Architect |

Context line for approval gate: `SaaS Idea: {IDEA_NAME}`

Read and follow `$GW_REPO/.claude/commands/gw/_shared/team-assembly.md` using the table above for team suggestions.

### 2.5b. Debate Rounds

Read and follow `$GW_REPO/.claude/commands/gw/_shared/saas-debate.md` for the Round 1 (Position Statements), Round 2 (Cross-Examination), and Round 3 (Supervisor Synthesis) templates.

### Idea selection

After the synthesis agent completes:

1. Read `.saas-ideas/SHORTLIST.md`

**If AUTO_SELECT is true (or PICK_ID is set):**

2. Determine selection: use PICK_ID if set, otherwise default to #1.
3. Print: `"Auto-selected #{N}: {Idea Name} (Score: X.X/10) — {one-liner}"`
4. Store the full entry as `SELECTED_IDEA`. Proceed directly to Phase 3.

**If AUTO_SELECT is false:**

2. Present the top 10 with scores, then a top 3 trade-off analysis with strengths, risks, and best-for.
3. Ask: **"Which idea do you want to deep-dive into? Enter a number (1-10), or press Enter for the recommendation."**

**In both cases**, store `SELECTED_IDEA` with: name, one_liner, category, signals, scores, ranking_rationale, key_risk. This context is passed to Phase 3.

---

## Phase 3 — Parallel Deep-Dive

Read and follow `$GW_REPO/.claude/commands/gw/_shared/saas-deep-dive-agents.md` for the 4 parallel deep-dive agent prompt templates.

### Launch all deep-dive agents

Apply `superpowers:dispatching-parallel-agents` pattern — Launch ALL 4 agents in a SINGLE message. Each call must set `run_in_background=true`. Wait for ALL 4 to finish.

### Deep-dive validation

1. Check each expected file exists with >20 lines: BUSINESS-PLAN.md, MARKETING-PLAYBOOK.md, TECH-SPEC.md, IMPLEMENTATION-PROMPTS.md.
2. Print a status table with line counts.
3. **CRITICAL agents** (Business Plan, Tech Spec): retry on failure (max 2). If both fail after retries, stop.
   **Non-critical agents** (Marketing Playbook, Implementation Prompts): note failure, continue.

---

## Phase 3.5 — Coherence Verification (conditional)

**Skip if VERIFY_MODE is false.**

Read and follow `$GW_REPO/.claude/commands/gw/_shared/saas-verification.md` for the verification agent prompt.

After the verification agent completes:

1. Read `.saas-ideas/deep-dive/VERIFICATION.md` and print the results table.
2. **If BUILD_MODE is true and any check is FAIL:** Ask "Verification found issues. Continue to build anyway? [y/n]".
3. **If all checks PASS or BUILD_MODE is false:** Continue to Phase 4.

---

## Phase 4 — Final Assembly

Phase 4 is orchestrator-driven. Only Step 1 uses a subagent.

### Step 1 — Pitch Deck (foreground subagent)

Read and follow `$GW_REPO/.claude/commands/gw/_shared/saas-pitch-deck.md` for the 10-slide pitch deck structure and Python generation instructions.

### Step 2 — Executive Report (orchestrator writes directly)

Read all deep-dive files and SHORTLIST.md. Write `.saas-ideas/REPORT.md`:

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

### Step 3 — Update History (orchestrator writes directly)

Read `.saas-ideas/history.json` (create if missing). Append a new entry to `runs`:

```json
{
  "date": "YYYY-MM-DD",
  "ideas_surfaced": ["...all 10 from shortlist..."],
  "selected": "Selected Idea Name",
  "focus": "FOCUS value or null",
  "budget": "BUDGET value",
  "score": 8.4
}
```

Do NOT overwrite previous entries — the `runs` array accumulates.

### Step 4 — Implementation Bridge (orchestrator)

Skip if SKIP_PLANNING is true.

#### 4a. Generate project files

**If BUILD_MODE is true:** Auto-generate CLAUDE.md and SPEC.md silently, then continue to 4c.

**If BUILD_MODE is false:** Ask:
```
Generate project files for implementation?
  - CLAUDE.md — project context, tech stack, constraints
  - SPEC.md  — requirements, user flows, data model, success criteria
Generate and choose workflow [y], go straight to planning [g], or skip [n]?
```

**If [n]:** Skip to Step 5. **If [g]:** Skip to 4c. **If [y]:** Generate both files.

Read and follow `$GW_REPO/.claude/commands/gw/_shared/saas-project-files.md` for the CLAUDE.md and SPEC.md templates.

#### 4b. Copy to project root and choose workflow

**CLAUDE.md copy:** If exists at root, ask: Overwrite [o], merge [m], or keep in .saas-ideas/ only [k]?
**SPEC.md copy:** If exists at root, ask: Overwrite [o], or keep in .saas-ideas/ only [k]?

Then ask (skip if BUILD_MODE — auto-continue to 4c):
```
How would you like to proceed?
  [p] Superpowers — invoke superpowers:writing-plans with SPEC.md (recommended)
  [g] GSD — create project/milestone from tech spec
  [d] Done — handle implementation manually
```

**[p]:** Invoke `Skill(skill="superpowers:writing-plans")`.
**[g]:** Continue to 4c.
**[d]:** Skip to Step 5.

#### 4c. GSD integration

**If BUILD_MODE is true:** Print "GSD integration deferred to Phase 5 (build mode)." Skip to Step 5.

**If BUILD_MODE is false:** Check if `~/.claude/commands/gsd/` exists. If yes:
- **Brownfield** (`.planning/PROJECT.md` exists): invoke `/gsd:new-milestone` referencing TECH-SPEC.md.
- **Greenfield**: invoke `/gsd:new-project` referencing TECH-SPEC.md.

If GSD not installed: "GSD not installed. Use [p] Superpowers instead."

Target: complete working prototype at `{app-name}.codingandmore.net` with Google OAuth, Stripe, PostgreSQL, Terraform/AWS.

#### Error handling for Step 4

- Missing deep-dive artifacts: "Cannot generate project files — run full workflow first or use `--pick N`."
- Permission errors: generate in `.saas-ideas/` only.
- Missing superpowers: "Files ready at {paths} — invoke the skill manually."

### Step 4.5 — Parallel Build (optional)

Generate a build manifest from deep-dive artifacts:

| Feature | Dependencies | Source |
|---------|-------------|--------|
| `auth` | none | Phase 1 |
| `landing-page` | none | Phase 5 |
| `core-feature` | `auth` | Phase 2 |
| `data-api` | `core-feature` | Phase 3 |
| `billing` | `core-feature` | Phase 4 |
| `polish` | all above | Phase 6 |

Write manifest to `.saas-ideas/build-manifest.json`. Ask:
```
Build manifest: 6 features in 4 waves.
Build all in parallel worktrees with TDD? [y] / Manifest only [m] / Skip [s]
```

- `[y]`: invoke `/gw:worktree execute .saas-ideas/build-manifest.json`
- `[m]`: tell user manifest is saved
- `[s]`: continue to Step 5

### Step 5 — Present Results (orchestrator)

1. Display Executive Summary from REPORT.md
2. List all generated files with sizes
3. Print pitch deck path
4. If VERIFY_MODE: one-line verification summary
5. If BUILD_MODE: "Check progress with `/gsd:progress`"
6. If GSD was invoked: note project/milestone created
7. Remind about any failed non-critical agents
8. Print pipeline command hints:
   ```
   Tip: /gw:saas-idea --build --budget low
        /gw:saas-idea --build --budget low --focus devtools
        /gw:saas-idea --auto --verify
   ```

### Step 5.5 — Persona Contribution

Skip if `CREATED_PERSONAS` is empty.

Present created personas and offer to contribute to gw-skills defaults via PR:
1. Save current dir/branch, cd to $GW_REPO
2. Stash if dirty (ask first)
3. Create branch `persona/{slug}` (or `persona/batch-YYYY-MM-DD` for multiple)
4. Copy to `workforce/_defaults/`, commit, push
5. Create PR via `gh pr create`
6. Pop stash if needed, return to original dir/branch

---

## Phase 5 — Build Execution (conditional)

**Skip unless ALL:** BUILD_MODE=true, SKIP_PLANNING=false, `~/.claude/commands/gsd/` exists.

Read and follow `$GW_REPO/.claude/commands/gw/_shared/saas-gsd-scaffold.md` for the GSD Idea Document template, auto-chain launch, and post-build summary.

---

## Step 8.5 — Intent Commit & Auto-PR

Read and follow `$GW_REPO/.claude/commands/gw/_shared/intent-commit.md` to write and commit the `.gw-intent.md` file.

Then read and follow `$GW_REPO/.claude/commands/gw/_shared/auto-pr.md` to create a PR with the `agent_merge` label.

---

## Final — Session Summary

Read and follow `$GW_REPO/.claude/commands/gw/_shared/session-summary.md`.
