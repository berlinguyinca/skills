# Skill Optimization (Tier 1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Decompose 8 oversized skill files below 500 lines, fix broken GSD-2 detection in preamble, and add "USE WHEN" trigger patterns to all skill descriptions.

**Architecture:** Extract agent prompt templates, output format templates, data/reference tables, and session summary/error handling blocks from 8 skill files into new `_shared/` modules. Skills become orchestration stubs that reference extracted content via "Read and follow" directives. The existing `_shared/` pattern (7 modules, ~470 lines) proves this approach. `_shared/pptx-design.md` already exists for the design palette.

**Tech Stack:** Markdown (skill files), YAML (frontmatter), Bash (verification)

---

## File Structure

### New shared modules to create:
- `_shared/source-mapping-table.md` — 28-source search strategy lookup (from research.md)
- `_shared/research-agent-prompt.md` — Research specialist agent prompt template (from research.md)
- `_shared/debate-rounds.md` — Round 1/2/3 structured debate prompts (from research.md, compete.md)
- `_shared/report-template.md` — Markdown report output format (from research.md)
- `_shared/session-summary.md` — Session summary template + error handling patterns (shared across all)
- `_shared/saas-harvest-agents.md` — 6 harvest agent prompts (from saas-idea.md)
- `_shared/saas-scoring.md` — Synthesis agent + scoring methodology + SHORTLIST format (from saas-idea.md)
- `_shared/saas-deep-dive-agents.md` — 4 deep-dive agent prompts: business plan, marketing, tech spec, implementation (from saas-idea.md)
- `_shared/saas-pitch-deck.md` — Pitch deck PPTX slide structure + Python generation (from saas-idea.md)
- `_shared/saas-gsd-scaffold.md` — GSD project scaffold template (from saas-idea.md)
- `_shared/compete-research-agent.md` — Competitor research agent prompt (from compete.md)
- `_shared/compete-feature-matrix.md` — Feature matrix generation + test scaffold prompts (from compete.md)
- `_shared/compete-pptx-slides.md` — Competitive analysis PPTX slide structure (from compete.md)
- `_shared/review-specialist-prompt.md` — App review specialist agent prompt + findings format (from review-app.md)
- `_shared/weekly-json-schema.md` — JSON data structure for weekly presentations (from weekly-review.md)
- `_shared/weekly-pptx-slides.md` — Executive + technical deck slide structures (from weekly-review.md)
- `_shared/audit-deep-scan.md` — Deep scan agent prompt + finding report format (from audit-repo.md)
- `_shared/audit-pptx-slides.md` — Audit PPTX executive + technical deck structures (from audit-repo.md)
- `_shared/review-synthesis-format.md` — Synthesis agent output format + recommendation engine template (from review-app.md)
- `_shared/review-pptx-slides.md` — Review-app PPTX slide structure (from review-app.md)
- `_shared/log-patrol-sources.md` — Source type detection patterns + classification tables (from log-patrol.md)
- `_shared/log-patrol-issue-template.md` — GitHub issue template + diagnosis plan format (from log-patrol.md)
- `_shared/worktree-execute.md` — Worktree execute subcommand manifest format + agent dispatch (from worktree.md)

### Files to modify:
- `_shared/preamble.md` — Add GSD-2 `.gsd/STATE.md` detection
- `research.md` — Extract source mapping, agent prompt, debate rounds, report template, PPTX, session summary
- `saas-idea.md` — Extract harvest agents, scoring, deep-dive agents, pitch deck, GSD scaffold, session summary
- `compete.md` — Extract research agent, feature matrix, debate rounds, PPTX, session summary
- `review-app.md` — Extract specialist prompt, PPTX generation, session summary
- `weekly-review.md` — Extract JSON schema, PPTX slides, session summary
- `audit-repo.md` — Extract deep scan, PPTX slides, session summary
- `log-patrol.md` — Extract source detection patterns, issue template, session summary
- `worktree.md` — Extract execute subcommand manifest/dispatch logic
- All 12 skills — Update YAML description with "USE WHEN" triggers

---

## Task 1: Fix Preamble GSD-2 Detection

**Files:**
- Modify: `.claude/commands/gw/_shared/preamble.md`

- [ ] **Step 1: Read current preamble**

Read `_shared/preamble.md` to confirm the current GSD v1 detection logic.

- [ ] **Step 2: Add GSD-2 detection**

Replace the GSD Project Detection section with version-aware detection:

