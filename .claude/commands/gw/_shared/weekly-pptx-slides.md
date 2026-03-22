# Weekly Review — PPTX Slide Specifications

Reference `$GW_REPO/.claude/commands/gw/_shared/pptx-design.md` for the canonical color palette, typography, and execution instructions.

---

## Design Principle

**The executive deck tells a story to non-technical stakeholders.** Each slide has one job — a clear visual element paired with concise text that answers "why does this matter?"

**The technical deck is chart-heavy** (~70% visual) since the audience understands the data.

---

## Executive Deck — `docs/gw/weekly-review-executive-YYYY-MM-DD.pptx` (5-9 slides)

| # | Slide | Content |
|---|-------|---------|
| 1 | **Title** | "Development Update" 32pt bold PRIMARY. Author's full name (`data["author_name"]`) 20pt SECONDARY below. Org names + date range 18pt SECONDARY below that. Impact line: `"This week's focus: {category} — {summary}"` from `executive.impact_focus`, 16pt italic MUTED at y=5.5". BG_LIGHT slide background. |
| 2 | **Headline & KPIs** | BG_LIGHT background. `headline.text` as 28pt bold PRIMARY at (0.7", 0.5"), width 11". `headline.subtitle` as 16pt MUTED below. 3 KPI cards at bottom: white ROUNDED_RECTANGLE with CARD_BORDER (#E0E0E0) border. Card: 3.5" wide, 1.4" tall, 0.5" gap. Value: 36pt bold, color from token map. Label: 11pt uppercase MUTED centered below. |
| 3-4 | **Theme Slides** (2, or 3 if data supports it) | White background. Theme `title` 24pt bold PRIMARY at (0.7", 0.4"). `subtitle` 14pt MUTED at (0.7", 0.85"). **Left 60%** (x=0.7"–7.8"): 2-3 evidence bullets at y=1.5", each ~1.2" tall. Each bullet: 0.04"-wide ACCENT shape at left edge. `claim` 14pt bold PRIMARY + `detail` 12pt MUTED below. **Right 40%** (x=8.2"–12.6"): visual anchor by type — see Visual Anchor Rendering below. |
| 5-7 | **Spotlight slides** (0-3, one per highlight) | White background, accent bar. Title: "Spotlight: [title]" 24pt bold PRIMARY at (0.7", 0.4"). **Left 55%** (x=0.7"–7"): problem text 14pt SECONDARY at y=1.3" (max 3 sentences); result text 14pt bold SUCCESS at y=3.5" (max 3 sentences); user's description in quotes 12pt italic MUTED at y=5.5". **Right 45%** (x=7.3"–12.6"): dashed-border placeholder from y=1.3"–6.5", "Screenshot: [hint]" in MUTED 14pt centered. Skip if no highlights. |
| | **What I Learned** | White background, accent bar. Title "What I Learned" 24pt bold PRIMARY. 1-3 learning cards horizontal: 1 card=11.9", 2=5.7" each, 3=3.7" each with 0.3" gap. Each card: ROUNDED_RECTANGLE BG_LIGHT fill, height 5.5". Top ~3": matplotlib visual by `visual_type` (see Learning Visuals below). Bottom ~2.5": title 14pt bold PRIMARY centered + insight 12pt SECONDARY centered. Skip if no learnings. |
| Last | **What's Next** | White background. Title "What's Next" 24pt bold PRIMARY at (0.7", 0.4"). Max 4 rows, each BG_LIGHT ROUNDED_RECTANGLE, height 0.8", gap 0.3", starting y=1.3". Status pill: ROUNDED_RECTANGLE 1.1"×0.35" — "testing"→WARNING fill, "planned"→ACCENT fill, white 9pt bold text. Title 14pt bold PRIMARY right of pill. Detail 12pt MUTED. If `side_projects` non-empty: append as footnote 11pt MUTED at bottom. |

---

## Technical Deck — `docs/gw/weekly-review-technical-YYYY-MM-DD.pptx` (max 25 slides)

