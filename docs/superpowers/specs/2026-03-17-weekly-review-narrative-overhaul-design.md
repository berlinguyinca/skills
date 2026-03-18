# Weekly Review Executive Deck — Narrative & Visual Overhaul

**Date:** 2026-03-17
**Skill:** `gw:weekly-review`
**Scope:** Executive deck only (technical deck unchanged for now)

## Problem

The executive deck feels like a dressed-up GitHub activity dump. PRs are listed individually, KPIs are vanity metrics (PR counts), charts visualize counts rather than insights, and redundant slides say the same things twice. The result: a mixed audience of technical and non-technical stakeholders walks away thinking "they were busy" rather than "they shipped real value."

The deck needs to work both async (self-explanatory when emailed) and live (clean enough to present without reading walls of text).

## Solution: Top-Down Narrative + Purpose-Built Visuals

Replace the bottom-up PR-listing approach with top-down theme synthesis. Claude identifies 2-3 natural themes from the week's PRs and builds the deck around those themes, using PRs as supporting evidence rather than as the skeleton. Every slide has one job. Every visual earns its place.

## Slide Structure

5-6 slides (down from up to 8), each with a single purpose. Always 2 theme slides; a 3rd theme slide is added only when the data clearly supports 3 distinct themes:

### Slide 1: Title
- Project/org name, date range
- Clean, minimal — same as today but lighter

### Slide 2: The Headline
- One bold sentence capturing the week's impact (not a summary, but *why it matters*)
- Subtitle with supporting context
- Exactly 3 outcome-oriented KPI cards with real numbers extracted from PR evidence
- KPIs are outcomes ("30min auto-recovery", "1000x queue speedup") not activity counts ("7 new capabilities", "12 PRs merged")
- Always 3 cards — if only 2 strong outcomes exist, the 3rd can be a qualitative outcome (e.g., "Dev Experience" with label "macOS builds fixed")

### Slides 3-4: Theme Slides (2, sometimes 3)
- Each theme groups related PRs into a coherent story
- Layout: headline + subtitle at top, evidence bullets on left (60%), visual anchor on right (40%)
- Evidence bullets: bold claim + gray supporting detail, blue left border
- Visual anchor type chosen per theme:
  - **Before/After** — when there's a measurable improvement (e.g., hours → 30 min)
  - **Metric Callout** — when one big number tells the story (e.g., 1000x)
  - **Count Cards** — when the theme is about breadth (e.g., 3 bugs across 3 subsystems)

### Slide 5: What's Next
- Max 4 items from open PRs
- Each item: status pill (TESTING/PLANNED) + title + brief detail — one line each
- No paragraphs, no multi-line descriptions

## Narrative Synthesis Pipeline

### Step 1: Gather Data (unchanged)
Same GitHub queries via `gh` CLI — merged PRs, open PRs, commits. Same rich PR body extraction for quantitative evidence (numbers, timeouts, performance improvements, test counts).

### Step 2: Theme Synthesis (new)
Instead of categorizing PRs into fixed buckets (Bug Fix, Feature, Improvement, etc.), Claude reads all PR data and identifies 2-3 natural themes — clusters of work that tell a coherent story together.

Example from a real week:
- "Turnaround Time Overhaul" groups: scheduler priority PR, auto-recovery PR, batch query optimization PR
- "Reliability & Stability" groups: deadlock fix PR, temp file cleanup PR, macOS build fix PR

Themes emerge from the data. They are not predetermined categories.

### Step 3: Headline Generation (new)
Claude writes one bold sentence capturing the week's impact. The 3 KPIs are extracted from PR body evidence — real numbers, not PR counts. If the PR data lacks quantitative evidence, the KPI card shows a qualitative outcome instead.

### Step 4: Visual Anchor Selection (new)
For each theme slide, Claude selects the visual anchor type that best communicates the theme's impact:
- `before_after` — measurable improvement exists
- `metric_callout` — one dominant number
- `count_cards` — breadth of impact
- `evidence_list` (fallback) — when no quantitative anchor fits, the right column shows a compact bulleted summary instead of a visual element. This is the default if none of the above apply.

### Step 5: What's Next Curation (improved)
Open PRs filtered to the 4 most significant items. Each gets a one-line description and status pill. No paragraphs.

### Removed: Interactive Q&A
The Q&A step (Step 4e in the current skill) is removed entirely — for both executive and technical decks. Claude derives everything from the PR data autonomously. If evidence is insufficient, the slide acknowledges it rather than asking. This is a behavioral change to the technical deck flow as well, but the technical deck's slide structure and renderer remain unchanged.

## Visual Design System

### Color Palette (unchanged)
- PRIMARY: #2C3E50 (dark blue-gray — text only, not backgrounds)
- ACCENT: #3498DB (bright blue — accent bar, KPI numbers, bullet borders)
- SUCCESS: #27AE60 (green — "after" states, positive metrics)
- DANGER: #E74C3C (red — "before" states)
- WARNING: #F39C12 (amber — "testing" pills)
- MUTED: #95A5A6 (gray — captions, secondary text)
- BG_LIGHT: #F8F9FA (light gray — headline slide background)
- CARD_BORDER: #E0E0E0