```markdown
## GSD Project Detection (Model Inheritance)

Skip this step if you are inside a GSD project (`~/.config/opencode/.planning/` exists).

### GSD-2 Detection (check first)

If `.gsd/STATE.md` exists in the current or parent directories:
1. Log: "Detected GSD-2 project"
2. If `.gsd/config.json` exists, read it and extract `model_profile` (default: "balanced")
3. If a profile is found, use it for all agent spawns instead of default Claude model
4. Log: "Using GSD-2 model profile: {profile}" in the first output message

### GSD v1 Detection (fallback)

If `.planning/config.json` exists in the current or parent directories:
1. Read its JSON content
2. Extract `model_profile` (default: "balanced")
3. If a profile is found, use it for all agent spawns instead of default Claude model
4. Log: "Using GSD model profile: {profile}" in the first output message

This enables gw skills to inherit model preferences within managed projects.
```

- [ ] **Step 3: Verify the change**

Run: `wc -l .claude/commands/gw/_shared/preamble.md`
Expected: ~35-40 lines (was 26, added ~10-14 for GSD-2 section)

- [ ] **Step 4: Commit**

```bash
git add .claude/commands/gw/_shared/preamble.md
git commit -m "fix: add GSD-2 detection to preamble alongside GSD v1"
```

---

## Task 2: Create Session Summary Shared Module

This is used by all 6 oversized skills, so extract it first.

**Files:**
- Create: `.claude/commands/gw/_shared/session-summary.md`

- [ ] **Step 1: Read the session summary sections from all 6 skills**

Read the final "Session Summary" section from each skill to identify the common pattern.

- [ ] **Step 2: Write the shared module**

Create `_shared/session-summary.md` with the parameterized template:

```markdown
# Session Summary Template

Print a summary of all files created during this session:

\```
Session complete. Generated files:
  [new]   {path} — {description}
  [skip]  {description} ({--skip-flag} to skip)
  ...

Total: N files created, N skipped
\```

List each file that was created with `[new]` and each output that was skipped (due to --skip flags) with `[skip]`.
```

- [ ] **Step 3: Verify**

Run: `wc -l .claude/commands/gw/_shared/session-summary.md`
Expected: ~15-20 lines

- [ ] **Step 4: Commit**

```bash
git add .claude/commands/gw/_shared/session-summary.md
git commit -m "refactor: extract session summary template to _shared/"
```

---

## Task 3: Decompose research.md (1,192 → <500 lines)

**Files:**
- Create: `.claude/commands/gw/_shared/source-mapping-table.md`
- Create: `.claude/commands/gw/_shared/research-agent-prompt.md`
- Create: `.claude/commands/gw/_shared/debate-rounds.md`
- Create: `.claude/commands/gw/_shared/report-template.md`
- Modify: `.claude/commands/gw/research.md`

- [ ] **Step 1: Read research.md fully**

Read the entire file to identify exact extraction boundaries.

- [ ] **Step 2: Extract source mapping table**

Create `_shared/source-mapping-table.md` containing the search_skills → Source Mapping Table from research.md (the ~40-line table mapping search_skill names to WebSearch strategies). Include the section header and full table content.

- [ ] **Step 3: Extract research agent prompt template**

Create `_shared/research-agent-prompt.md` containing the "Agent Prompt Template" section from research.md Step 4. This is the large prompt template with placeholders ({PERSONA_NAME}, {RESEARCH_QUESTION}, etc.) including the lightweight and deep task lists, rules, and output format.

- [ ] **Step 4: Extract debate round prompts**

Create `_shared/debate-rounds.md` containing the Round 1, Round 2, and Round 3 debate prompt templates from research.md Step 5. Include all three agent prompt templates with their output format specifications.

- [ ] **Step 5: Extract report template**

Create `_shared/report-template.md` containing the full Markdown report structure from research.md Step 7 Option 2. This is the complete report skeleton with section headers and placeholder descriptions.

- [ ] **Step 6: Update research.md to reference extracted modules**

Replace each extracted section in research.md with a "Read and follow" reference:

For the source mapping table:
```markdown
### search_skills → Source Mapping Table

Read the source mapping from `$GW_REPO/.claude/commands/gw/_shared/source-mapping-table.md` and use it to construct source-specific search instructions for each persona.
```

For the agent prompt template:
```markdown
### Agent Prompt Template

Read the agent prompt template from `$GW_REPO/.claude/commands/gw/_shared/research-agent-prompt.md` and substitute the placeholders for each persona.
```

