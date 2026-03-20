---
name: research
description: Multi-persona research with structured debate, parallel source investigation, and actionable output (report, PPTX, implementation, prototype)
argument-hint: "<question> [--standalone] [--deep] [--team auto|ask|N] [--skip-pptx] [--skip-gsd]"
---

## Step 0 — Update check

Resolve the gw-skills repo directory and run its update check script:

```bash
GW_REPO="$(cd "$(readlink ~/.claude/commands/gw)/../../.." 2>/dev/null && pwd)" || GW_REPO="$HOME/.gw-skills"
bash "$GW_REPO/check-update.sh" 2>/dev/null || true
```

If the output contains `UPDATE_AVAILABLE`, tell the user how many commits behind they are and ask: "gw-skills has updates available. Run /gw:update to install them, or continue?" If they want to update, invoke `/gw:update` and stop. Otherwise continue. If the script is missing or fails, skip silently.

---

## Step 0.5 — GSD Project Detection (Model Inheritance)

Skip this step if you are inside a GSD project (`~/.config/opencode/.planning/` exists).

If `.planning/config.json` exists in the current or parent directories:
1. Try to resolve and read its JSON content using Bash/Grep
2. Extract `model_profile` (default: "balanced")
3. If a profile is found, use it for all agent spawns instead of default Claude model
4. Log: "Using GSD model profile: {profile}" in the first output message

This enables gw skills to inherit opencode's model preferences within managed projects.

---

## Step 1 — Parse Arguments & Route

You are an orchestrator for multi-persona research investigations. You assemble a specialist team, run parallel research with persona-specific sources, conduct structured debate, and produce actionable output. Follow these steps precisely.

Parse the arguments: "$ARGUMENTS"

- The **research question** is everything in `$ARGUMENTS` that isn't a recognized flag. It can be quoted or unquoted.
- If `"--standalone"` is present, set FORCE_STANDALONE=true
- If `"--deep"` is present, set DEEP_RESEARCH=true. Default: false
- If "--team N|auto|ask" is present: if N is a number, set TEAM_MODE=auto and TEAM_SIZE_OVERRIDE=N (clamped to 3-10). If "auto", set TEAM_MODE=auto. If "ask", set TEAM_MODE=ask. Default TEAM_MODE: auto
- If `"--skip-pptx"` is present, set SKIP_PPTX=true
- If `"--skip-gsd"` is present, set SKIP_GSD=true
- If `"--hire"`, `"--fire"`, or `"--roster"` is present: tell the user "Use `/gw:workforce` for persona management. Examples: `/gw:workforce --hire \"Name\" --background \"...\"`, `/gw:workforce --fire \"Name\"`, `/gw:workforce --roster`" and stop.

If no research question is provided and no workforce management flag is set, ask: "What would you like to research?" and wait.

### Workflow routing

| Condition | Steps executed |
|-----------|----------------|
| Default (full run) | 0 → 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 |
| `--hire/--fire/--roster` | 0 → 1 (redirect to `/gw:workforce`) |
| `--skip-pptx` | Skip PPTX in Step 7 |
| `--skip-gsd` | Skip GSD in Step 7 |

**Approval gates** (stop and wait for user confirmation):
- After Step 2 — confirm research context and domain classification
- After Step 3 — confirm team composition before spawning research agents
- After Step 5 — confirm consensus before output action

---

## Step 2 — Context Detection & Domain Classification

### 2a. Detect project context

Check for project signals by globbing in parallel:
- `package.json`, `pyproject.toml`, `requirements.txt`, `go.mod`, `Cargo.toml`, `*.tf`, `Dockerfile`
- `README.md`, `CLAUDE.md`
- `.planning/PROJECT.md` (GSD project)

If **any** project files exist AND `FORCE_STANDALONE` is not set:
- Set MODE=PROJECT_CONTEXTUAL
- Read README.md and CLAUDE.md if they exist (in parallel)
- Build PROJECT_CONTEXT: project name, detected stack, key file paths (keep under 200 words)

If **no** project files exist OR `FORCE_STANDALONE` is set:
- Set MODE=STANDALONE

### 2b. Classify research domain

Analyze the research question keywords to classify RESEARCH_DOMAIN:

| Keywords / Signals | RESEARCH_DOMAIN |
|---|---|
| API, architecture, framework, library, code, algorithm, distributed, microservice, database | **engineering** |
| market, revenue, business model, pricing, TAM, growth, competition, go-to-market | **business** |
| paper, study, literature, hypothesis, methodology, systematic review, meta-analysis | **academic** |
| investment, valuation, DCF, equity, bonds, portfolio, risk-adjusted, financial model | **financial** |
| experiment, physics, chemistry, biology, genome, molecule, quantum, climate, energy | **science** |
| UX, UI, design system, accessibility, user flow, wireframe, prototype, usability | **design** |
| *(no strong signal)* | **general** |

### 2c. Slugify and set up output directory

Slugify the research question:
- Lowercase, replace spaces/special chars with hyphens, truncate to 60 chars
- Example: "What is the best approach to real-time data sync?" → `best-approach-real-time-data-sync`

Set RESEARCH_DIR=`.research/YYYY-MM-DD-{slug}`

Check if RESEARCH_DIR already exists:
- If yes, ask: "Previous research found at `{RESEARCH_DIR}/`. Re-use findings [enter], start fresh [f], or pick a different question [q]?"
  - **[enter]:** Load existing agent outputs and skip to Step 5
  - **[f]:** Delete existing directory and continue fresh
  - **[q]:** Ask for a new question and restart Step 2

If it doesn't exist, create it:
```bash
mkdir -p "{RESEARCH_DIR}/agents" "{RESEARCH_DIR}/debate"
```

### 2d. Present context

Show this summary and wait for confirmation:

```
Research Question: {QUESTION}
Domain: {RESEARCH_DOMAIN}
Mode: {PROJECT_CONTEXTUAL|STANDALONE}
Depth: {lightweight|deep}
Output: {RESEARCH_DIR}/

{If PROJECT_CONTEXTUAL: "Project: {name} ({stack})"}

Proceed [enter], change domain [d], or edit question [e]?
```

**APPROVAL GATE — Stop and wait for user confirmation before proceeding to Step 3.**

---

## Step 3 — Team Assembly

### 3a. Load workforce

Resolve the gw-skills repo path (same pattern as Step 0):

```bash
GW_REPO="$(cd "$(readlink ~/.claude/commands/gw)/../../.." 2>/dev/null && pwd)" || GW_REPO="$HOME/.gw-skills"
```

Read all persona files from:
1. `$GW_REPO/workforce/_defaults/*.md` — pre-shipped personas
2. `$GW_REPO/workforce/*.md` (excluding `_defaults/`) — user-added personas

Parse frontmatter from each: `name`, `background`, `perspective`, `priorities`, `debate_style`, `search_skills`.

### 3b. Suggest team composition

Based on RESEARCH_DOMAIN, suggest the best subset. Devil's Advocate is **always** included.

| RESEARCH_DOMAIN | Suggested Team |
|-----------------|---------------|
| engineering | Software Architect, Backend Engineer, Literature Reviewer, Devil's Advocate, Domain Expert |
| business | Business Analyst, Financial Analyst, Product Manager, Devil's Advocate, Domain Expert |
| academic | Literature Reviewer, Methodologist, Statistician, Devil's Advocate, Domain Expert |
| financial | Financial Analyst, Business Analyst, Statistician, Devil's Advocate, Data Scientist |
| science | Physicist, Literature Reviewer, Methodologist, Statistician, Devil's Advocate |
| design | UX Specialist, UI Designer, End User Advocate, Devil's Advocate, Product Manager |
| general | Literature Reviewer, Devil's Advocate, Domain Expert, Software Architect, Business Analyst |

Custom personas are always shown as available additions.

### 3c. Approval gate

**If TEAM_MODE is "auto" (default):** Skip the gate — auto-proceed with the suggested team. Print a brief summary:

```
Team ({N} specialists): {Name1}, {Name2}, {Name3}, ... — auto-proceeding (use --team ask for interactive selection)
```

**If TEAM_MODE is "ask":** Show this exact format and wait for user confirmation:

```
Research: "{QUESTION}"
Domain: {RESEARCH_DOMAIN}

Suggested team ({N} specialists):
  1. Literature Reviewer     [recommended]  [arxiv, academic, google-scholar, pubmed, journals]
  2. Devil's Advocate        [recommended]  [forums, reddit, news, counter-narrative-sources]
  3. Domain Expert           [recommended]  [academic, journals, trade-publications, forums, context7]
  ...

Also available:
  7. Software Architect                     [github, tech-blogs, context7, stackoverflow]
  8. Woodworker (custom)                    [forums, reddit, trade-publications, youtube]
  ...

Accept [enter], resize [N], add by number [+7,8], customize [c], or create new [n]?
```

Options:
- **Accept:** proceed with suggested team
- **Resize [N]:** adjust team size (add/remove from relevance order)
- **Add [+N,N]:** add specific personas to the suggested team
- **Customize [c]:** show full roster, pick by number
- **Create new [n]:** create a new persona on-the-fly (see below)

If `--team N` was set, auto-size to N using the relevance order (still show for confirmation only if TEAM_MODE is "ask").

**APPROVAL GATE — Stop and wait for user confirmation before proceeding to Step 4.**

### Handle "create new" [n]

When the user selects `[n]` at the approval gate (only available in `--team ask` mode), run this inline persona creation sub-flow:

Initialize `CREATED_PERSONAS` as an empty list if not already set.

#### Step N1 — Ask for name

Prompt the user: "New persona name?"

Slugify the response (lowercase, hyphens, e.g., "Mass Spectrometrist" → `mass-spectrometrist`). Check for collisions:

- If `$GW_REPO/workforce/{slug}.md` exists (custom): offer "Use existing [u], rename [r], or overwrite [o]?"
  - **[u]:** add the existing persona to the team and return to the approval gate
  - **[r]:** ask for a new name, re-slugify, re-check
  - **[o]:** proceed to Step N2 (will overwrite)
- If `$GW_REPO/workforce/_defaults/{slug}.md` exists (default): offer "Use existing [u] or rename [r]?" (never overwrite defaults)

#### Step N2 — Research the role

Launch 3 WebSearch queries in parallel:
1. `"{Name}" job role responsibilities skills`
2. `"{Name}" what do they focus on priorities`
3. `"{Name}" debate style perspective how they argue`

From the results, auto-derive:
- `background` — professional background summary (1-2 sentences)
- `perspective` — key concerns and viewpoint
- `priorities` — what this persona cares most about
- `debate_style` — how they argue and what evidence they cite
- `search_skills` — 3-5 source types from the search_skills reference list, appropriate for this persona's domain

If WebSearch fails or returns insufficient results: fall back to asking the user to provide each field manually.

#### Step N3 — Present for approval

Display the auto-derived persona:

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

- **[enter]:** accept and proceed to Step N4
- **[e]:** show each field for individual editing, re-display, re-prompt
- **[x]:** cancel creation, return to the approval gate without changes

#### Step N4 — Write persona file

```bash
mkdir -p "$GW_REPO/workforce"
```

Write `$GW_REPO/workforce/{slug}.md` with standard frontmatter (name, background, perspective, priorities, debate_style, search_skills).

Append the slug to the `CREATED_PERSONAS` list.

#### Step N5 — Add to team and return to gate

Add the new persona to the selected team. Re-display the updated team roster and return to the approval gate prompt. The user can accept the team, create another persona with `[n]`, or make other changes.

---

## Step 4 — Parallel Research

Launch one background agent per persona in a SINGLE message using the Agent tool with `run_in_background=true` and `subagent_type="general-purpose"`.

