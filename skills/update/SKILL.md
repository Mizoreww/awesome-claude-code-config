---
name: update
description: Update this awesome-claude-code-config Cursor configuration from the repository's `cursor` branch to the latest version. Checks the remote version, then re-runs the Cursor installer to refresh skills, rules, AGENTS.md, mcp.json, hooks, and the statusline under `~/.cursor/`. Use when the user types /update or asks to update their installed Cursor configuration.
disable-model-invocation: true
---

# Update — Cursor branch configuration

## Overview

Check for updates and upgrade the installed Cursor configuration to the latest version from the `cursor` branch. The installer writes into `~/.cursor/`:

- skills → `~/.cursor/skills/`
- rules → `~/.cursor/rules/`
- `AGENTS.md` → `~/.cursor/AGENTS.md`
- `mcp.json` → merged into `~/.cursor/mcp.json`
- hooks → `~/.cursor/hooks.json` (+ scripts in `~/.cursor/hooks/`)
- statusline → `~/.cursor/statusline.sh` (wired via `~/.cursor/cli-config.json`)

## Workflow

Run the following steps **in order**. Stop immediately if a step fails. Do **not** ask for confirmation between steps unless the installer itself requires user interaction.

### Step 1: Check versions

```bash
# Installed version (written by install-cursor.sh)
INSTALLED="$(cat ~/.cursor/.awesome-claude-code-config-version 2>/dev/null || echo 'not installed')"

# Remote version
REMOTE="$(curl -fsSL https://raw.githubusercontent.com/Mizoreww/awesome-claude-code-config/cursor/VERSION 2>/dev/null | tr -d '[:space:]')"

echo "Installed: $INSTALLED"
echo "Remote:    $REMOTE"
```

If `INSTALLED` equals `REMOTE`, tell the user they are already on the latest version and stop.

If the remote fetch fails, warn the user and stop.

### Step 2: Run the installer (remote mode)

Choose the installer that matches the current platform.

**macOS / Linux**

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Mizoreww/awesome-claude-code-config/cursor/install-cursor.sh)
```

**Windows PowerShell**

```powershell
$u = "https://raw.githubusercontent.com/Mizoreww/awesome-claude-code-config/cursor/install-cursor.ps1"
$t = Join-Path $env:TEMP "install-cursor.ps1"; irm $u -OutFile $t; & $t
```

If a local clone of the repo is already checked out on the `cursor` branch, the equivalent update is `git pull` followed by running `./install-cursor.sh` from the repo root.

### Step 3: Report result

After the installer finishes, confirm the new version:

```bash
cat ~/.cursor/.awesome-claude-code-config-version 2>/dev/null
```

Tell the user the update is complete with the new version number.

## Notes

- The skill targets the repository's **`cursor`** branch; `install-cursor.sh` writes `~/.cursor/.awesome-claude-code-config-version` on success.
- The installer is idempotent and backs up existing files before overwriting; `lessons.md` is preserved if it already exists.
- Restart Cursor after updating so new skills, rules, MCP servers, hooks, and the statusline are fully picked up.