For debate rounds:
```markdown
Read and follow the debate round templates from `$GW_REPO/.claude/commands/gw/_shared/debate-rounds.md`.
```

For the report template:
```markdown
Read the report structure from `$GW_REPO/.claude/commands/gw/_shared/report-template.md`.
```

Replace the session summary section with:
```markdown
Read and follow `$GW_REPO/.claude/commands/gw/_shared/session-summary.md`.
```

- [ ] **Step 7: Verify line count**

Run: `wc -l .claude/commands/gw/research.md`
Expected: <500 lines

- [ ] **Step 8: Verify extracted files exist and have content**

```bash
for f in source-mapping-table.md research-agent-prompt.md debate-rounds.md report-template.md; do
  echo "$f: $(wc -l < .claude/commands/gw/_shared/$f) lines"
done
```

- [ ] **Step 9: Commit**

```bash
git add .claude/commands/gw/_shared/source-mapping-table.md \
       .claude/commands/gw/_shared/research-agent-prompt.md \
       .claude/commands/gw/_shared/debate-rounds.md \
       .claude/commands/gw/_shared/report-template.md \
       .claude/commands/gw/research.md
git commit -m "refactor: decompose research.md into orchestrator + 4 shared modules"
```

---

## Task 4: Decompose saas-idea.md (2,117 → <500 lines)

This is the largest file and needs the most aggressive extraction.

**Files:**
- Create: `.claude/commands/gw/_shared/saas-harvest-agents.md`
- Create: `.claude/commands/gw/_shared/saas-scoring.md`
- Create: `.claude/commands/gw/_shared/saas-deep-dive-agents.md`
- Create: `.claude/commands/gw/_shared/saas-pitch-deck.md`
- Create: `.claude/commands/gw/_shared/saas-gsd-scaffold.md`
- Modify: `.claude/commands/gw/saas-idea.md`

- [ ] **Step 1: Read saas-idea.md fully**

Read the entire 2,117-line file to identify exact extraction boundaries.

- [ ] **Step 2: Extract harvest agent prompts**

Create `_shared/saas-harvest-agents.md` containing the 6 parallel harvest agent prompts (HN, Product Hunt, Reddit, Twitter/X, Google Trends, GitHub). Include the full prompt templates with placeholders.

- [ ] **Step 3: Extract scoring methodology + synthesis agent**

Create `_shared/saas-scoring.md` containing the synthesis agent prompt, the balanced scorecard methodology, and the SHORTLIST.md output format template.

- [ ] **Step 4: Extract deep-dive agent prompts**

Create `_shared/saas-deep-dive-agents.md` containing the 4 parallel deep-dive agent prompts: Business Plan, Marketing Playbook, Tech Spec (with mandatory stack constraints inline), and Implementation Prompts.

- [ ] **Step 5: Extract pitch deck PPTX instructions**

Create `_shared/saas-pitch-deck.md` containing the 10-slide pitch deck structure and Python generation instructions. Reference `_shared/pptx-design.md` for the color palette instead of inlining it.

- [ ] **Step 6: Extract GSD project scaffold**

Create `_shared/saas-gsd-scaffold.md` containing the GSD Idea Document template and the Phase 5 project scaffold format.

- [ ] **Step 7: Update saas-idea.md to reference extracted modules**

Replace each extracted section with a "Read and follow" reference to the corresponding shared module. Keep inline: budget tier semantics, cost-optimization principles, argument parsing, workflow routing, approval gates, and the orchestration step sequence.

- [ ] **Step 8: Verify line count**

Run: `wc -l .claude/commands/gw/saas-idea.md`
Expected: <500 lines

- [ ] **Step 9: Commit**

```bash
git add .claude/commands/gw/_shared/saas-harvest-agents.md \
       .claude/commands/gw/_shared/saas-scoring.md \
       .claude/commands/gw/_shared/saas-deep-dive-agents.md \
       .claude/commands/gw/_shared/saas-pitch-deck.md \
       .claude/commands/gw/_shared/saas-gsd-scaffold.md \
       .claude/commands/gw/saas-idea.md
git commit -m "refactor: decompose saas-idea.md (2117→<500) into orchestrator + 5 modules"
```

---

## Task 5: Decompose compete.md (971 → <500 lines)

**Depends on:** Task 3 (for `_shared/debate-rounds.md`)

