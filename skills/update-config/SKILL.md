---
name: update-config
description: Update awesome-claude-code-config (Cursor variant) to the latest version. Checks the remote for new releases, then re-runs the Cursor installer (install-cursor.sh). Use when the user types /update-config or asks to update their Cursor configuration.
disable-model-invocation: true
---

# Update — awesome-claude-code-config

## Overview

Check for updates and upgrade the installed configuration to the latest version.

## Workflow

Run the following steps **in order**. Stop immediately if a step fails. Do NOT ask for
confirmation between steps — just execute.

### Step 1: Check versions

```bash
# Installed version
INSTALLED="$(cat ~/.cursor/.awesome-claude-code-config-version 2>/dev/null || echo 'not installed')"

# Remote version
REMOTE="$(curl -fsSL https://raw.githubusercontent.com/Mizoreww/awesome-claude-code-config/cursor/VERSION 2>/dev/null | tr -d '[:space:]')"

echo "Installed: $INSTALLED"
echo "Remote:    $REMOTE"
```

If `INSTALLED` equals `REMOTE`, tell the user they are already on the latest version and stop.

If the remote fetch fails, warn the user and stop.

### Step 2: Run the installer (remote mode)

Download and execute the latest Cursor installer:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Mizoreww/awesome-claude-code-config/cursor/install-cursor.sh)
```

The installer is idempotent and non-destructive. It:
- Smart-merges existing config files such as `mcp.json` / `cli-config.json` (preserves your customizations)
- Backs up any file it overwrites and stamps the installed version
- Refreshes skills, rules, `AGENTS.md`, and hooks under `~/.cursor/`

### Step 3: Report result

After the installer finishes, confirm the new version:

```bash
cat ~/.cursor/.awesome-claude-code-config-version 2>/dev/null
```

Tell the user the update is complete with the new version number.

## Notes

- The installer's smart merge preserves existing config customizations (e.g. `mcp.json`)
- `lessons.md` is never overwritten if it already exists
- Skills and rules are re-installed (idempotent — existing ones are refreshed)
- User should restart Cursor after updating for changes to take effect