### search_skills → Source Mapping Table

Each persona's `search_skills` field determines which sources they prioritize. The agent prompt must include source-specific search instructions based on their skills:

| search_skill | Search Strategy |
|---|---|
| `github` | WebSearch for GitHub repos, issues, discussions relevant to the question |
| `context7` | Use `resolve-library-id` + `query-docs` for any libraries/frameworks mentioned in the question |
| `arxiv` | WebSearch `site:arxiv.org` for papers related to the question |
| `academic` | WebSearch for academic papers, Google Scholar results, university publications |
| `google-scholar` | WebSearch `site:scholar.google.com` or `"cited by"` patterns for the topic |
| `pubmed` | WebSearch `site:pubmed.ncbi.nlm.nih.gov` for biomedical/life science papers |
| `journals` | WebSearch for peer-reviewed journal articles (Nature, Science, IEEE, ACM, etc.) |
| `stackoverflow` | WebSearch `site:stackoverflow.com` for technical Q&A on the topic |
| `tech-blogs` | WebSearch for technical blog posts, engineering blogs (Netflix, Uber, Stripe, etc.) |
| `api-docs` | WebSearch for official API documentation and developer guides |
| `financial-data` | WebSearch for financial data, market analysis, Bloomberg/Reuters summaries |
| `sec-filings` | WebSearch `site:sec.gov` for SEC filings, 10-K, 10-Q reports |
| `market-reports` | WebSearch for market research reports (Gartner, Forrester, McKinsey, etc.) |
| `news` | WebSearch for recent news articles from major outlets |
| `earnings-transcripts` | WebSearch for quarterly earnings call transcripts |
| `reddit` | WebSearch `site:reddit.com` for community discussions and opinions |
| `forums` | WebSearch for forum discussions, community posts, Stack Exchange sites |
| `product-hunt` | WebSearch `site:producthunt.com` for product launches and reviews |
| `g2-reviews` | WebSearch `site:g2.com` for software reviews and comparisons |
| `cve-databases` | WebSearch `site:cve.mitre.org` or `site:nvd.nist.gov` for vulnerability data |
| `owasp` | WebSearch `site:owasp.org` for security guidelines and checklists |
| `cloud-docs` | WebSearch for AWS/GCP/Azure official documentation |
| `benchmarks` | WebSearch for performance benchmarks, comparison tests |
| `testing-resources` | WebSearch for testing methodology guides, framework docs |
| `dribbble` | WebSearch `site:dribbble.com` for design inspiration and patterns |
| `design-blogs` | WebSearch for design blogs (Smashing Magazine, A List Apart, etc.) |
| `figma-community` | WebSearch `site:figma.com/community` for design templates and systems |
| `mdn` | WebSearch `site:developer.mozilla.org` for web standards documentation |
| `css-tricks` | WebSearch `site:css-tricks.com` for web design techniques |
| `web-dev-resources` | WebSearch for web.dev, Can I Use, and web platform guides |
| `ux-research` | WebSearch for UX research studies, usability reports |
| `nielsen-norman` | WebSearch `site:nngroup.com` for UX research and guidelines |
| `trade-publications` | WebSearch for industry-specific trade publications and magazines |
| `youtube` | WebSearch `site:youtube.com` for tutorials, talks, demonstrations |
| `counter-narrative-sources` | WebSearch for contrarian viewpoints, critique articles, "problems with {topic}" |
| `methodology-guides` | WebSearch for research methodology handbooks, best practice guides |
| `statistics-resources` | WebSearch for statistics tutorials, methodology papers, statistical software docs |

### Agent Prompt Template

For each persona on the team, launch an agent with the following prompt (substituting the placeholders):

```
You are {PERSONA_NAME}, a research specialist with the following profile:
- Background: {PERSONA_BACKGROUND}
- Perspective: {PERSONA_PERSPECTIVE}
- Priorities: {PERSONA_PRIORITIES}
- Search Skills: {PERSONA_SEARCH_SKILLS}

## Research Question

{RESEARCH_QUESTION}

## Research Context

Mode: {PROJECT_CONTEXTUAL|STANDALONE}
Domain: {RESEARCH_DOMAIN}
Depth: {lightweight|deep}
{If PROJECT_CONTEXTUAL: "Project Context: {PROJECT_CONTEXT}"}

## Your Research Task

Investigate the research question from YOUR specialist perspective using YOUR designated sources.

### Source-Specific Instructions

For each of your search skills, perform targeted research:

{For each skill in PERSONA_SEARCH_SKILLS, include the corresponding search strategy from the mapping table above}

### LIGHTWEIGHT TASKS (always perform these)

1. Use your search skills to find 5-10 high-quality sources related to the research question.
2. WebFetch the top 3-5 most relevant pages from your search results.
3. Extract and organize:
   - Key findings relevant to the research question (with source URLs)
   - Areas of consensus in your sources
   - Areas of disagreement or uncertainty
   - Practical implications or recommendations
   - Gaps in available information

### DEEP TASKS (only if depth=deep)

4. Expand your search to 10-20 sources, including less obvious or contrarian viewpoints.
5. WebFetch an additional 3-5 pages for deeper context.
6. Additionally extract:
   - Historical context and evolution of thinking on this topic
   - Edge cases, exceptions, or conditions where common wisdom fails
   - Quantitative data, statistics, or metrics where available
   - Expert opinions with attribution
   - Predictions or emerging trends

## RULES

- Be thorough but strictly factual — cite a source URL for every claim.
- Clearly distinguish **confirmed/well-sourced** findings from **speculative** or **single-source** claims.
- Stay in character — analyze everything through your specialist lens.
- Note the retrieval date for all sources.
- If a search or fetch fails, retry once, then note "source unavailable" and continue with what you have.

## OUTPUT

Write your findings to: `{RESEARCH_DIR}/agents/{PERSONA_SLUG}.md`

Use this exact format:

---
persona: {PERSONA_NAME}
question: {RESEARCH_QUESTION}
domain: {RESEARCH_DOMAIN}
date: {TODAY_DATE}
depth: {lightweight|deep}
sources_count: {N}
---

# Research Findings: {PERSONA_NAME}

## Executive Summary

{2-3 sentence summary of your key findings from your specialist perspective}

## Key Findings

### Finding 1: {Title}
{Description with evidence and source citations}
- **Source:** {URL}
- **Confidence:** {High|Medium|Low}

### Finding 2: {Title}
{Description}
- **Source:** {URL}
- **Confidence:** {High|Medium|Low}

(continue for all findings)

## Areas of Consensus

- {Point where multiple sources agree} — Sources: {URL1}, {URL2}

## Areas of Disagreement

- {Point where sources conflict} — {Source A says X}, {Source B says Y}

## Practical Implications

From my perspective as {PERSONA_NAME}:
1. {Implication or recommendation}
2. {Implication or recommendation}

## Knowledge Gaps

- {What we don't know or couldn't find}

## Sources

| # | Title | URL | Type | Retrieved |
|---|-------|-----|------|-----------|
| 1 | {title} | {url} | {type} | {date} |
```