**Files:**
- Create: `.claude/commands/gw/_shared/compete-research-agent.md`
- Create: `.claude/commands/gw/_shared/compete-feature-matrix.md`
- Create: `.claude/commands/gw/_shared/compete-pptx-slides.md`
- Modify: `.claude/commands/gw/compete.md`

- [ ] **Step 1: Read compete.md fully**

- [ ] **Step 2: Extract competitor research agent prompt**

Create `_shared/compete-research-agent.md` with the competitor research agent prompt template and output format.

- [ ] **Step 3: Extract feature matrix + test scaffold prompts**

Create `_shared/compete-feature-matrix.md` with the feature matrix generation prompt and the test scaffold generation prompt.

- [ ] **Step 4: Extract PPTX slide structure**

Create `_shared/compete-pptx-slides.md` with the 11-slide competitive analysis deck structure. Reference `_shared/pptx-design.md` for palette.

- [ ] **Step 5: Update compete.md to reference extracted modules**

Replace extracted sections with "Read and follow" references. The debate rounds reference `_shared/debate-rounds.md` (already extracted in Task 3). Replace session summary with reference to `_shared/session-summary.md`.

- [ ] **Step 6: Verify line count**

Run: `wc -l .claude/commands/gw/compete.md`
Expected: <500 lines

- [ ] **Step 7: Commit**

```bash
git add .claude/commands/gw/_shared/compete-research-agent.md \
       .claude/commands/gw/_shared/compete-feature-matrix.md \
       .claude/commands/gw/_shared/compete-pptx-slides.md \
       .claude/commands/gw/compete.md
git commit -m "refactor: decompose compete.md (971→<500) into orchestrator + 3 modules"
```

---

## Task 6: Decompose review-app.md (937 → <500 lines)

**Files:**
- Create: `.claude/commands/gw/_shared/review-specialist-prompt.md`
- Create: `.claude/commands/gw/_shared/review-synthesis-format.md`
- Create: `.claude/commands/gw/_shared/review-pptx-slides.md`
- Modify: `.claude/commands/gw/review-app.md`

- [ ] **Step 1: Read review-app.md fully**

- [ ] **Step 2: Extract specialist agent prompt + findings format**

Create `_shared/review-specialist-prompt.md` with the specialist analysis agent prompt template (~70 lines) and the findings report output format (~30 lines).

- [ ] **Step 3: Extract synthesis agent format + recommendation engine**

Create `_shared/review-synthesis-format.md` with the synthesis agent output format, the REPORT.md structure, and the recommendation engine output template. This section is typically ~150 lines covering the merge of specialist findings.

- [ ] **Step 4: Extract PPTX slide structure**

Create `_shared/review-pptx-slides.md` with the review-app PPTX slide specifications and generation instructions (~80 lines). Reference `_shared/pptx-design.md` for palette.

- [ ] **Step 5: Update review-app.md**

Replace each extracted section with "Read and follow" references. Replace session summary with reference to `_shared/session-summary.md`. Keep inline: argument parsing, workflow routing, app type detection logic, team assembly configuration, approval gates.

- [ ] **Step 6: Verify line count**

Run: `wc -l .claude/commands/gw/review-app.md`
Expected: <500 lines

- [ ] **Step 7: Commit**

```bash
git add .claude/commands/gw/_shared/review-specialist-prompt.md \
       .claude/commands/gw/_shared/review-synthesis-format.md \
       .claude/commands/gw/_shared/review-pptx-slides.md \
       .claude/commands/gw/review-app.md
git commit -m "refactor: decompose review-app.md (937→<500) into orchestrator + 3 modules"
```

---

## Task 7: Decompose weekly-review.md (869 → <500 lines)

**Files:**
- Create: `.claude/commands/gw/_shared/weekly-json-schema.md`
- Create: `.claude/commands/gw/_shared/weekly-pptx-slides.md`
- Modify: `.claude/commands/gw/weekly-review.md`

- [ ] **Step 1: Read weekly-review.md fully**

- [ ] **Step 2: Extract JSON data structure schema**

Create `_shared/weekly-json-schema.md` with the JSON data structure specification for weekly presentation data.

- [ ] **Step 3: Extract PPTX slide structures**

Create `_shared/weekly-pptx-slides.md` with both executive and technical deck slide structure specifications. Reference `_shared/pptx-design.md` for palette.

- [ ] **Step 4: Update weekly-review.md**

Replace extracted sections with "Read and follow" references. Replace session summary.