| # | Slide | Content |
|---|-------|---------|
| 1 | **Title** | Title, author, sources, date range. |
| 2 | **Stats Dashboard** | Full-slide visual. Top row: 6 metric cards (2×3 grid) — big numbers, tiny labels. Bottom half: horizontal bar chart of commits-by-repo (sorted desc, ACCENT bars). |
| 3 | **Commit Heatmap** | Full-slide matplotlib area chart of commits-by-date. Fills ~80% of slide. Clean axes, grid, date labels on x-axis. Title: "Commit Activity". |
| 4 | **Work Distribution** | Two charts side-by-side (~45% each). Left: donut chart of `impact_areas` (ring, center = total PRs). Right: horizontal color-coded bar chart of `category_counts`. Title: "Where & What". |
| 5 | **Code Volume** | Full-slide grouped bar chart. Per repo: green bar (additions) up, red bar (deletions). Net change annotated above each group. Title: "Code Volume". |
| 6 | **Architecture** | Matplotlib repo-relationship diagram. Each repo as colored circle (size = commit count). Lines between repos if PRs reference both. Annotations for cross-repo patterns. Fallback if 1 repo: labeled circle with key stats. Skip if trivial. |
| 7–N | **PR Detail slides** (max 15, one per significant org PR) | Title 22pt (1 line). "What changed" 14pt max 15 words. "Why" 14pt italic SUCCESS max 15 words. Right side: category badge + impact area badge + merge date + +/- badge if stats available. If `screenshot_worthy`: large gray dashed placeholder (60% of slide, centered), "Screenshot: {hint}" in MUTED 14pt. |
| N+1… | **Deep Dive: [title] — Problem & Approach** | (One per highlight, max 3.) Title "Deep Dive: [title]" 22pt bold PRIMARY. Left 60%: "PROBLEM" label 9pt DANGER + text 12pt SECONDARY (~1.5" block); "APPROACH" label 9pt ACCENT + text 12pt SECONDARY. Right 40%: visual anchor. Skip if no highlights. |
| | **Deep Dive: [title] — What Changed** | Title "What Changed" 22pt bold PRIMARY. Subtitle "[title]" 14pt MUTED at y=0.85". Matched PRs from y=1.5": repo badge (ACCENT ROUNDED_RECTANGLE, 9pt white) + `what_changed` 14pt SECONDARY + `why` 12pt MUTED italic. 1-2 PRs: more detail. 3+ PRs: compact single-line. Screenshot placeholder at y=4.5"–6.8" if any PR is `screenshot_worthy`. |
| | **Deep Dive: [title] — Results & Impact** | Title "Results & Impact" 22pt bold PRIMARY. Subtitle "[title]" 14pt MUTED. "RESULT" label 9pt SUCCESS + text 14pt SECONDARY (3 sentences max). Visual anchor large, centered at (3", 3.5"), width 7". Screenshot placeholder bottom-right (x=8", y=5", w=4.6", h=2") if hint available. |
| | **Minor & Personal** | Two sections: "Minor Changes" table (title, repo, category — max 5 rows) and "Side Projects" table (title, repo, one-liner — max 5 rows). MUTED table styling. Skip if neither exists. |
| N+2 | **Open PRs** | Matplotlib horizontal bar chart. Each open PR as a bar, width = rough scope, colored by repo. Bar labels = short PR title (max 6 words). Title: "In Progress". Skip if none. |
| Last | **Links** | Compact URL reference. Repo name as small blue header, PR links as 9pt MUTED. Reference slide. |

---

## Visual Anchor Rendering

Used in executive Theme slides and technical Deep Dive slides (right-column):

- **`before_after`**: Two stacked ROUNDED_RECTANGLE — "Before" (RGBColor(0xFD,0xF2,0xF2) bg, DANGER text, "BEFORE" 9pt, value 22pt bold, detail 11pt MUTED, h=1.6") + "↓" 18pt MUTED centered + "After" (RGBColor(0xF0,0xFA,0xF4) bg, SUCCESS text, same layout)
- **`metric_callout`**: Single centered block — value 48pt bold ACCENT, label 14pt MUTED below
- **`count_cards`**: 2-3 ROUNDED_RECTANGLE side by side — bold number 24pt ACCENT, label 10pt MUTED
- **`evidence_list`** (fallback): Bulleted list, each item 12pt SECONDARY, bullet "•"

---

## Learning Visual Renders (matplotlib, top half of card)

- **`analogy`**: Two horizontal bars — red "before" (shorter) + green "after" (longer), with labels and values
- **`diagram`**: Horizontal flow — boxes connected by arrows, each box containing a step label
- **`quote_card`**: Large "\u201C" in ACCENT 72pt, quote text 16pt bold PRIMARY, attribution 11pt MUTED
- **`chart`**: Simple bar or line chart from `visual_data.labels` and `visual_data.values`

---

## Python Script Generation Pattern

Write script to `/tmp/weekly_review_gen.py`. Key implementation rules:

```python
# Imports
import json, os, sys, tempfile
import matplotlib
matplotlib.use('Agg')  # BEFORE importing pyplot
import matplotlib.pyplot as plt
from pptx import Presentation
from pptx.util import Inches, Pt, Emu
from pptx.dml.color import RGBColor
from pptx.enum.text import PP_ALIGN
from pptx.enum.shapes import MSO_SHAPE_TYPE

# Accept output directory
output_dir = sys.argv[1] if len(sys.argv) > 1 else "."

# Left accent bar on every slide
slide.shapes.add_shape(1, 0, 0, Inches(0.06), Inches(7.5))  # fill ACCENT, no border

# Charts: save to /tmp/*.png at 200 DPI, embed via slide.shapes.add_picture()
# Text truncation: titles 80 chars max, bullets 150 chars max
# Tables: cap at 10 rows per slide
# Print absolute paths of both output files on success
```

**Defensive chart rules — skip and replace with text/KPI card when:**
- Donut/pie with only 1 category
- Bar chart where all bars have same value or only 1 bar
- Area/line chart with 1 data point or flat line (all identical values)
- Any chart with 0 total data

**Matplotlib global style:**
```python
plt.rcParams.update({
    'font.family': 'sans-serif', 'font.size': 11,
    'axes.spines.top': False, 'axes.spines.right': False,
    'axes.edgecolor': '#E0E0E0', 'axes.labelcolor': '#34495E',
    'xtick.color': '#95A5A6', 'ytick.color': '#95A5A6',
    'figure.facecolor': 'white', 'axes.facecolor': 'white',
    'grid.color': '#F0F0F0', 'grid.linestyle': '-', 'grid.linewidth': 0.5,
})
```

**Execute:**
```bash
mkdir -p docs/gw
uv run --with python-pptx,matplotlib python /tmp/weekly_review_gen.py "OUTPUT_DIR"
# Fallback if uv unavailable:
python3 -m pip install python-pptx matplotlib && python3 /tmp/weekly_review_gen.py "OUTPUT_DIR"
```

If the script fails: show error, fix, retry once. If it fails again, offer HTML fallback.
