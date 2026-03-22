## Feature Matrix Generation

Launch a single foreground agent (`subagent_type="general-purpose"`) with:
- The project's FEATURE_INVENTORY from Step 2
- All `.competitors/research/*.md` files
- Instruction to build a comprehensive feature-by-feature comparison

The agent writes `.competitors/feature-matrix.json`:
```json
{
  "generated": "YYYY-MM-DD",
  "project": "{project_name}",
  "competitors": ["Notion", "Coda", "Obsidian"],
  "categories": [
    {
      "name": "Collaboration",
      "features": [
        {
          "name": "Real-time editing",
          "our_status": "missing",
          "competitors": {
            "Notion": "full",
            "Coda": "full",
            "Obsidian": "missing"
          },
          "gap_type": "competitive_gap",
          "effort_estimate": "Large",
          "community_signal": "High demand on Reddit (340+ upvotes)"
        }
      ]
    }
  ]
}
```

Status values: `full`, `partial`, `missing`, `planned`
Gap types:
- `competitive_gap` — they have it, we don't
- `competitive_advantage` — we have it, they don't
- `parity` — everyone has it
- `opportunity` — nobody has it yet (from community pain points in deep mode)

Present the matrix to the user as a readable table before proceeding to debate.

---

## Test Scaffold Generation

For each selected feature, spawn specialist testing agents in parallel (`run_in_background=true`).

### Testing agent pool

| Agent | Responsibility | Output Pattern |
|-------|---------------|----------------|
| Unit Test Architect | Pure logic tests, isolated components | `tests/unit/feature-{slug}.test.{ext}` |
| Integration Test Architect | Cross-module, database, API contracts | `tests/integration/feature-{slug}.test.{ext}` |
| E2E Test Architect | Full user flows, happy + error paths | `tests/e2e/feature-{slug}.spec.{ext}` |
| Backend Test Architect | API endpoints, auth, data validation | `tests/backend/feature-{slug}.test.{ext}` |
| Stress Test Architect | Load, concurrency, resource limits | `tests/stress/feature-{slug}.test.{ext}` |
| Session Recorder | Playwright recorded user journeys (web only) | `tests/recorded/feature-{slug}.spec.{ext}` |

Not all agents apply to every project:

| APP_TYPE | Agents Used |
|----------|-------------|
| web | All 6 |
| server | Unit, Integration, Backend, Stress |
| cli | Unit, Integration, E2E |
| mobile | Unit, Integration, E2E |
| library | Unit, Integration, Stress |
| saas | All 6 |

### Agent prompt template

Include a code block with:
- Role: "You are a {TEST_SPECIALTY} generating TDD test scaffolds."
- Project context, stack context, feature name and description
- 8 rules: match existing test framework, real assertions, tests MUST FAIL (true TDD), descriptive names, cover happy/edge/error, web default to Vitest+Playwright, test API contracts for backend, define load parameters for stress
- Output: test files + manifest to `.competitors/tests/{FEATURE_SLUG}-{SPECIALTY}-manifest.md`

### Session Recorder specifics (web apps only)

- Generates Playwright test scripts with `page.goto()`, `page.click()`, `page.fill()`
- Includes `await expect(page).toHaveScreenshot()` for visual regression
- Scaffolds `playwright.config.ts` if not present
- Marks with `// RECORD: run with --headed to capture baseline`

### Commit test scaffolds

After all testing agents complete, check if the project is in a git repository: if `git rev-parse --git-dir 2>/dev/null` fails, tell the user: "Test scaffolds were written but not committed (not a git repository)." and skip the commit step.

Otherwise, ask the user: "Test scaffolds generated. Commit to the branch? [y/n]"

If yes:
```bash
git add tests/
git add .competitors/tests/
git commit -m "test: scaffold TDD tests for competitive features

Features: {comma-separated feature names}
Types: unit, integration, e2e, backend, stress, recorded
All tests designed to FAIL until features are implemented."
```
