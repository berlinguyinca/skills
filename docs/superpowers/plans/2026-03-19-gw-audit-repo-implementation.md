# gw:audit-repo Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create the gw:audit-repo skill file — a Markdown instruction document following the spec at `docs/superpowers/specs/2026-03-19-gw-audit-repo-design.md`

**Architecture:** Single Markdown skill file at `.claude/commands/gw/audit-repo.md`. Follows the same pattern as the other 8 gw-skills: YAML frontmatter → Step 0 update check → argument parsing → workflow routing → numbered steps → approval gates → error handling. The skill is consumed by Claude Code at runtime as an instruction prompt.

**Tech Stack:** Markdown (skill file), YAML (frontmatter), Bash (embedded code blocks for shell commands)

**Reference files:**
- Spec: `docs/superpowers/specs/2026-03-19-gw-audit-repo-design.md`
- Pattern to follow: `.claude/commands/gw/compete.md` (closest structural match — parallel agents, approval gates, PPTX, GSD)
- Design system reference: `.claude/commands/gw/review-app.md` lines 720-739 (canonical palette)
- Weekly-review dual-deck pattern: `.claude/commands/gw/weekly-review.md`

---

### Task 1: Frontmatter + Step 0 + Step 1 (Parse Arguments & Acquire Repo)

**Files:**
- Create: `.claude/commands/gw/audit-repo.md`

- [ ] **Step 1: Create the skill file with frontmatter**

Write the YAML frontmatter block exactly as specified in the spec:
```yaml
---
name: audit-repo
description: Security audit for GitHub repositories — analyzes code for malicious patterns, credential theft, crypto wallet attacks, backdoors, and supply chain risks before local use
argument-hint: "[<github-url>] [--deep] [--tools] [--refresh-threats] [--skip-pptx] [--skip-gsd] [--publish] [--publish-repo <owner/repo>] [--publish-list]"
---
```

- [ ] **Step 2: Write Step 0 — Update check**

Copy the canonical update check block verbatim from `compete.md` (the "Step 0 — Update check" section). This block is identical across all gw-skills.

- [ ] **Step 3: Write the orchestrator introduction and argument parsing**

After the `---` separator, write the orchestrator intro paragraph and `$ARGUMENTS` parsing section. Parse every flag from the spec: `<github-url>`, `--deep`, `--tools`, `--refresh-threats`, `--skip-pptx`, `--skip-gsd`, `--publish`, `--publish-repo`, `--publish-list`, `--hire/--fire/--roster`.

Follow the exact pattern from `compete.md` "Step 1 — Parse Arguments & Route" section for the argument parsing format. Note: `--hire/--fire/--roster` are parsed but intentionally NOT listed in the `argument-hint` frontmatter, matching the pattern of other skills.

- [ ] **Step 4: Write the workflow routing table**

Write the routing table and approval gates list matching the spec's Workflow Routing section. Follow the table format from `compete.md` "Workflow routing" section.

- [ ] **Step 5: Write Step 1 — Acquire repo**

Write the full Step 1 including:
- 1a: Check for existing `.audit/` directory (refresh/view/delete)
- 1b: Acquire repo (URL clone vs current dir)
- Language detection, file counting, commit hash recording

Reference the spec sections Step 1, 1a, and 1b. Use `mktemp -d` for temp directory, `git clone --depth 1` for shallow clone, full clone when `--tools` + trufflehog.

- [ ] **Step 6: Verify structure**

Read the file and verify:
- Frontmatter has all 3 required fields
- Step 0 is identical to other skills
- All flags from argument-hint are parsed
- Routing table covers all flag combinations
- Approval gates are listed

- [ ] **Step 7: Commit**

```bash
git add .claude/commands/gw/audit-repo.md
git commit -m "feat(gw:audit-repo): add frontmatter, Step 0, argument parsing, and repo acquisition"
```

---

### Task 2: Step 2 — Threat Intelligence Cache

**Files:**
- Modify: `.claude/commands/gw/audit-repo.md`

- [ ] **Step 1: Write Step 2 — Threat intelligence refresh**

Write the full threat intelligence section including:
- Cache location (`~/.config/gw-skills/threat-intel.json`)
- Cache JSON structure (all 6 categories with patterns, keywords, recent_techniques)
- Refresh logic (missing → create, `--refresh-threats` → force, >7 days → refresh, fresh → use)
- WebSearch query templates per category
- Merge behavior (accumulate, never remove)

- [ ] **Step 2: Write the bundled baseline patterns section**

