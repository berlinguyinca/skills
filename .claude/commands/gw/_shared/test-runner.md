# Test Runner Detection

Shared test suite detection priority for gw-skills.

## Detection Order

| Priority | File | Command |
|----------|------|---------|
| 1 | `package.json` with `scripts.test` | `npm test` (or `yarn test` / `pnpm test` if lockfile present) |
| 2 | `pyproject.toml` with `[tool.pytest]`, or `pytest.ini`, or `setup.cfg` | `pytest` |
| 3 | `Cargo.toml` | `cargo test` |
| 4 | `go.mod` | `go test ./...` |
| 5 | `Makefile` with `test` target | `make test` |

If no test runner is detected: "No test runner detected — skipping tests."

## Failure Handling

If tests fail, show the output and ask how to proceed. The calling skill defines the specific prompt options (e.g., "Fix and retry, continue anyway, or abort?").
