---
name: workforce
description: Manage the shared workforce — hire, fire, edit, and list personas used by gw:compete, gw:research, gw:review-app, and gw:saas-idea
argument-hint: "[--hire \"Name\" --background \"...\"] [--fire \"Name\"] [--edit \"Name\"] [--roster] [--analyze-slug <slug>] [--analyze-categories \"...\"] [--analyze-tags \"...\"]"
---

## Step 0 — Preamble

Resolve the gw-skills repo path, then read and follow `$GW_REPO/.claude/commands/gw/_shared/preamble.md` for update check and GSD project detection:

```bash
GW_REPO="$(cd "$(readlink ~/.claude/commands/gw)/../../.." 2>/dev/null && pwd)" || GW_REPO="$HOME/.gw-skills"
```

GW_REPO persists for the duration of this skill run — do not re-resolve it in later steps.

---

## Step 1 — Parse Arguments & Route

You manage the shared persona workforce used by `/gw:compete`, `/gw:research`, `/gw:review-app`, and `/gw:saas-idea`. Follow these steps precisely.

Parse the arguments: "$ARGUMENTS"

- If `--hire "Name" --background "..."` is present, set HIRE_NAME and HIRE_BACKGROUND
- If `--fire "Name"` is present, set FIRE_NAME
- If `--edit "Name"` is present, set EDIT_NAME
- If `--roster` is present, set SHOW_ROSTER=true
- If no flags are provided, set SHOW_ROSTER=true (default action)

### Workflow routing

| Condition | Action |
|-----------|--------|
| `--hire` | Step 2 — Hire persona |
| `--fire` | Step 3 — Fire persona |
| `--edit` | Step 4 — Edit persona |
| `--roster` or no flags | Step 5 — Show roster |

---

## Step 2 — Hire Persona

1. Slugify the name (e.g., "Mass Spectrometrist" → `mass-spectrometrist`)
2. Check if `$GW_REPO/workforce/{slug}.md` already exists. If so, ask: "A persona named {Name} already exists. Overwrite [o] or rename [r]?" and wait.
   - If the user chooses **[o]**: overwrite the existing file.
   - If the user chooses **[r]**: ask for a new name and re-run the slugification. If the new name also collides, ask again (max 3 attempts). After 3 collisions, tell the user to use `--fire` to remove the existing persona first.
3. Create `$GW_REPO/workforce/{slug}.md` with this structure:

```
mkdir -p "$GW_REPO/workforce"
```