Write the hardcoded baseline patterns block. This must include concrete patterns for all 6 categories:
- Credential theft: `process.env.*fetch`, `keychain`, `os.environ.*request`
- Crypto theft: BTC address regex `[13][a-km-zA-HJ-NP-Z1-9]{25,34}`, ETH address regex `0x[a-fA-F0-9]{40}`
- Data exfiltration: common exfil domains, base64 + eval patterns
- Backdoors: reverse shell signatures (`/bin/sh -i`, `bash -c 'exec bash`), eval of decoded strings
- Supply chain: known malicious package names (from recent advisories)
- Persistence: crontab write patterns, LaunchAgent plist creation

- [ ] **Step 3: Verify the section**

Read back the threat intelligence section. Verify:
- JSON structure example is valid JSON
- All 6 categories appear in the cache structure
- Refresh logic covers all 4 cases
- Baseline patterns include at least 3 concrete patterns per category

- [ ] **Step 4: Commit**

```bash
git add .claude/commands/gw/audit-repo.md
git commit -m "feat(gw:audit-repo): add threat intelligence cache with baseline patterns"
```

---

### Task 3: Step 3 — Surface Scan

**Files:**
- Modify: `.claude/commands/gw/audit-repo.md`

- [ ] **Step 1: Write the pre-scan checks**

Write the 4 pre-scan checks from the spec:
- File count with >10,000 threshold
- Binary file detection (glob for `.so`, `.dll`, `.dylib`, `.wasm`, `.exe`)
- Git submodules check (`.gitmodules`)
- GitHub Actions check (`.github/workflows/*.yml` for `uses:` directives)

- [ ] **Step 2: Write the per-category surface scan table**

Write the 6-row table with category names and grep/glob patterns. Copy the exact patterns from the spec's "Per-category surface checks" table. Include the typosquatting check for supply chain (Levenshtein distance ≤2 against popular packages, supported ecosystems).

- [ ] **Step 3: Write additional surface checks and verdict logic**

Write the "Surface scan also checks" section (suspicious filenames, obfuscation signals, hidden files) and the verdict logic:
- 0 matches → SAFE → offer deep scan or stop
- 1+ matches → CAUTION/DANGEROUS → auto-proceed to deep scan

Include the SAFE output template from the spec.

- [ ] **Step 4: Verify**

Read the surface scan section. Verify all 6 categories have grep patterns, pre-scan checks are complete, verdict logic matches spec.

- [ ] **Step 5: Commit**

```bash
git add .claude/commands/gw/audit-repo.md
git commit -m "feat(gw:audit-repo): add surface scan with 6 threat categories"
```

---

### Task 4: Step 4 + 4b — Deep Scan Agents + Tool Scan

**Files:**
- Modify: `.claude/commands/gw/audit-repo.md`

- [ ] **Step 1: Write Step 4 — Deep scan agent dispatch**

Write the parallel agent launch section. Include:
- "Launch 6 background agents in a SINGLE message" instruction
- Full agent prompt template from the spec (with all placeholders)
- All rules (READ actual code, trace data flows, decode obfuscation, etc.)
- Output format template with CRITICAL/SUSPICIOUS/INFO structure
- The category-specific file targets table

Follow the agent dispatch pattern from `compete.md` Step 7 (Round 1) — same structure of persona-per-agent with `run_in_background=true`.

- [ ] **Step 2: Write the collection section**

After agent dispatch, write the collection/validation section:
- Wait for all 6 agents to complete
- Verify each `.audit/{NN}-{slug}.md` exists
- Print status table (done/FAILED)
- Offer retry for failed agents (max 2 retries per agent)

Follow the collection pattern from `compete.md` Step 4 Collection.

- [ ] **Step 3: Write Step 4b — Tool scan**

Write the optional tool scan section including:
- 6-tool availability table (semgrep, trufflehog, npm audit, pip-audit, cargo-audit, bundler-audit)
- Check command, run command, and parse description for each
- Output to `.audit/tools-{tool-name}.md`
- "Not installed" notes for unavailable tools

- [ ] **Step 4: Verify**

Read back. Verify:
- Agent prompt has all placeholders from spec
- All 6 categories have file targets
- Collection section has retry logic
- Tool table has all 6 tools
- `run_in_background=true` is specified

- [ ] **Step 5: Commit**

```bash
git add .claude/commands/gw/audit-repo.md
git commit -m "feat(gw:audit-repo): add deep scan agents and optional tool scan"
```

---

### Task 5: Step 5 — Synthesis + Verdict