### Rate Limit Guard

If any WebSearch or WebFetch call returns an error (rate limit, timeout, or access denied):
1. Retry once after a short backoff (~5 seconds).
2. If the retry also fails, note `"source unavailable — {reason}"` in the output file and continue writing whatever was collected so far.
3. Do not abort the entire research run due to a single tool failure.

### Collection

After all background agents complete, verify that each expected research file exists at `{RESEARCH_DIR}/agents/*.md`. Print a status table:

```
Research Status:
  [done] literature-reviewer.md   (8 findings, 12 sources)
  [done] devils-advocate.md       (6 findings, 9 sources)
  [done] domain-expert.md         (7 findings, 11 sources)
  [FAILED] statistician.md        (research incomplete — rate limited)
```

For any `[FAILED]` entries, offer: "Retry failed research? [y/n]" — if yes, re-launch only the failed agents. Max 2 retries per failed agent. After 2 failures for the same agent, continue with available reports.

---

## Step 5 — Structured Debate

Three rounds with the assembled team.

### Round 1 — Position Statements

Launch all team agents in parallel (`run_in_background=true`). Each agent gets a prompt with:
- Their persona details (name, background, perspective, priorities, debate_style)
- The research question and domain
- Instruction to read their own research file from `{RESEARCH_DIR}/agents/{PERSONA_SLUG}.md`
- Tasks: formulate a position on the research question, identify top 3-5 conclusions, flag uncertainties, propose recommendations
- Output to `{RESEARCH_DIR}/debate/round1/{PERSONA_SLUG}.md`

Agent prompt template:

```
You are {PERSONA_NAME}, a specialist with the following profile:
- Background: {PERSONA_BACKGROUND}
- Perspective: {PERSONA_PERSPECTIVE}
- Priorities: {PERSONA_PRIORITIES}
- Debate style: {PERSONA_DEBATE_STYLE}

## Research Question

{RESEARCH_QUESTION}

## Your Research

Read your research findings at: `{RESEARCH_DIR}/agents/{PERSONA_SLUG}.md`

## Your Task

Based on your research findings and specialist perspective:

1. Formulate your **position** on the research question — what is the answer or best approach?
2. Identify your **top 3-5 conclusions** ranked by confidence and importance.
3. Flag **uncertainties** — where your evidence is weak or conflicting.
4. Propose **concrete recommendations** — what should be done based on your findings?
5. Identify **risks** — what could go wrong if your recommendations are followed?

## Output

Write your position to: `{RESEARCH_DIR}/debate/round1/{PERSONA_SLUG}.md`

Use this format:

---
persona: {PERSONA_NAME}
round: 1
date: {TODAY_DATE}
---

# Round 1 — Position Statement: {PERSONA_NAME}

## Position

{Your overall position on the research question — 2-3 paragraphs}

## Top Conclusions

1. **{Conclusion}** (Confidence: {High|Medium|Low})
   - **Evidence:** {supporting evidence from your research}

2. **{Conclusion}** (Confidence: {High|Medium|Low})
   - **Evidence:** {supporting evidence}

3. **{Conclusion}** (Confidence: {High|Medium|Low})
   - **Evidence:** {supporting evidence}

(up to 5 conclusions)

## Uncertainties

- {Area of uncertainty and why}

## Recommendations

1. {Concrete recommendation with rationale}
2. {Concrete recommendation with rationale}

## Risks

- {Risk if recommendations are followed, and mitigation}
```

After all agents complete, verify each file exists at `{RESEARCH_DIR}/debate/round1/{PERSONA_SLUG}.md`.

### Round 2 — Cross-Examination & Devil's Advocate

The supervisor (orchestrator itself, acting as a foreground step) reads all Round 1 positions. Identifies:
- Top 3-5 **disagreements** — areas where personas reached different conclusions
- Top 2-3 **blind spots** — things only one persona mentioned that others overlooked
- For the Devil's Advocate specifically: the strongest consensus point to challenge

Then launch all team agents again in parallel (`run_in_background=true`) with a prompt containing:
- Their persona details
- All colleagues' Round 1 positions (concatenated)
- The identified disagreements and blind spots
- A specific devil's advocate challenge targeting THIS persona's Round 1 stance
- Tasks: respond to disagreements, defend or update position, engage with the devil's advocate challenge
- Output to `{RESEARCH_DIR}/debate/round2/{PERSONA_SLUG}.md`

Agent prompt template:

```
You are {PERSONA_NAME}, a specialist with the following profile:
- Background: {PERSONA_BACKGROUND}
- Perspective: {PERSONA_PERSPECTIVE}
- Priorities: {PERSONA_PRIORITIES}
- Debate style: {PERSONA_DEBATE_STYLE}

## Research Question

{RESEARCH_QUESTION}

## Your Round 1 Position

(Your Round 1 file content is included below for reference.)

{ROUND1_POSITION}

## Your Colleagues' Round 1 Positions

{CONCATENATED_ROUND1_POSITIONS_OF_ALL_OTHER_PERSONAS}

## Key Disagreements Identified by the Supervisor

{NUMBERED_LIST_OF_TOP_3_TO_5_DISAGREEMENTS}

## Blind Spots Identified

{NUMBERED_LIST_OF_BLIND_SPOTS}

## Devil's Advocate Challenge (for you specifically)

{TARGETED_CHALLENGE_ARGUING_AGAINST_THIS_PERSONAS_ROUND1_STANCE}

## Your Task

1. Respond to the key disagreements above. Do you hold your position or update it? Be specific.
2. Address the devil's advocate challenge directed at you. Rebut, concede, or refine your stance.
3. Respond to the blind spots — did you overlook something important?
4. Note if any colleague made an argument that genuinely changed your thinking (and explain how).
5. If you are updating your conclusions or recommendations, state the updated versions explicitly.

## Output

Write your response to: `{RESEARCH_DIR}/debate/round2/{PERSONA_SLUG}.md`

Use this format:

---
persona: {PERSONA_NAME}
round: 2
date: {TODAY_DATE}
---

# Round 2 — Cross-Examination: {PERSONA_NAME}

## Response to Disagreements

### Disagreement 1: {Topic}
{Your response — hold, concede, or refine}

### Disagreement 2: {Topic}
{Your response}

(continue for each disagreement)

## Response to Devil's Advocate Challenge

{Your rebuttal or concession}

## Blind Spots Addressed

- {What you missed and how it changes your analysis}

## Mind Changes

- {Conclusion or recommendation you updated, and why} (or "None — I hold my Round 1 position.")

## Updated Conclusions (if changed)

(List only if your conclusions changed from Round 1; otherwise write "Unchanged.")
```

### Round 3 — Supervisor Synthesis

A single foreground supervisor agent reads ALL Round 1 + Round 2 files and the original research files, then writes `{RESEARCH_DIR}/CONSENSUS.md`:

```markdown
# Research Consensus

**Question:** {RESEARCH_QUESTION}
**Date:** {date}
**Domain:** {RESEARCH_DOMAIN}
**Team:** {N} specialists, 2 debate rounds
**Mode:** {PROJECT_CONTEXTUAL|STANDALONE}
**Disagreements examined:** {N}

## Executive Summary

{3-5 sentences: the answer to the research question, confidence level, key caveats}

## Consensus Findings

### Finding 1: {Title}
- **Conclusion:** {what the team agrees on}
- **Confidence:** {High|Medium|Low}
- **Supporting personas:** {who agreed}
- **Evidence:** {key sources}

### Finding 2: {Title}
(same format)

(continue for all consensus findings)

## Contested Findings

### {Topic}
- **Position A:** {view} — supported by {personas}
- **Position B:** {view} — supported by {personas}
- **Resolution:** {supervisor's assessment of which position is stronger, and why}

## Key Uncertainties

- {What remains unknown, and what additional research would help}

## Recommendations

### Tier 1: High Confidence (act on these)
1. {Recommendation with rationale}
2. {Recommendation}

### Tier 2: Moderate Confidence (consider these)
1. {Recommendation}

### Tier 3: Speculative (investigate further)
1. {Recommendation}

## Devil's Advocate Summary

{What the Devil's Advocate challenged, what survived scrutiny, what didn't}

## Supervisor's Assessment

{Narrative synthesis: the answer to the research question, how confident we should be,
what would change the answer, and what to do next. Explicitly notes where the supervisor
overruled minority positions and why.}
```

Present a brief summary of the consensus to the user before proceeding.

---

## Step 6 — Output Action Dialog

Present the research findings summary and ask what to do:

```
Research Complete: "{RESEARCH_QUESTION}"

Team: {N} specialists across {N} sources
Consensus: {brief 1-line summary}
Confidence: {High|Medium|Low}

What would you like to do with the findings?

  1. PowerPoint   — presentation with findings and recommendations
  2. Report       — detailed Markdown report (optional .docx via pandoc)
  3. Implement    — create GSD project from recommendations {only if MODE=PROJECT_CONTEXTUAL}
  4. Prototype    — standalone script/code demonstrating the recommended approach
  5. Custom       — describe what you want

Pick one or more [1,2], or done [d]?
```

If MODE=STANDALONE, hide option 3 (Implement) unless the user explicitly asks for it.

**APPROVAL GATE — Stop and wait for user selection before proceeding to Step 7.**

---

## Step 7 — Execute Output Action

Execute the user's chosen action(s). If multiple were selected, execute them sequentially.

### Option 1: PowerPoint

Skip if SKIP_PPTX is true.

#### 7a-pptx. Build JSON data file

Write `/tmp/research_presentation_data.json` with all data extracted from CONSENSUS.md, agent research files, and debate files. Include:
- Research question, domain, date, team composition
- Executive summary
- All consensus findings with confidence levels
- Contested findings with positions
- Recommendations by tier
- Key uncertainties
- Source count and retrieval stats

#### 7a-pptx. Write and execute Python script

Write `/tmp/research_presentation.py` — reads the JSON data file and generates a `.pptx` presentation.

**Design system** (canonical gw-skills palette):
```
PRIMARY      = RGBColor(0x2C, 0x3E, 0x50)  # dark blue-gray — titles, headers
SECONDARY    = RGBColor(0x34, 0x49, 0x5E)  # medium blue-gray — body text
ACCENT       = RGBColor(0x34, 0x98, 0xDB)  # bright blue — highlights, KPIs
SUCCESS      = RGBColor(0x27, 0xAE, 0x60)  # green — high confidence, consensus
DANGER       = RGBColor(0xE7, 0x4C, 0x3C)  # red — low confidence, risks
WARNING      = RGBColor(0xF3, 0x9C, 0x12)  # amber — moderate confidence, contested
MUTED        = RGBColor(0x95, 0xA5, 0xA6)  # gray — captions, labels
BG_WHITE     = RGBColor(0xFF, 0xFF, 0xFF)
BG_LIGHT     = RGBColor(0xF8, 0xF9, 0xFA)
```

