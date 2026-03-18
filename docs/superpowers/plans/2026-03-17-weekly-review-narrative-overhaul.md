# Weekly Review Narrative & Visual Overhaul — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign the executive deck from a bottom-up PR dump into a top-down theme-based narrative with purpose-built slide layouts (5-6 slides).

**Architecture:** The skill markdown (`weekly-review.md`) drives Claude's narrative synthesis (Steps 4c and 4e). The Python renderer (`/tmp/weekly_review_gen.py`, written inline by the skill in Step 5b) generates slides from a JSON handoff. Both must change: the skill gets new synthesis instructions (themes instead of PR lists, no Q&A), and the renderer gets new slide types (headline, theme, whats_next) replacing the old ones.

**Tech Stack:** Claude Code skill (markdown), Python 3.11+, python-pptx 1.0.2, matplotlib (technical deck only)

---

## File Map

| File | Action | Responsibility |
|------|--------|----------------|
| `.claude/commands/gw/weekly-review.md` | Modify | Skill instructions — Steps 4c, 4e, 5a, 5b, and the executive slide table |
| No new files | — | All changes are within the existing skill file |

The Python renderer is written inline in Step 5b of the skill markdown. It is not a separate file in the repo — Claude generates it to `/tmp/weekly_review_gen.py` at runtime. Changes to the renderer are made by editing the Step 5b instructions in the skill markdown.

---

### Task 1: Update Step 4c — Theme-Based Executive Narrative

**Files:**
- Modify: `.claude/commands/gw/weekly-review.md:246-273` (Step 4c executive narrative instructions)

- [ ] **Step 1: Read the current Step 4c section**

Read lines 246-273 of `weekly-review.md` to confirm the exact content to replace.

- [ ] **Step 2: Replace Step 4c with theme-based synthesis instructions**

Replace the current Step 4c content (lines 246-273) with the following. Use the Edit tool with the old content starting from `### 4c. Generate executive narrative` through the end of the "Rules:" paragraph (ending at the line before `### 4d.`):

```markdown
### 4c. Generate executive narrative (org-first, theme-based)

**Organization work dominates the narrative.** Personal repos get a brief mention at most.

**Use the PR body context extracted in Step 3a-ii to build a top-down, theme-based narrative** — not a list of PRs. The executive deck must make someone glance at it and think "this team ships real value."

#### Theme Synthesis

Read all merged PR data and identify **2-3 natural themes** — clusters of related work that tell a coherent story together. Themes emerge from the data; they are NOT predetermined categories like "Bug Fix" or "Feature."

**Examples of good themes:**
- "Turnaround Time Overhaul" (groups: scheduler priority PR, auto-recovery PR, batch optimization PR)
- "Reliability & Stability" (groups: deadlock fix, temp file cleanup, build fix)
- "Operator Tooling" (groups: dry-run mode, CLI commands, monitoring endpoints)

**Examples of bad themes (too generic):**
- "Features" / "Bug Fixes" / "Improvements" — these are categories, not themes
- "Backend Work" / "Various Updates" — too vague to tell a story

Always produce exactly 2 themes. Add a 3rd only when the data clearly supports 3 distinct stories. Never exceed 3.

#### Headline Generation

Write one bold sentence capturing the week's most impactful story. Use specific numbers from PR bodies when available. This is the sentence people remember.

- BAD: "Several improvements to the processing pipeline"
- GOOD: "Sample processing got dramatically faster — auto-recovery, smarter scheduling, and a 1000x query speedup"

#### Produce the following JSON structure:

- **headline**: One bold sentence (see above).
- **subtitle**: One supporting sentence with additional context.
- **kpis**: Exactly 3 outcome-oriented KPI cards. Each is `{"value": "...", "label": "...", "color": "accent|success|danger|warning"}`.
  - KPI values are OUTCOMES with real numbers from PR evidence: "30 min" (auto-recovery time), "1000x" (speedup), "3" (bugs eliminated).
  - NOT activity counts: "12 PRs", "7 features", "45 commits" are meaningless to a lab director.
  - Always 3 cards. If only 2 strong quantitative outcomes exist, the 3rd can be qualitative (e.g., value: "Fixed", label: "macOS Dev Builds").
  - Color mapping: `"accent"` = #3498DB, `"success"` = #27AE60, `"danger"` = #E74C3C, `"warning"` = #F39C12.
- **themes**: Array of 2-3 theme objects, each containing:
  ```json
  {
    "title": "Turnaround Time Overhaul",
    "subtitle": "Faster results for lab users, less manual work for operators",
    "evidence": [
      {
        "claim": "Stuck samples auto-recover in 30 minutes",
        "detail": "Previously required manual operator intervention, stalling results for hours"
      }
    ],
    "visual_anchor": {
      "type": "before_after|metric_callout|count_cards|evidence_list",
      ...
    }
  }
  ```
  - Each theme has 2-3 evidence items. Each evidence item has a bold `claim` (max 10 words) and a gray `detail` (max 25 words) with specific numbers from PR bodies.
  - `visual_anchor` type selection:
    - `"before_after"`: Use when there's a measurable improvement. Fields: `before: {value, detail}`, `after: {value, detail}`.
    - `"metric_callout"`: Use when one big number tells the story. Fields: `value`, `label`.
    - `"count_cards"`: Use when the theme is about breadth. Fields: `cards: [{value, label}, ...]`.
    - `"evidence_list"` (fallback): Use when no quantitative anchor fits. Fields: `items: ["string", ...]`.
- **whats_next**: Array of max 4 items from open PRs, each: `{"title": "...", "detail": "...", "status": "testing|planned"}`. Title is max 8 words. Detail is max 10 words. Status is lowercase.
- **side_projects**: 1-2 sentences about personal repo activity, or empty string if none.

**Rules:** No jargon, no code references, no file paths. Every claim must cite specific evidence from PR descriptions. Generic statements like "improved reliability" are not acceptable.
```