**Files:**
- Modify: `.claude/commands/gw/audit-repo.md`

- [ ] **Step 1: Write Step 5 — Synthesis agent**

Write the synthesis section including:
- Foreground agent launch (reads all `.audit/[0-9]*-*.md` and `.audit/tools-*.md`)
- Full `.audit/REPORT.md` template (technical report)
- Full `.audit/EXECUTIVE-SUMMARY.md` template (executive report)
- Confidence scoring rules from spec

Follow the synthesis pattern from `review-app.md` Step 4.

- [ ] **Step 2: Write Step 6 — Present verdict**

Write the three verdict display templates (SAFE, CAUTION, DANGEROUS) from the spec. Include:
- SAFE: offer gw:review-app or done
- CAUTION: approval gate with proceed/deep scan/abort options
- DANGEROUS: delete cloned directory offer

- [ ] **Step 3: Verify**

Read back. Verify:
- Both report templates have all fields from spec
- Confidence scoring matches spec rules
- All three verdict templates are present
- CAUTION has an explicit approval gate marker

- [ ] **Step 4: Commit**

```bash
git add .claude/commands/gw/audit-repo.md
git commit -m "feat(gw:audit-repo): add synthesis, dual reports, and verdict system"
```

---

### Task 6: Step 7 — PPTX Generation (Dual Decks)

**Files:**
- Modify: `.claude/commands/gw/audit-repo.md`

- [ ] **Step 1: Write the PPTX generation section**

Write Step 7 including:
- Skip condition (`--skip-pptx`)
- Canonical design system block (copy the exact 9-color palette from `review-app.md` — search for "Design system" heading)
- Executive deck slide table (6 slides from spec)
- Technical deck slide table (up to 30 slides from spec)
- Output paths: `docs/gw/audit-executive-{repo-name}-{YYYY-MM-DD}.pptx` and `docs/gw/audit-technical-{repo-name}-{YYYY-MM-DD}.pptx`
- Execution chain: `uv run --with python-pptx` → `pip install` fallback → error message
- Font: Calibri, 16:9, accent bar specification

Follow the dual-deck pattern from `weekly-review.md`.

- [ ] **Step 2: Verify design system compliance**