Font: Calibri throughout. Slide dimensions: 16:9 widescreen (13.333" x 7.5"). Accent bar: 0.06" wide ACCENT strip at left edge of every slide.

**Slide structure:**

| # | Slide | Content |
|---|-------|---------|
| 1 | Title | Research question, domain badge, date, team size |
| 2 | Executive Summary | Answer to the question, key stats as KPI cards (N specialists, N sources, N findings, confidence level) |
| 3 | Methodology | Team composition table with persona names and search_skills, research depth |
| 4 | Consensus Findings | Green cards for high-confidence findings, amber for moderate, with evidence summaries |
| 5 | Contested Findings | Side-by-side Position A vs Position B cards with persona names |
| 6 | Key Uncertainties | What remains unknown, organized by impact level |
| 7 | Recommendations | Tiered recommendation cards: Tier 1 (green), Tier 2 (amber), Tier 3 (gray) with rationale |
| 8 | Devil's Advocate | What was challenged, what survived, what didn't — builds credibility |
| 9 | Closing | "Full report: `{RESEARCH_DIR}/CONSENSUS.md`", date, "Generated by gw:research" |

**Execution:**
```bash
mkdir -p docs/gw
uv run --with python-pptx python /tmp/research_presentation.py
```

Fallback: `python3 -m pip install python-pptx && python3 /tmp/research_presentation.py`

If both fail: "PowerPoint generation failed — python-pptx is required. Install it with `pip install python-pptx` or use `--skip-pptx` to skip presentation generation." Do not generate an HTML fallback.

**Output:** `docs/gw/research-{slug}-YYYY-MM-DD.pptx`

Tell the user where the file was saved.

### Option 2: Report

Launch a single foreground synthesis agent (`subagent_type="general-purpose"`) that reads all artifacts:
- `{RESEARCH_DIR}/agents/*.md`
- `{RESEARCH_DIR}/debate/round1/*.md`
- `{RESEARCH_DIR}/debate/round2/*.md`
- `{RESEARCH_DIR}/CONSENSUS.md`

Writes `{RESEARCH_DIR}/REPORT.md`:

```markdown
# Research Report

**Question:** {RESEARCH_QUESTION}
**Date:** {date}
**Domain:** {RESEARCH_DOMAIN}
**Team:** {N} specialists, 2 debate rounds, {N} total sources
**Depth:** {lightweight|deep}
**Mode:** {PROJECT_CONTEXTUAL|STANDALONE}

## Executive Summary

{3-5 sentences summarizing the answer, confidence, and key recommendations}

## Background

{Why this question matters, what context drove the investigation}

## Methodology

### Research Team

| Persona | Background | Search Skills | Sources Found |
|---------|-----------|---------------|---------------|
| {name} | {background} | {search_skills} | {N} |

### Research Process

1. Parallel source investigation across {N} specialists
2. Structured debate (3 rounds with devil's advocate)
3. Supervisor synthesis and consensus building

## Findings

### Consensus Findings

{Detailed write-up of each finding with evidence, organized by confidence}

### Contested Findings

{Each disagreement with both sides presented fairly, supervisor resolution}

## Analysis

### Strengths of Evidence

{Where the evidence is strong and why}

### Weaknesses and Gaps

{Where the evidence is weak, missing, or conflicting}

### Devil's Advocate Assessment

{Summary of challenges raised, which conclusions survived, which were weakened}

## Recommendations

### Immediate Actions (High Confidence)

1. {Recommendation with full rationale and supporting evidence}

### Consider (Moderate Confidence)

1. {Recommendation}

### Investigate Further (Low Confidence)

1. {What needs more research and why}

## Appendices

### A. Source Index

{Complete table of all sources across all personas with URLs}

### B. Debate Transcript Summary

{Key exchanges from the debate rounds}
```

After writing REPORT.md, check if `pandoc` is available:
```bash
command -v pandoc
```

If pandoc exists, offer: "Convert report to .docx? [y/n]"
If yes:
```bash
pandoc "{RESEARCH_DIR}/REPORT.md" -o "{RESEARCH_DIR}/REPORT.docx" --reference-doc=/dev/null 2>/dev/null || pandoc "{RESEARCH_DIR}/REPORT.md" -o "{RESEARCH_DIR}/REPORT.docx"
```

Tell the user where the file(s) were saved.

### Option 3: Implement

Skip if SKIP_GSD is true or MODE=STANDALONE (unless user explicitly requests).

#### 3a. Generate project files

Ask the user:

```
Generate project files for implementation?

This will create:
  - CLAUDE.md — project context, tech stack, constraints, recommended skills
  - SPEC.md  — requirements, user flows, data model, success criteria

Source: {RESEARCH_DIR}/CONSENSUS.md + agent research

Generate and choose workflow [y], or go straight to GSD [g], or skip [n]?
```

**If [n]:** Skip to existing GSD flow in 3c.

**If [g]:** Skip to 3c (GSD integration) directly.

**If [y]:** Generate both files:

**Generate `{RESEARCH_DIR}/CLAUDE.md`:**

Read `{RESEARCH_DIR}/CONSENSUS.md` and the agent research files. Write `{RESEARCH_DIR}/CLAUDE.md` with this structure:

````markdown
<!-- Generated by gw:research on {date} from {RESEARCH_DIR}/CONSENSUS.md -->

# {Project Name from PROJECT_CONTEXT or research question slug}

## What This Is
{From CONSENSUS.md Executive Summary — 2-3 sentences describing what to build}

