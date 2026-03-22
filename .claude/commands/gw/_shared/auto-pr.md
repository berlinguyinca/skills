# Auto-PR Creation

Shared module for creating a PR with the `agent_merge` label at the end of skill execution. The calling skill sets `SKILL_NAME`, `GW_BRANCH`, `BASE_BRANCH`, and `BRANCH_CREATED` before including this module.

---

## Skip Check

Skip this module entirely if ANY of these are true:

- `BRANCH_CREATED` is `false`
- `IN_WORKTREE` is `true` (worktree-based skills use `gw:merge-it` for PR creation)
- Current branch equals `BASE_BRANCH` (no branch switch happened)

Also check if there are commits ahead of base:

```bash
commit_count=$(git rev-list --count ${BASE_BRANCH}..HEAD 2>/dev/null || echo "0")
```

If `commit_count` is 0: log "No commits on branch — skipping PR creation." and skip.

---

## Check GitHub CLI

```bash
gh auth status 2>/dev/null
```

If not authenticated: warn "GitHub CLI not authenticated. Skipping PR creation. Run `gh auth login` to enable auto-PR." and skip. Do NOT abort the skill.

---

## Ensure Label Exists

```bash
gh label create agent_merge \
  --description "Auto-created by gw-skills for gw:merge-prs integration" \
  --color "0E8A16" 2>/dev/null || true
```

This is idempotent — if the label already exists, the command silently succeeds.

---

## Push Branch

```bash
git push -u origin "${GW_BRANCH}"
```

If push fails, warn and skip PR creation. Do NOT abort the skill.

---

## Build PR Body

Read `.gw-intent.md` from the project root if it exists. Extract the Purpose and Key Decisions sections for the PR body.

Get diff stats:

```bash
DIFF_STATS=$(git diff --stat ${BASE_BRANCH}..HEAD)
```

---

## Create PR

```bash
gh pr create \
  --base "${BASE_BRANCH}" \
  --title "gw:${SKILL_NAME} — <brief description derived from Purpose in .gw-intent.md>" \
  --label "agent_merge" \
  --body "$(cat <<'PRBODY'
## gw:${SKILL_NAME} Execution

**Branch:** ${GW_BRANCH}
**Base:** ${BASE_BRANCH}

### Purpose
<Purpose section from .gw-intent.md, or summary from $ARGUMENTS>

### Key Decisions
<Key Decisions section from .gw-intent.md, or "See .gw-intent.md on branch">

### Changes
${DIFF_STATS}

---
*Auto-created by gw-skills branch-first execution.*
*Merge via `/gw:merge-prs` or manually.*
PRBODY
)"
```

Capture the PR URL from the output.

---

## Switch Back to Base Branch

Return the user to their original branch so their terminal is clean:

```bash
git checkout "${BASE_BRANCH}"
```

---

## Report

Log:

```
PR created: <PR URL>
Label: agent_merge
Branch: ${GW_BRANCH}
Merge with: /gw:merge-prs
```