Grep the file for the palette. Verify:
- All 9 color constants present (PRIMARY through BG_LIGHT)
- Hex values match canonical palette exactly
- Accent bar spec present (0.06" wide)
- "canonical gw-skills palette" text present

- [ ] **Step 3: Commit**

```bash
git add .claude/commands/gw/audit-repo.md
git commit -m "feat(gw:audit-repo): add dual PPTX generation with canonical design system"
```

---

### Task 7: Step 8 — Post-Audit Actions

**Files:**
- Modify: `.claude/commands/gw/audit-repo.md`

- [ ] **Step 1: Write Step 8a — Publish findings**

Write the publish section including:
- Config location (`~/.config/gw-skills/audit-repo.json`)
- Config management for `--publish-repo` and `--publish-list`
- Clone publish repo → create `findings/{owner}/{repo}/` → write 4 files (metadata.json, findings.json, summary.md, threat-patterns.json)
- Commit and push
- Duplicate detection (same repo+commit)

- [ ] **Step 2: Write Step 8b — GSD integration**

Write the GSD integration section. Follow the pattern from `compete.md` Step 12:
- Skip if `--skip-gsd` or verdict is SAFE
- Check for `~/.claude/commands/gsd/`
- Brownfield: `/gsd:new-milestone`
- Greenfield: `/gsd:new-project`
- Reference `.audit/REPORT.md` as requirements source

- [ ] **Step 3: Write Step 8c — Offer gw:review-app**

If verdict is SAFE, offer quality analysis.

- [ ] **Step 4: Verify**

Read back. Check publish has all 4 output files (metadata.json, findings.json, summary.md, threat-patterns.json), GSD section matches pattern, review-app offer is conditional on SAFE.

- [ ] **Step 5: Commit**

```bash
git add .claude/commands/gw/audit-repo.md
git commit -m "feat(gw:audit-repo): add publish and GSD integration"
```

---

### Task 7b: Step 9 — Cleanup + Error Handling

**Files:**
- Modify: `.claude/commands/gw/audit-repo.md`

- [ ] **Step 1: Write Step 9 — Cleanup**

Write cleanup logic:
- If CLONED and DANGEROUS and already deleted → done
- Otherwise offer keep/delete
- Print final summary template from spec

- [ ] **Step 2: Write Error Handling section**

Write the error handling section at the end of the file. Include all 11 items from the spec's Error Handling section. This section goes after all numbered steps.

- [ ] **Step 3: Verify completeness**

Read the full file. Check:
- All 10 steps present (0-9 including 4b)
- All flags from frontmatter are parsed and used
- All approval gates marked
- Error handling covers all 11 failure modes
- Temp directory cleanup on failure is included

- [ ] **Step 4: Commit**

```bash
git add .claude/commands/gw/audit-repo.md
git commit -m "feat(gw:audit-repo): add cleanup and error handling"
```

---

### Task 8: Update README.md

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Add gw:audit-repo to the Available Skills table**

Add a row to the table at the top of README.md:
```
| `/gw:audit-repo` | Security audit for GitHub repositories — checks for malicious code, credential theft, crypto attacks, backdoors, and supply chain risks before local use. |
```

Insert after the `/gw:review-app` row (security audit is closely related to app review).

- [ ] **Step 2: Add the Skill Reference section**

Add a full `/gw:audit-repo` reference section after the `/gw:review-app` section. Include:
- Command syntax
- Description paragraph
- Output files list (`.audit/REPORT.md`, `.audit/EXECUTIVE-SUMMARY.md`, dual PPTX)
- Options table (all flags)
- Examples section with 5-6 usage examples

Follow the format of the existing `/gw:compete` reference section.

- [ ] **Step 3: Verify README**

Read the README. Check:
- New skill appears in the Available Skills table
- Reference section has all flags from the skill
- Examples cover the main use cases (URL, current dir, deep, tools, publish)

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "docs: add gw:audit-repo to README with full reference section"
```

---

### Task 9: Final Verification

**Files:**
- Read: `.claude/commands/gw/audit-repo.md` (full file)
- Read: `README.md`

- [ ] **Step 1: Structural verification**

Read the complete skill file and verify against the Skill Developer persona's checklist:
1. Frontmatter has `name`, `description`, `argument-hint`
2. Step 0 is the canonical update check block
3. All flags in argument-hint are parsed in Step 1
4. Routing table covers all flag combinations
5. Approval gates appear before expensive operations
6. Error handling section at the end
7. Design system uses canonical 9-color palette

- [ ] **Step 2: Cross-reference with spec**

Compare the skill file against the spec document. Verify every section in the spec has a corresponding section in the skill file. Check that no spec requirement was dropped.

- [ ] **Step 3: Pattern consistency check**

Grep across the skill to verify key patterns:
```bash
grep "canonical gw-skills palette" .claude/commands/gw/audit-repo.md  # palette reference exists
grep "Max 2 retries" .claude/commands/gw/audit-repo.md               # retry cap exists
grep "workforce" .claude/commands/gw/audit-repo.md                    # workforce redirect exists
grep "EXECUTIVE-SUMMARY.md" .claude/commands/gw/audit-repo.md        # dual report exists
grep "metadata.json" .claude/commands/gw/audit-repo.md               # publish structure complete
grep "findings.json" .claude/commands/gw/audit-repo.md               # publish structure complete
grep "threat-patterns.json" .claude/commands/gw/audit-repo.md        # publish structure complete
grep "confidence.*99\|capped at 99" .claude/commands/gw/audit-repo.md # confidence cap documented
grep -c "APPROVAL GATE\|Stop and wait" .claude/commands/gw/audit-repo.md  # expect 3 approval gates
grep "0x2C.*0x3E.*0x50" .claude/commands/gw/audit-repo.md            # canonical PRIMARY color
```

- [ ] **Step 4: Verify the file naming conventions**

Check that output paths follow conventions:
```bash
grep "audit-executive-" .claude/commands/gw/audit-repo.md   # executive deck path
grep "audit-technical-" .claude/commands/gw/audit-repo.md   # technical deck path
grep '{NN}-{' .claude/commands/gw/audit-repo.md              # agent output naming
grep 'tools-{' .claude/commands/gw/audit-repo.md             # tool output naming
```

- [ ] **Step 5: Verify skill is accessible via symlink**

The install.sh symlinks the entire `.claude/commands/gw/` directory, so the new file is automatically available:
```bash
test -f .claude/commands/gw/audit-repo.md && echo "EXISTS" || echo "MISSING"
head -5 .claude/commands/gw/audit-repo.md  # frontmatter visible
```

- [ ] **Step 6: Final commit (only if fixes were needed)**

Only run this if previous verification steps found issues that were fixed:
```bash
git add .claude/commands/gw/audit-repo.md README.md
git commit -m "fix(gw:audit-repo): address verification findings"
```