## Tech Stack
{From CONSENSUS.md Recommendations — extract technology choices. List each technology with one-line rationale.}

## Architecture
{From CONSENSUS.md — key architectural decisions and patterns recommended}

## Constraints
{From CONSENSUS.md Key Uncertainties + contested findings — things to be careful about}

## Coding Conventions
- Use TDD for all features (`superpowers:test-driven-development`)
- Plan before coding (`superpowers:writing-plans`)
- Verify before claiming done (`superpowers:verification-before-completion`)
- Debug systematically (`superpowers:systematic-debugging`)
- Commit frequently with conventional commits

## Recommended Skills
- `superpowers:writing-plans` — plan multi-step tasks before coding
- `superpowers:test-driven-development` — TDD for all implementation
- `superpowers:verification-before-completion` — verify before claiming done
- `superpowers:systematic-debugging` — for any failures
- `superpowers:brainstorming` — for design decisions
- `superpowers:using-git-worktrees` — for feature branch isolation (if project has multiple phases)
- `gw:review-app` — quality analysis after implementation

## Key Decisions
{From CONSENSUS.md — Tier 1 recommendations that constrain implementation}
{From contested findings — what was decided and why}

## External Services
{From agent research — any APIs, services, or accounts needed}

## Deployment
{From CONSENSUS.md recommendations — where and how to deploy}

## References
- Research: `{RESEARCH_DIR}/CONSENSUS.md`
- Agent findings: `{RESEARCH_DIR}/agents/`
- Debate transcripts: `{RESEARCH_DIR}/debate/`
````

