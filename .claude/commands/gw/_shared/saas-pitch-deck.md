# SaaS Pitch Deck Generation

Pitch deck subagent prompt for Phase 4, Step 1 of gw:saas-idea.

---

Launch a single **foreground** Agent (subagent_type="general-purpose") with this prompt:

"You are a pitch deck designer. Read ALL deep-dive files from `.saas-ideas/deep-dive/`:
- `BUSINESS-PLAN.md`
- `MARKETING-PLAYBOOK.md`
- `TECH-SPEC.md`
- `IMPLEMENTATION-PROMPTS.md`

Generate a complete Python script that uses `python-pptx` to create a 10-slide investor pitch deck saved to `docs/gw/pitch-deck.pptx`.

**Design system:** Read and apply the canonical gw-skills palette from `$GW_REPO/.claude/commands/gw/_shared/pptx-design.md`.

- Font: Calibri throughout
- Slide dimensions: 16:9 widescreen (13.333" x 7.5")
- Accent bar: 0.06" wide ACCENT strip at left edge of every slide
- Layout: Title + subtitle top bar on each slide, content area with generous margins (at least 0.75" on all sides), slide numbers bottom-right

**10 slides:**

| # | Slide | Content |
|---|-------|---------|
| 1 | **Title** | Idea name (32pt bold, dark blue), tagline (18pt, accent blue), date (14pt, gray) centered on slide |
| 2 | **The Problem** | Pain point description with supporting market stats. Use bullet points with accent blue markers. Include a pull-quote style callout for the most compelling stat. |
| 3 | **The Solution** | What it does in one sentence (large text), then 3-4 key differentiators as icon-style bullet points |
| 4 | **Market Opportunity** | TAM/SAM/SOM as three nested rounded rectangles (largest to smallest), each labeled with dollar amounts. Source data from BUSINESS-PLAN.md market analysis. |
| 5 | **Business Model** | Pricing tiers as a comparison table (light gray alternating rows). Revenue projections note below. |
| 6 | **Competitive Landscape** | 2x2 positioning matrix with axes labeled. Place competitors and the product as positioned shapes. Source from BUSINESS-PLAN.md competitive analysis. |
| 7 | **Go-to-Market** | Launch strategy as a horizontal timeline with 4-5 phases. Each phase is a rounded rectangle with title and key action. Source from MARKETING-PLAYBOOK.md. |
| 8 | **Tech Architecture** | Stack diagram showing frontend/backend/infra layers as stacked rounded rectangles. Highlight: PostgreSQL, Google OAuth, Stripe, AWS, Terraform. MVP timeline as bullet points. Include note: 'AI-accelerated development → deployed at {app-name}.codingandmore.net'. Source from TECH-SPEC.md. |
| 9 | **Traction Plan** | Month-by-month growth targets for months 1-6 as a simple table. Key milestones highlighted in accent blue. |
| 10 | **The Ask / Next Steps** | What's needed to start — bullet points for resources, budget, timeline. Bold call-to-action at bottom. |

**Important Python implementation details:**
- Import `json`, `os`, `sys` at the top
- Use `from pptx import Presentation` and related imports from `python-pptx`
- Use `from pptx.util import Inches, Pt, Emu` and `from pptx.dml.color import RGBColor`
- Use `from pptx.enum.text import PP_ALIGN` and `from pptx.enum.shapes import MSO_SHAPE`
- Create helper functions: `add_title_bar(slide, title, subtitle)`, `add_slide_number(slide, num)`, `set_cell_style(cell, bold, color)`
- Each slide should be a separate function for clarity
- The script must be self-contained — read the markdown files, extract relevant content, and build all 10 slides
- Write the output file to `docs/gw/pitch-deck.pptx`
- Print the absolute path of the generated file on success

Write the script to `/tmp/saas_pitch_deck_gen.py`, then execute it.

**Execution chain:**

1. Try:
   ```bash
   mkdir -p docs/gw
   uv run --with python-pptx python3 /tmp/saas_pitch_deck_gen.py
   ```

2. If `uv` is not available or fails, fall back to:
   ```bash
   pip install python-pptx && python3 /tmp/saas_pitch_deck_gen.py
   ```

3. If both fail, generate an HTML file at `docs/gw/pitch-deck.html` instead with the same 10-slide content as a styled HTML presentation. Note the limitation to the user: 'Generated HTML pitch deck as fallback — python-pptx was not available.'

If the Python script fails: show the error output, examine the script for issues, fix, and retry once. If it fails again, fall back to HTML."
