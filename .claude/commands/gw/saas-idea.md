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

Check if `.saas-ideas/` directory exists. If it does and `--pick` was NOT set and `--fresh` was NOT set, ask the user: "`.saas-ideas/` already exists from a previous run. Harvest fresh data, re-use existing shortlist, or view existing REPORT.md?" Handle each choice:
- If they choose to view: read and present `.saas-ideas/REPORT.md` and stop.
- If they choose to re-use: skip to interactive selection on existing `SHORTLIST.md` (skip Phase 1 and Phase 2).
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