Write the file with frontmatter:
- `name`: from --hire flag
- `background`: from --background flag
- `perspective`: auto-derived from background (key concerns and viewpoint)
- `priorities`: auto-derived (what this persona cares most about)
- `debate_style`: auto-derived (how they argue and what evidence they cite)
- `search_skills`: auto-derived (3-5 comma-separated source types appropriate for this persona's domain, chosen from the source mapping table below)

If `--analyze-slug` is provided, also add these fields to the frontmatter:
- `analyze_slug`: from --analyze-slug flag
- `analyze_categories`: from --analyze-categories flag (required with --analyze-slug)
- `analyze_tags`: from --analyze-tags flag (default: "all")

These fields make the persona participate in `/gw:review-app` analysis runs.

### search_skills source types

Choose 3-5 from: `github`, `context7`, `arxiv`, `academic`, `google-scholar`, `pubmed`, `journals`, `stackoverflow`, `tech-blogs`, `api-docs`, `financial-data`, `sec-filings`, `market-reports`, `news`, `earnings-transcripts`, `reddit`, `forums`, `product-hunt`, `g2-reviews`, `cve-databases`, `owasp`, `cloud-docs`, `benchmarks`, `testing-resources`, `dribbble`, `design-blogs`, `figma-community`, `mdn`, `css-tricks`, `web-dev-resources`, `ux-research`, `nielsen-norman`, `trade-publications`, `youtube`, `counter-narrative-sources`, `methodology-guides`, `statistics-resources`

4. Print: "Hired {Name}. Available in all future `/gw:compete` and `/gw:research` runs."
5. Stop.

**Note:** Personas can also be created inline during skill runs (`/gw:compete`, `/gw:research`, `/gw:review-app`, `/gw:saas-idea`) when using `--team ask` mode. Select `[n]` at the team assembly approval gate to create a new persona on-the-fly — the skill will research the role via WebSearch, auto-derive persona fields, and add it to the team immediately.

---

## Step 3 — Fire Persona

1. Find matching file in `$GW_REPO/workforce/` (NOT `_defaults/`)
2. If the persona is in `_defaults/`: print "Can't fire default personas. They ship with the skill." and stop.
3. If no matching file found: print "No custom persona named '{Name}' found. Run `/gw:workforce --roster` to see all personas." and stop.
4. Delete the file.
5. Print: "Removed {Name} from workforce."
6. Stop.

---

## Step 4 — Edit Persona

1. Slugify the name and look for the file in `$GW_REPO/workforce/{slug}.md` first, then `$GW_REPO/workforce/_defaults/{slug}.md`.
2. If found in `_defaults/`: print "Can't edit default personas directly. Use `--hire` to create a custom version." and stop.
3. If not found anywhere: print "No persona named '{Name}' found. Run `/gw:workforce --roster` to see all personas." and stop.
4. Read the file and display the current frontmatter to the user.
5. Ask: "What would you like to change? (Edit the fields above, or type 'done' to finish.)"
6. Apply the user's requested changes to the frontmatter fields.
7. Print: "Updated {Name}."
8. Stop.

---

## Step 5 — Show Roster

Read all persona files from:
1. `$GW_REPO/workforce/_defaults/*.md` — pre-shipped personas
2. `$GW_REPO/workforce/*.md` (excluding `_defaults/`) — user-added personas

Parse frontmatter from each: `name`, `background`, `perspective`, `priorities`, `debate_style`, `search_skills`.

Display grouped by source. For personas that have `analyze_slug` set, show the slug and tags. Show skill participation badges indicating which skills use each persona.

```
Workforce Roster ({N} personas):

  Defaults:
  [default] Software Architect — System design, scalability, technical debt  [github, tech-blogs, context7, stackoverflow]
            [compete] [research] [analyze: architecture (web,server,cli,mobile,library,saas)]
  [default] Security Engineer — Auth, data protection, compliance            [cve-databases, owasp, github, tech-blogs]
            [compete] [research] [analyze: security (all, mandatory)]
  [default] UX Specialist — User flows, friction, accessibility              [ux-research, design-blogs, forums, reddit, nielsen-norman]
            [compete] [research] [analyze: usability (web,mobile,saas)]
  [default] SEO Specialist — Crawlability, indexability, Core Web Vitals     [mdn, web-dev-resources, tech-blogs, google-scholar]
            [analyze: seo (all, mandatory)]
  ...

  Custom:
  [custom]  Woodworker — Craftsmanship, ergonomics, "does it feel right"     [forums, reddit, trade-publications, youtube]
            [compete] [research]
  ...
```

Skill badges:
- `[compete]` — always shown for all personas (all can participate in competitive debates)
- `[research]` — always shown for all personas (all can participate in research)
- `[analyze: {slug} ({tags})]` — only shown if `analyze_slug` is set. Append ", mandatory" if `analyze_mandatory: true`
- `[saas]` — shown for personas used in saas-idea debates (Business Analyst, Financial Analyst, Product Manager, Devil's Advocate, Software Architect)

If no custom personas exist, show: "(no custom personas — use `/gw:workforce --hire \"Name\" --background \"...\"` to add one)"

End with:
```
---
Manage: --hire "Name" --background "..." | --fire "Name" | --edit "Name"
Inline: create new personas during any skill run with --team ask → [n]
Contribute: after creating inline, skills offer to PR the persona back to gw-skills defaults
Used by: /gw:compete, /gw:research, /gw:review-app, /gw:saas-idea
```

Stop.

---

## Error Handling

- **Workforce directory missing:** create it with `mkdir -p`
- **User tries to fire a default persona:** reject with explanation
- **`--hire` name conflicts with existing persona:** ask to overwrite or rename
- **`--edit` targets a default persona:** reject, suggest `--hire` to create custom version
- **No matching persona for `--fire` or `--edit`:** suggest `--roster`
