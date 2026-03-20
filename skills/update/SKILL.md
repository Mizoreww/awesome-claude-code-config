---
name: update_config
description: Update awesome-claude-code-config on the Codex branch to the latest version. Checks remote version, then re-runs the Codex installer. Use when user types /update_config or asks to update their Codex configuration.
---

# Update — awesome-claude-code-config (Codex)

## Overview

Check for updates and upgrade the installed Codex configuration to the latest version from the `codex` branch.

## Workflow

Run the following steps **in order**. Stop immediately if a step fails. Do **not** ask for confirmation between steps unless the installer itself requires user interaction.

### Step 1: Check versions

Use the current Codex version stamp, but also support the legacy Claude-era fallback file:

```bash
# Installed version
INSTALLED="$(cat ~/.codex/.codex-config-version 2>/dev/null || cat ~/.codex/.claude-code-config-version 2>/dev/null || echo 'not installed')"

# Remote version
REMOTE="$(curl -fsSL https://raw.githubusercontent.com/Mizoreww/awesome-claude-code-config/codex/VERSION 2>/dev/null | tr -d '[:space:]')"

echo "Installed: $INSTALLED"
echo "Remote:    $REMOTE"
```

If `INSTALLED` equals `REMOTE`, tell the user they are already on the latest version and stop.

If the remote fetch fails, warn the user and stop.

### Step 2: Run the installer (remote mode)

Choose the installer that matches the current platform.

**macOS / Linux**

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Mizoreww/awesome-claude-code-config/codex/install.sh)
```

**Windows PowerShell**

```powershell
irm https://raw.githubusercontent.com/Mizoreww/awesome-claude-code-config/codex/install.ps1 | iex
```

### Step 3: Report result

After the installer finishes, confirm the new version:

```bash
cat ~/.codex/.codex-config-version 2>/dev/null || cat ~/.codex/.claude-code-config-version 2>/dev/null
```

Tell the user the update is complete with the new version number.

## Notes

- The skill targets the **Codex** branch, not the Claude Code `main` branch
- `lessons.md` is preserved if it already exists
- Restart Codex after updating so new config, skills, and MCP settings are fully picked up