- [ ] **Step 5: Verify line count**

Run: `wc -l .claude/commands/gw/weekly-review.md`
Expected: <500 lines

- [ ] **Step 6: Commit**

```bash
git add .claude/commands/gw/_shared/weekly-json-schema.md \
       .claude/commands/gw/_shared/weekly-pptx-slides.md \
       .claude/commands/gw/weekly-review.md
git commit -m "refactor: decompose weekly-review.md (869→<500) into orchestrator + 2 modules"
```

---

## Task 8: Decompose audit-repo.md (804 → <500 lines)

**Files:**
- Create: `.claude/commands/gw/_shared/audit-deep-scan.md`
- Create: `.claude/commands/gw/_shared/audit-pptx-slides.md`
- Modify: `.claude/commands/gw/audit-repo.md`

- [ ] **Step 1: Read audit-repo.md fully**

- [ ] **Step 2: Extract deep scan agent prompt + finding format**

Create `_shared/audit-deep-scan.md` with the deep scan agent prompt and threat finding report format.

- [ ] **Step 3: Extract PPTX slide structures**

Create `_shared/audit-pptx-slides.md` with executive (6-slide) and technical (up to 30-slide) deck structures. Reference `_shared/pptx-design.md` for palette.

- [ ] **Step 4: Update audit-repo.md**

Replace extracted sections with "Read and follow" references. Replace session summary.

- [ ] **Step 5: Verify line count**

Run: `wc -l .claude/commands/gw/audit-repo.md`
Expected: <500 lines

- [ ] **Step 6: Commit**

```bash
git add .claude/commands/gw/_shared/audit-deep-scan.md \
       .claude/commands/gw/_shared/audit-pptx-slides.md \
       .claude/commands/gw/audit-repo.md
git commit -m "refactor: decompose audit-repo.md (804→<500) into orchestrator + 2 modules"
```

---

## Task 8.5: Decompose log-patrol.md (713 → <500 lines)

**Files:**
- Create: `.claude/commands/gw/_shared/log-patrol-sources.md`
- Create: `.claude/commands/gw/_shared/log-patrol-issue-template.md`
- Modify: `.claude/commands/gw/log-patrol.md`

- [ ] **Step 1: Read log-patrol.md fully**

- [ ] **Step 2: Extract source type detection patterns + classification**

Create `_shared/log-patrol-sources.md` with the source type detection patterns (SSH, CloudWatch, local files, Docker), connection string formats, and log classification tables.

- [ ] **Step 3: Extract GitHub issue template + diagnosis plan**

Create `_shared/log-patrol-issue-template.md` with the GitHub issue creation template, diagnosis plan format, and error correlation output structure.

- [ ] **Step 4: Update log-patrol.md**

Replace extracted sections with "Read and follow" references. Replace session summary. Keep inline: argument parsing, workflow routing, source discovery logic, approval gates.

- [ ] **Step 5: Verify line count**

Run: `wc -l .claude/commands/gw/log-patrol.md`
Expected: <500 lines

- [ ] **Step 6: Commit**

```bash
git add .claude/commands/gw/_shared/log-patrol-sources.md \
       .claude/commands/gw/_shared/log-patrol-issue-template.md \
       .claude/commands/gw/log-patrol.md
git commit -m "refactor: decompose log-patrol.md (713→<500) into orchestrator + 2 modules"
```

---

## Task 8.7: Decompose worktree.md (561 → <500 lines)

**Files:**
- Create: `.claude/commands/gw/_shared/worktree-execute.md`
- Modify: `.claude/commands/gw/worktree.md`

- [ ] **Step 1: Read worktree.md fully**

- [ ] **Step 2: Extract execute subcommand**

Create `_shared/worktree-execute.md` with the `execute` subcommand's manifest format specification, agent dispatch logic, dependency-wave execution, and per-agent verification steps. This is the largest section in worktree.md.

- [ ] **Step 3: Update worktree.md**

Replace the execute subcommand's detailed implementation with a "Read and follow" reference. Keep inline: create, status, merge-all, cleanup subcommands (they are shorter). Replace session summary.

- [ ] **Step 4: Verify line count**

Run: `wc -l .claude/commands/gw/worktree.md`
Expected: <500 lines

- [ ] **Step 5: Commit**

```bash
git add .claude/commands/gw/_shared/worktree-execute.md \
       .claude/commands/gw/worktree.md
git commit -m "refactor: decompose worktree.md (561→<500) into orchestrator + execute module"
```