- [ ] **Step 3: Verify the edit**

Read the modified section to confirm the new Step 4c is properly placed between Step 4b and Step 4d, with no duplicate content.

- [ ] **Step 4: Commit**

```bash
git add .claude/commands/gw/weekly-review.md
git commit -m "feat(weekly-review): replace PR-listing narrative with theme-based synthesis"
```

---

### Task 2: Remove Step 4e — Interactive Q&A

**Files:**
- Modify: `.claude/commands/gw/weekly-review.md:301-363` (Step 4e interactive Q&A)

- [ ] **Step 1: Read the current Step 4e section**

Read lines 301-363 of `weekly-review.md` to confirm the exact content of Step 4e.

- [ ] **Step 2: Delete Step 4e entirely**

Remove everything from `## Step 4e — Interactive review & enrichment` through the line `If the user says "skip" or "just generate" at any point, skip remaining questions and proceed with the data as-is.` (inclusive).

Replace with a brief note:

```markdown
### 4e. (Removed)

The interactive Q&A step has been removed. Claude derives all narrative content autonomously from PR data. If PR bodies lack sufficient evidence, the slide text acknowledges this rather than asking the user.
```

- [ ] **Step 3: Verify the edit**

Read the surrounding sections to confirm Step 4e is cleanly removed and Step 5 follows naturally.

- [ ] **Step 4: Commit**

```bash
git add .claude/commands/gw/weekly-review.md
git commit -m "feat(weekly-review): remove interactive Q&A step — fully autonomous generation"
```

---

### Task 3: Update Step 5a — New JSON Handoff Structure

**Files:**
- Modify: `.claude/commands/gw/weekly-review.md:365-450` (Step 5a JSON structure)

- [ ] **Step 1: Read the current Step 5a section**

Read lines 365-450 of `weekly-review.md` to see the current JSON structure definition.

- [ ] **Step 2: Replace the executive portion of the JSON structure**

The JSON structure needs two changes:
1. The `executive` key gets the new format (headline, themes[], whats_next[])
2. The `technical` key stays exactly the same

Replace the `"executive": { ... }` block in the JSON example with:

```json
"executive": {
  "metadata": {
    "date_range": "2026-03-11 – 2026-03-17",
    "org": "metabolomics-us",
    "repos": ["repo1", "repo2"]
  },
  "headline": {
    "text": "Sample processing got dramatically faster",
    "subtitle": "Auto-recovery, smarter scheduling, and a 1000x query speedup",
    "kpis": [
      {"value": "30 min", "label": "Auto-Recovery", "color": "accent"},
      {"value": "1000x", "label": "Queue Speedup", "color": "accent"},
      {"value": "3", "label": "Bugs Eliminated", "color": "success"}
    ]
  },
  "themes": [
    {
      "title": "Turnaround Time Overhaul",
      "subtitle": "Faster results for lab users, less manual work for operators",
      "evidence": [
        {
          "claim": "Stuck samples auto-recover in 30 minutes",
          "detail": "Previously required manual operator intervention"
        }
      ],
      "visual_anchor": {
        "type": "before_after",
        "before": {"value": "Hours", "detail": "Manual recovery, FIFO queue"},
        "after": {"value": "30 min", "detail": "Auto-recovery, priority queue"}
      }
    }
  ],
  "whats_next": [
    {
      "title": "Interactive node dashboard",
      "detail": "Terminal UI for processing nodes",
      "status": "testing"
    }
  ],
  "side_projects": ""
}
```

Note: The `metadata` field provides org name, repos, and date range for the title slide. The `side_projects` field is kept for optional mention on the What's Next slide or as a brief footnote — it is produced by Step 4c but not rendered as its own slide.

Keep the `technical` key and all its contents (`stats`, `commits_by_repo`, `commits_by_date`, `category_counts`, `impact_areas`, `org_prs`, `personal_prs`, `open_prs`, `harvested_assets`) exactly as they are.

- [ ] **Step 3: Verify the edit**

Read the full JSON block to confirm: (a) the `executive` key uses the new format, (b) the `technical` key is unchanged, (c) the JSON is valid.

- [ ] **Step 4: Commit**

```bash
git add .claude/commands/gw/weekly-review.md
git commit -m "feat(weekly-review): update JSON handoff format for theme-based executive structure"
```

---

### Task 4: Update Step 5b — New Executive Slide Renderer Instructions

**Files:**
- Modify: `.claude/commands/gw/weekly-review.md:524-553` (executive slide table and design instructions)

- [ ] **Step 1: Read the current executive deck table**

Read lines 524-553 of `weekly-review.md` to see the current executive slide table.

- [ ] **Step 2: Replace the executive deck slide table**

Replace the current executive deck table (from `### Executive deck` through the `| 8 |` row on line 552, keeping the `---` separator on line 554 intact) with:

```markdown
### Executive deck — `CWD/weekly-review-executive-YYYY-MM-DD.pptx` (5-6 slides)

| # | Slide | Content |
|---|-------|---------|
| 1 | **Title** | "Development Update" large title. Org name(s) + date range as subtitle. Light background (#F8F9FA). Clean, minimal. |
| 2 | **Headline & KPIs** | Light gray background (#F8F9FA). The `headline.text` as 28pt bold text at top. `headline.subtitle` as 16pt gray text below. 3 KPI cards at bottom — white rounded rectangles with subtle border (#E0E0E0), large number (36pt bold, color from `kpis[].color` token mapped to hex), small uppercase label (11pt, MUTED) below. Color token mapping: `"accent"` → #3498DB, `"success"` → #27AE60, `"danger"` → #E74C3C, `"warning"` → #F39C12. |
| 3-4 | **Theme Slides** (2, or 3 if data supports it) | White background. Theme `title` as 24pt bold at top, `subtitle` as 14pt gray below. **Left column (60%):** 2-3 evidence bullets, each with a 3px blue (#3498DB) left border. Bold `claim` (14pt, PRIMARY) + gray `detail` (12pt, MUTED) below. **Right column (40%):** Visual anchor, rendered by type: **`before_after`**: Two stacked rounded rectangles — red top (#FDF2F2 bg, #E74C3C text) with "Before" label + value + detail, arrow "↓" between, green bottom (#F0FAF4 bg, #27AE60 text) with "After" label + value + detail. **`metric_callout`**: Single large centered number (36pt bold, ACCENT) with label (14pt, MUTED). **`count_cards`**: 2-3 small stat boxes side by side, each with bold number + small label. **`evidence_list`**: Compact bulleted list of items in SECONDARY 12pt. |
| 5 | **What's Next** | White background. Title "What's Next" (24pt bold). Max 4 rows, each on a light gray (#F8F9FA) row background with rounded corners. Each row: status pill (small rounded rectangle — TESTING = #F39C12, PLANNED = #3498DB, white text, 9pt bold) + title (14pt bold, PRIMARY) + detail (12pt, MUTED). |
```