### Typography (unchanged)
- Calibri throughout
- Headline: 28pt bold, PRIMARY
- Subtitle: 16pt, MUTED
- Theme title: 24pt bold, PRIMARY
- Evidence claim: 14pt bold, PRIMARY
- Evidence detail: 12pt, MUTED
- KPI value: 36pt bold, ACCENT
- KPI label: 11pt uppercase, MUTED

### Layout Principles
- 16:9 widescreen (13.333" x 7.5")
- Light backgrounds throughout (white or #F8F9FA) — no dark slides
- Left accent bar (0.06" wide, ACCENT color) on every slide
- Margins: 0.7" left/right, 0.5" top/bottom
- KPI cards: white with subtle border (#E0E0E0) and light shadow
- Before/After boxes: pastel tinted backgrounds (red: #FDF2F2, green: #F0FAF4)
- What's Next rows: light gray (#F8F9FA) row backgrounds for scannability
- Status pills: colored rounded badges (TESTING = amber, PLANNED = blue)

### Color Token Mapping (for JSON `color` field)
The JSON `color` field on KPI cards maps to hex values as follows:
- `"accent"` → #3498DB (ACCENT)
- `"success"` → #27AE60 (SUCCESS)
- `"danger"` → #E74C3C (DANGER)
- `"warning"` → #F39C12 (WARNING)

## Python Renderer Changes

### New Slide Types
The renderer receives JSON with the new structure and renders these slide types:

**`headline`** — Slide 2
- Light gray background
- Bold headline text top-left, subtitle underneath
- 3 KPI card shapes at bottom — white rounded rectangles with large number + small label

**`theme`** — Slides 3-4
- White background
- Title + subtitle at top
- Left column: evidence bullet groups (text frames with paragraph formatting)
- Right column: visual anchor variant
  - `before_after`: Two stacked rounded rectangles (red top / green bottom) with arrow text between
  - `metric_callout`: Single large centered number with label
  - `count_cards`: 2-3 small stat boxes in a row
  - `evidence_list` (fallback): Compact bulleted summary when no quantitative anchor fits

**`whats_next`** — Slide 5
- Row layout: status pill shape + title text + detail text per item
- Max 4 rows, light gray row background shapes

### Removed Slide Types
- `key_deliverables` — merged into theme slides
- `impact_details` — redundant with theme slides
- `focus_areas` — donut chart of PR categories (vanity visual)
- Bar chart of work distribution (vanity visual)

### Removed Logic
- Interactive Q&A step (Step 4e)
- Degenerate chart detection (no generic charts to be degenerate)
- PR-by-PR slide generation for executive deck

### Kept
- Title slide (simplified)
- Left accent bar on all slides
- Truncation guards (80 char titles, 150 char bullets)
- `matplotlib` as dependency (retained for the technical deck renderer; not used by the new executive slide types)
- `uv run --with` execution model
- JSON handoff file at `/tmp/weekly_review_data.json`
- Config system at `~/.config/gw-skills/weekly-review.json`

## JSON Handoff Format

The JSON written to `/tmp/weekly_review_data.json` changes structure. The new format replaces the `executive` key in the existing JSON. The `technical` key (used by the technical deck renderer) remains unchanged and continues to use the existing fields (`highlights`, `bug_fixes`, `category_counts`, `impact_areas`, etc.). The full JSON file contains both:

```json
{
  "executive": { /* new format below */ },
  "technical": { /* unchanged — same structure as today */ }
}
```

The new `executive` value:

```json
{
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
          "detail": "Previously required manual operator intervention, stalling results for hours"
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
      "title": "Interactive node monitoring dashboard",
      "detail": "Full terminal UI for processing nodes",
      "status": "testing"
    }
  ]
}
```

## Scope & Constraints

- **Executive deck only.** Technical deck is unchanged in this iteration.
- **Same toolchain.** `python-pptx`, `matplotlib`, `uv run`, `gh` CLI.
- **Same config system.** `~/.config/gw-skills/weekly-review.json` unchanged.
- **Same data sources.** GitHub queries unchanged — the change is in synthesis, not collection.
- **Backward compatible.** The skill still produces `weekly-review-executive-YYYY-MM-DD.pptx` in the working directory.
- **Asset harvesting out of scope.** The current skill's harvested `.pptx` assets (Step 3e) are not used in the new executive slide types. This could be revisited later to embed real screenshots as visual anchors.

## Success Criteria

1. Executive deck is 5-6 slides (title + headline + 2-3 themes + what's next)
2. No slide contains a generic PR-count chart (donut, bar chart of categories)
3. KPI values are outcome-oriented numbers extracted from PR evidence, not activity counts
4. Each theme slide has a clear headline, evidence bullets, and a visual anchor
5. What's Next items are one line each with status pills
6. No interactive Q&A step — fully autonomous generation
7. A mixed audience (technical + non-technical) can understand every slide without explanation