---

## Task 9: Add "USE WHEN" Trigger Patterns to All Skill Descriptions

**Files:**
- Modify: All 12 `.claude/commands/gw/*.md` files (YAML frontmatter only)

- [ ] **Step 1: Read all 12 skill YAML frontmatter descriptions**

```bash
for f in .claude/commands/gw/*.md; do
  echo "=== $(basename $f) ==="
  head -5 "$f" | grep "description:"
done
```

- [ ] **Step 2: Update each skill description with "USE WHEN" triggers**

For each skill, append trigger conditions. Examples:

- **research.md**: `"Multi-persona research with structured debate. Use when the user asks to research, investigate, analyze, compare, study, or explore a topic across multiple sources."`
- **saas-idea.md**: `"Harvest and analyze SaaS opportunities. Use when the user wants to find SaaS ideas, explore business opportunities, validate startup concepts, or generate a business plan."`
- **compete.md**: `"Competitive feature analysis with structured debate. Use when the user asks to analyze competitors, compare features, find competitive gaps, or plan competitive features."`
- **review-app.md**: `"Full-stack application review. Use when the user asks to review, audit, or analyze an application's quality, security, architecture, or UX."`
- **merge-it.md**: `"Ship changes end-to-end. Use when the user wants to ship, merge, create a PR, or push current changes through a review workflow."`
- **weekly-review.md**: `"Generate presentations from GitHub activity. Use when the user wants a weekly report, activity summary, or presentation of recent GitHub work."`
- **audit-repo.md**: `"Security audit for repositories. Use when the user wants to audit a repo for security risks, malicious code, backdoors, or supply chain attacks."`
- **log-patrol.md**: `"Monitor production logs. Use when the user wants to scan logs, detect errors, check production health, or investigate deployment issues."`
- **worktree.md**: `"Manage git worktrees. Use when the user wants to create isolated workspaces, work on parallel features, or manage concurrent development branches."`
- **merge-prs.md**: `"Integrate agent PRs. Use when the user wants to merge agent_merge labeled PRs, integrate multiple branches, or consolidate parallel work."`
- **workforce.md**: `"Manage personas. Use when the user wants to hire, fire, edit, or list workforce personas used by team-driven skills."`
- **update.md**: `"Update gw-skills. Use when the user wants to update or check for new versions of gw-skills."`

- [ ] **Step 3: Verify all descriptions include "Use when"**

```bash
for f in .claude/commands/gw/*.md; do
  desc=$(grep "description:" "$f" | head -1)
  if echo "$desc" | grep -qi "use when"; then
    echo "[OK] $(basename $f)"
  else
    echo "[MISSING] $(basename $f): $desc"
  fi
done
```

- [ ] **Step 4: Commit**

```bash
git add .claude/commands/gw/*.md
git commit -m "feat: add USE WHEN trigger patterns to all skill descriptions"
```

---

## Task 10: Final Verification

**Files:** None (verification only)

- [ ] **Step 1: Verify all skill files are under 500 lines**

```bash
echo "=== Line Count Verification ==="
PASS=true
for f in .claude/commands/gw/*.md; do
  lines=$(wc -l < "$f")
  name=$(basename "$f")
  if [ "$lines" -gt 500 ]; then
    echo "[FAIL] $name: $lines lines (over 500)"
    PASS=false
  else
    echo "[OK]   $name: $lines lines"
  fi
done
if $PASS; then echo "All skills under 500 lines."; else echo "SOME SKILLS STILL OVER 500."; fi
```

Expected: All 12 files show [OK]

- [ ] **Step 2: Verify all shared modules exist**

```bash
echo "=== Shared Module Verification ==="
ls -la .claude/commands/gw/_shared/*.md | wc -l
echo "Expected: 30+ files (7 original + 23 new)"
```

- [ ] **Step 3: Verify preamble detects both GSD versions**

```bash
grep -c ".gsd/STATE.md" .claude/commands/gw/_shared/preamble.md
grep -c ".planning/config.json" .claude/commands/gw/_shared/preamble.md
```

Expected: Both return 1 (one reference each for GSD-2 and GSD v1)

- [ ] **Step 4: Commit verification results as a tag**

```bash
git tag -a v1.1-tier1-optimization -m "Tier 1 optimization complete: 8 skills decomposed below 500 lines, GSD-2 detection, USE WHEN triggers"
```