- [ ] **Step 3: Update the design principle section**

Find the `### DESIGN PRINCIPLE: VISUAL + CONTEXT` section (around line 526-538). Replace the paragraph starting with `**Balance rule: ~50% visual, ~50% concise text.**` through `- Use matplotlib for data visualization. Charts should be clear enough to understand in 3 seconds.` (4 lines of executive-specific chart guidance that are now outdated) with:

```
**Balance rule: every slide has one job.** The headline slide sets the week's story with 3 outcome KPIs. Theme slides pair evidence bullets with a visual anchor. The What's Next slide is scannable rows. No charts for the sake of charts — only visuals that add insight.
```

Keep the line `**The technical deck is more chart-heavy** (~70% visual) since the audience understands the data.` — that still applies.

- [ ] **Step 3b: Update the intro line about max slides**

Find line 20 of the file which says `an **executive deck** (max 8 slides` and change `max 8 slides` to `5-6 slides`.

- [ ] **Step 4: Verify the edit**

Read the full executive deck section to confirm the new slide table is correct and the technical deck table is untouched.

- [ ] **Step 5: Commit**

```bash
git add .claude/commands/gw/weekly-review.md
git commit -m "feat(weekly-review): replace executive slide table with theme-based layouts"
```

---

### Task 5: Update Step 5b — Python Renderer Executive Section

**Files:**
- Modify: `.claude/commands/gw/weekly-review.md:573-584` (Python implementation details for executive deck)

This task updates the Python implementation instructions that tell Claude how to write the renderer code. The renderer is generated at runtime by Claude into `/tmp/weekly_review_gen.py`.

- [ ] **Step 1: Read the Python implementation details section**

Read lines 573-598 of `weekly-review.md` (through the `### 5c` header) to find the Python implementation notes and confirm the insertion point.

- [ ] **Step 2: Add executive renderer instructions after the existing Python implementation details**

After the line about printing absolute paths (`Print the absolute paths of both generated files on success`), and before `### 5c. Execute the script`, add:

```markdown
**Executive deck renderer — new slide types:**

The executive section of the Python renderer must generate these slides from the `executive` key in the JSON:

**Slide 1 (Title):** Same as before — "Development Update", org names, date range. Use BG_LIGHT fill for slide background.

**Slide 2 (Headline + KPIs):**
- Background: BG_LIGHT (#F8F9FA) — add a full-slide rounded rectangle with BG_LIGHT fill behind everything
- Headline text: 28pt bold PRIMARY, positioned at (0.7", 0.5"), width 11", word wrap
- Subtitle: 16pt MUTED, below headline
- 3 KPI cards at bottom: white rounded rectangles with CARD_BORDER (#E0E0E0) border, centered horizontally
  - Card width: 3.5", height: 1.4", gap: 0.5" between cards
  - Value: 36pt bold, color from token mapping (accent→ACCENT, success→SUCCESS, danger→DANGER, warning→WARNING)
  - Label: 11pt uppercase MUTED, centered below value

**Slides 3-4 (Theme slides):**
- Background: white
- Title: 24pt bold PRIMARY at (0.7", 0.4")
- Subtitle: 14pt MUTED at (0.7", 0.85")
- Left column (60%, from x=0.7" to x=7.8"):
  - Evidence bullets starting at y=1.5", each bullet block is ~1.2" tall
  - Each bullet: blue accent bar shape (0.04" wide, ~0.8" tall, ACCENT fill) at left edge
  - Claim text: 14pt bold PRIMARY, indented 0.15" right of accent bar
  - Detail text: 12pt MUTED, same indent, below claim
- Right column (40%, from x=8.2" to x=12.6"):
  - Visual anchor rendering by type:
  - `before_after`: Two stacked rounded rectangles
    - "Before" box: fill RGBColor(0xFD, 0xF2, 0xF2), y starts at 1.5". Label "BEFORE" in 9pt DANGER uppercase, value in 22pt bold DANGER, detail in 11pt MUTED. Height: 1.6"
    - Arrow "↓" text between boxes in 18pt MUTED, centered
    - "After" box: fill RGBColor(0xF0, 0xFA, 0xF4). Same layout as before but SUCCESS colors. Height: 1.6"
  - `metric_callout`: Single centered block. Value in 48pt bold ACCENT, label in 14pt MUTED below.
  - `count_cards`: 2-3 small rounded rectangles side by side, each with bold number (24pt ACCENT) and label (10pt MUTED).
  - `evidence_list`: Bulleted text list, each item 12pt SECONDARY with bullet character "•".

**Slide 5 (What's Next):**
- Title "What's Next" at (0.7", 0.4"), 24pt bold PRIMARY
- Each item is a row with light gray (#F8F9FA) rounded rectangle background
  - Row height: 0.8", gap: 0.3" between rows, starting at y=1.3"
  - Status pill: small rounded rectangle (width: 1.1", height: 0.35"), centered vertically in row
    - "testing" → WARNING fill, white 9pt bold text "TESTING"
    - "planned" → ACCENT fill, white 9pt bold text "PLANNED"
  - Title: 14pt bold PRIMARY, positioned right of pill
  - Detail: 12pt MUTED, right-aligned or after title

**Removed from executive renderer:**
- The `make_hbar_highlights()` chart call and "Key Deliverables" slide
- The "Impact Details" expanded text slide
- The "Issues Resolved" slide (bug fixes are now folded into themes)
- The `make_donut_chart()` call and "Focus Areas" slide
- The "In Testing & Coming Soon" paragraph-style slide
- The "Side Projects" slide
- The `extract_status_tag()` helper (no longer needed for executive deck)
- The hardcoded `exec_summary` paragraph

**Kept for executive renderer:**
- `new_slide()`, `add_accent_bar()`, `add_text_box()`, `add_paragraph()`, `set_run()`, `add_rounded_card()`, `trunc()` helpers
- `SLIDE_W`, `SLIDE_H`, `FONT`, and all color constants
- The title slide (Slide 1) — just update background to BG_LIGHT
```

- [ ] **Step 3: Verify the edit**

Read the modified section to confirm the new renderer instructions are in the right place and don't overlap with the technical deck instructions.

- [ ] **Step 4: Commit**

```bash
git add .claude/commands/gw/weekly-review.md
git commit -m "feat(weekly-review): add Python renderer instructions for new executive slide types"
```

---

### Task 6: Integration Test — Generate a Deck

- [ ] **Step 1: Run the updated skill**

Execute `/gw:weekly-review` with the default configuration to generate presentations from real GitHub data. This tests the full pipeline end-to-end.

- [ ] **Step 2: Verify the executive deck structure**

Open the generated `weekly-review-executive-*.pptx` and verify:
- Exactly 5-6 slides (title + headline + 2-3 themes + what's next)
- Slide 2 has 3 KPI cards with outcome values (not PR counts)
- Slides 3-4 have evidence bullets on the left and a visual anchor on the right
- Slide 5 has status pills and one-line items
- No donut charts, no bar charts, no "Impact Details" or "Key Deliverables" slides
- No Q&A prompt appeared during generation

- [ ] **Step 3: Verify the technical deck is unchanged**

Open the generated `weekly-review-technical-*.pptx` and verify it still has all the expected slides (stats dashboard, commit activity, work distribution, PR details, etc.).

- [ ] **Step 4: Fix any issues**

If the executive deck doesn't match the spec, read the generated Python script at `/tmp/weekly_review_gen.py` to identify the issue. Adjust the skill instructions in `weekly-review.md` and re-run.

- [ ] **Step 5: Commit any fixes**

```bash
git add .claude/commands/gw/weekly-review.md
git commit -m "fix(weekly-review): address integration test issues in executive deck generation"
```

---

## Task Dependencies

```
Task 1 (Step 4c narrative) ──┐
Task 2 (Remove Q&A)     ────┤
Task 3 (JSON handoff)   ────┼──→ Task 5 (Renderer) ──→ Task 6 (Integration test)
Task 4 (Slide table)    ────┘
```

Tasks 1-4 can be executed in any order (they modify different sections of the same file). Task 5 depends on Tasks 1-4. Task 6 depends on Task 5.