Populate every section from actual CONSENSUS.md content. Skip sections that have no source data (e.g., skip Deployment if the research domain doesn't imply deployment).

**Generate `{RESEARCH_DIR}/SPEC.md`:**

Read `{RESEARCH_DIR}/CONSENSUS.md`. Write `{RESEARCH_DIR}/SPEC.md` with this structure:

````markdown
# {Project Name} — Specification

**Generated:** {date}
**Source:** gw:research CONSENSUS.md
**Confidence:** {from CONSENSUS.md — High/Medium/Low}

## Goal
{From CONSENSUS.md Executive Summary — one sentence}

## Requirements

### Core Features
{From CONSENSUS.md Tier 1 Recommendations — each becomes a checkbox requirement}
- [ ] {Requirement derived from recommendation 1}
- [ ] {Requirement derived from recommendation 2}

### Technical Requirements
{From CONSENSUS.md — technical recommendations that need implementation}
- [ ] {Tech requirement 1}

### Non-Functional Requirements
{Derived from consensus findings — performance, security, scalability concerns}
- [ ] {NFR 1}

## User Flows
{Derived from CONSENSUS.md practical implications — key user journeys}
{Omit this section if research domain is not user-facing}

## Data Model
{Omit if not applicable to the research domain}
{Derived from consensus recommendations if they imply data structures}

## API Design
{Omit if not applicable}
{Derived from consensus recommendations if they imply interfaces}

## Out of Scope
{From CONSENSUS.md — Tier 3 (speculative) recommendations}
{From contested findings where the resolution was "defer"}

## Success Criteria
{From CONSENSUS.md — what would prove the implementation correct}
- [ ] {Criterion from Tier 1 recommendation}

## References
- `{RESEARCH_DIR}/CONSENSUS.md`
- `{RESEARCH_DIR}/REPORT.md` (if generated)
````

Populate every section from actual CONSENSUS.md content. Omit sections that have no source data rather than filling them with "N/A".

#### 3b. Copy to project root and choose workflow

**Copy logic for CLAUDE.md:**
- If `CLAUDE.md` exists at project root, ask: "CLAUDE.md already exists. Overwrite [o], merge [m], or keep in research dir only [k]?"
  - **Overwrite:** replace entirely
  - **Merge:** append a `## Generated by gw:research` section to the existing file
  - **Keep:** don't copy
- If it doesn't exist and MODE=PROJECT_CONTEXTUAL, copy directly.

**Copy logic for SPEC.md:**
- If `SPEC.md` exists at project root, ask: "SPEC.md already exists. Overwrite [o], or keep in research dir only [k]?"
  - **Overwrite:** replace entirely
  - **Keep:** don't copy
  - No merge option — merging two requirement specs creates duplicates.
- If it doesn't exist and MODE=PROJECT_CONTEXTUAL, copy directly.

If MODE=STANDALONE, do not copy to project root — files stay in `{RESEARCH_DIR}/` only.

Then ask:

```
Generated:
  {RESEARCH_DIR}/CLAUDE.md  ({N} lines)
  {RESEARCH_DIR}/SPEC.md    ({N} lines)
  {Copied to project root: ./CLAUDE.md, ./SPEC.md (if copied)}

How would you like to proceed with implementation?
  [p] Superpowers — invoke superpowers:writing-plans with SPEC.md
  [g] GSD — create project/milestone from recommendations
  [d] Done — files generated, handle implementation manually
```

**If [p]:** Tell the user: "Invoking superpowers:writing-plans. The plan will use CLAUDE.md for project context and SPEC.md for requirements." Then invoke the Skill tool: `Skill(skill="superpowers:writing-plans")`.

**If [g]:** Proceed to 3c.

**If [d]:** Continue to "After any output action."

#### 3c. GSD integration (existing logic, unchanged)

Check if `~/.claude/commands/gsd/` exists. If it does:

1. Check if `.planning/PROJECT.md` exists (GSD project already initialized).
   - **If yes (brownfield):** Automatically invoke `/gsd:new-milestone` and reference `{RESEARCH_DIR}/CONSENSUS.md` as the requirements source. Tell the user: "Creating a new GSD milestone from the research recommendations."
   - **If no (greenfield):** Automatically invoke `/gsd:new-project` and reference `{RESEARCH_DIR}/CONSENSUS.md` as the requirements source. Tell the user: "Creating a GSD project from the research recommendations."

Each Tier 1 recommendation becomes a GSD phase. Tier 2 recommendations become later phases.

If GSD commands don't exist, say: "Full research available in `{RESEARCH_DIR}/CONSENSUS.md`. Install GSD to auto-create a project from these recommendations." and stop.

#### Error handling for Option 3

- If `{RESEARCH_DIR}/CONSENSUS.md` does not exist: "Cannot generate project files — CONSENSUS.md is missing. Run the full research workflow first or pick a different output format."
- If file copy fails (permissions): generate in `{RESEARCH_DIR}/` only, tell user: "Could not copy to project root (permission denied). Files available at {RESEARCH_DIR}/CLAUDE.md and {RESEARCH_DIR}/SPEC.md."
- If superpowers:writing-plans is not available when [p] is selected: "superpowers:writing-plans not found. The files are ready at {paths} — invoke the skill manually when available."

### Option 4: Prototype

Launch a single foreground agent (`subagent_type="general-purpose"`) with:
- The CONSENSUS.md findings and recommendations
- The research question and domain
- Project context (if PROJECT_CONTEXTUAL)
- Instruction to write a working prototype demonstrating the recommended approach

```bash
mkdir -p "{RESEARCH_DIR}/prototype"
```

The agent should:
1. Read CONSENSUS.md
2. Identify the most actionable recommendation
3. Write working code that demonstrates the approach
4. Include a README.md in the prototype directory explaining how to run it
5. Keep it minimal — proof of concept, not production code

Output: `{RESEARCH_DIR}/prototype/` with working code files.

Tell the user what was created and how to run it.

### Option 5: Custom

Ask: "Describe what you'd like to create from the research findings:" and execute the user's request using the research artifacts as context.

### After any output action

Ask: "Another output format, or done? [1-5/d]"
- If the user picks another format, execute it
- If done, proceed to Step 8

---

## Step 8 — Persistence & Cleanup

### 8a. File listing

Show what was created:

```
Research artifacts:
  {RESEARCH_DIR}/
    agents/
      literature-reviewer.md
      devils-advocate.md
      domain-expert.md
      ...
    debate/
      round1/{persona}.md (x{N})
      round2/{persona}.md (x{N})
    CONSENSUS.md
    CLAUDE.md           {if generated}
    SPEC.md             {if generated}
    REPORT.md           {if generated}
    REPORT.docx         {if generated}
    prototype/          {if generated}
  docs/gw/
    research-{slug}-YYYY-MM-DD.pptx  {if generated}
  ./CLAUDE.md                          (copied to project root, if applicable)
  ./SPEC.md                            (copied to project root, if applicable)
```

### 8b. Optional git commit

If the project is a git repo, ask: "Commit research artifacts? [y/n]"

If yes:
```bash
git add "{RESEARCH_DIR}/"
git add docs/gw/research-*.pptx 2>/dev/null || true
git commit -m "docs: add research — {truncated question (50 chars)}

Question: {full question}
Domain: {RESEARCH_DOMAIN}
Team: {N} specialists, {N} sources
Confidence: {High|Medium|Low}"
```

### 8c. Tip

End with a contextual tip:

```
Tip: Re-run with --deep for expanded source coverage, or use a different output format.
     Your research is saved at {RESEARCH_DIR}/ and will be detected on future runs.
```

---

## Step 8.5 — Persona Contribution

Skip this step if `CREATED_PERSONAS` is empty.

Present the created personas:

```
New persona(s) created during this run:
  - {Name1} (workforce/{slug1}.md)
  - {Name2} (workforce/{slug2}.md)

Contribute to gw-skills defaults? This creates a PR to share with all users.
  Contribute [y], skip [n]?
```

If the user selects `[y]`:

1. Save the current directory and branch
2. `cd $GW_REPO`
3. Check for uncommitted changes — if the working tree is dirty, ask: "gw-skills repo has uncommitted changes. Stash them? [y/n]" If yes, `git stash`. If no, abort contribution.
4. Create a branch:
   - Single persona: `persona/{slug}`
   - Multiple personas: `persona/batch-YYYY-MM-DD`
5. For each persona in `CREATED_PERSONAS`:
   - Copy `workforce/{slug}.md` → `workforce/_defaults/{slug}.md`
6. Stage and commit:
   ```bash
   git add workforce/_defaults/
   git commit -m "feat(workforce): add {Name} persona

   Background: {background}
   Created inline during gw:research run."
   ```
   (For multiple personas, list all names in the commit message.)
7. Push: `git push -u origin {branch}`
8. Create PR:
   ```bash
   gh pr create --title "Add {Name} persona to defaults" --body "$(cat <<'EOF'
   ## New Persona: {Name}

   **Background:** {background}
   **Skills used by:** gw:compete, gw:research, gw:review-app, gw:saas-idea
   **Created:** Inline during gw:research run on {date}

   Generated with [Claude Code](https://claude.com/claude-code)
   EOF
   )"
   ```
9. If stashed in step 3, `git stash pop`
10. Return to the original directory and branch
11. Print the PR URL

---

## Error Handling

- **WebSearch/WebFetch fails during research:** retry once, then mark source as unavailable and continue with collected data
- **A research agent fails entirely:** note as `[FAILED]` in status, offer retry, supervisor synthesizes with available findings
- **A debate agent fails:** supervisor synthesizes with available positions, notes the gap
- **python-pptx unavailable:** suggest `pip install python-pptx` or `--skip-pptx`
- **pandoc not found:** skip .docx conversion, inform user
- **GSD not installed:** inform user, continue without GSD integration
- **Workforce directory missing:** create it with `mkdir -p`
- **User tries to `--fire` a default persona:** reject with explanation
- **`--hire` name conflicts with existing persona:** ask to overwrite or rename
- **Research directory already exists:** offer to re-use, start fresh, or change question
- **No research question provided:** prompt for one
- **Never force-push or use destructive git operations without asking**
