# Team Assembly Pattern

Shared logic for assembling a persona team. Used by: research, compete, review-app, saas-idea.

The calling skill provides: a team suggestion table mapping context (domain/app-type) to recommended personas.

## Load Workforce

GW_REPO must already be resolved. Read all persona files from:
1. `$GW_REPO/workforce/_defaults/*.md` — pre-shipped personas
2. `$GW_REPO/workforce/*.md` (excluding `_defaults/`) — user-added personas

Parse frontmatter from each: `name`, `background`, `perspective`, `priorities`, `debate_style`, `search_skills`.

If the calling skill is `/gw:review-app`, also parse: `analyze_slug`, `analyze_categories`, `analyze_tags`, `analyze_mandatory`, `analyze_skip_flag`.

## Suggest Team Composition

Use the calling skill's suggestion table to recommend the best subset. Devil's Advocate is **always** included. Custom personas are always shown as available additions.

## Approval Gate

**If TEAM_MODE is "auto" (default):** Skip the gate — auto-proceed with the suggested team. Print:

```
Team ({N} specialists): {Name1}, {Name2}, {Name3}, ... — auto-proceeding (use --team ask for interactive selection)
```

**If TEAM_MODE is "ask":** Show this format and wait:

```
{Context line from calling skill, e.g., 'Research: "question"' or 'Project: name'}
Domain/Type: {detected}

Suggested team ({N} specialists):
  1. {Name}  [recommended]  [{search_skills}]
  2. {Name}  [recommended]  [{search_skills}]
  ...

Also available:
  N. {Name}  [{search_skills}]
  ...

Accept [enter], resize [N], add by number [+N,N], customize [c], or create new [n]?
```

Options:
- **Accept:** proceed with suggested team
- **Resize [N]:** adjust team size (add/remove from relevance order)
- **Add [+N,N]:** add specific personas to the suggested team
- **Customize [c]:** show full roster, pick by number
- **Create new [n]:** create a new persona on-the-fly (see below)

If `--team N` was set, auto-size to N using the relevance order (still show for confirmation only if TEAM_MODE is "ask").

**APPROVAL GATE — Stop and wait for user confirmation before proceeding.**

## Handle "Create New" [n]

When the user selects `[n]` (only available in `--team ask` mode):

Initialize `CREATED_PERSONAS` as an empty list if not already set.

### N1 — Ask for name

Prompt: "New persona name?"

Slugify the response (lowercase, hyphens). Check for collisions:
- If `$GW_REPO/workforce/{slug}.md` exists (custom): offer "Use existing [u], rename [r], or overwrite [o]?"
- If `$GW_REPO/workforce/_defaults/{slug}.md` exists (default): offer "Use existing [u] or rename [r]?" (never overwrite defaults)

### N2 — Research the role

Launch 3 WebSearch queries in parallel:
1. `"{Name}" job role responsibilities skills`
2. `"{Name}" what do they focus on priorities`
3. `"{Name}" debate style perspective how they argue`

Auto-derive: `background`, `perspective`, `priorities`, `debate_style`, `search_skills` (3-5 source types).

If WebSearch fails: fall back to asking the user for each field.

### N3 — Present for approval

```
Auto-derived persona for "{Name}":
  name: {Name}
  background: {auto-derived}
  perspective: {auto-derived}
  priorities: {auto-derived}
  debate_style: {auto-derived}
  search_skills: {auto-derived}

Confirm [enter], edit [e], or cancel [x]?
```

For `/gw:review-app` only: also ask whether the persona should participate in analysis runs and prompt for `analyze_slug`, `analyze_categories`, and `analyze_tags`.

### N4 — Write persona file

```bash
mkdir -p "$GW_REPO/workforce"
```

Write `$GW_REPO/workforce/{slug}.md` with standard frontmatter. Append slug to `CREATED_PERSONAS` list.

### N5 — Add to team and return

Add the new persona to the selected team. Re-display the updated roster and return to the approval gate. User can accept, create another with `[n]`, or make other changes.
