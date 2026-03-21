# GW Skill Preamble

Shared boilerplate for all gw-skills. Skills reference this file instead of duplicating these steps.

## Update Check

Run the update check script (GW_REPO must already be resolved by the calling skill):

```bash
bash "$GW_REPO/check-update.sh" 2>/dev/null || true
```

If the output contains `UPDATE_AVAILABLE`, tell the user how many commits behind they are and ask: "gw-skills has updates available. Run /gw:update to install them, or continue?" If they want to update, invoke `/gw:update` and stop. Otherwise continue. If the script is missing or fails, skip silently.

## GSD Project Detection (Model Inheritance)

Skip this step if you are inside a GSD project (`~/.config/opencode/.planning/` exists).

If `.planning/config.json` exists in the current or parent directories:
1. Read its JSON content
2. Extract `model_profile` (default: "balanced")
3. If a profile is found, use it for all agent spawns instead of default Claude model
4. Log: "Using GSD model profile: {profile}" in the first output message

This enables gw skills to inherit model preferences within managed projects.
