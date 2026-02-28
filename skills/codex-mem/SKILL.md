---
name: codex-mem
description: Codex-native persistent memory workflow inspired by claude-mem. Uses local `codex-mem` CLI for observations, search, timeline, and MEMORY.md sync.
---

# codex-mem

Use this when you need cross-session memory in Codex.

## Core commands

```bash
# Initialize once
~/.codex/bin/codex-mem init

# Record important work
~/.codex/bin/codex-mem note --type decision --title "..." --details "..." --files "a.py,b.py"

# Search old memory
~/.codex/bin/codex-mem search --query "keyword" --limit 20

# Context around an event
~/.codex/bin/codex-mem timeline --query "keyword" --depth-before 3 --depth-after 3

# Full details by IDs
~/.codex/bin/codex-mem get --ids 12,15

# Refresh auto-loaded MEMORY.md
~/.codex/bin/codex-mem build-context --project "$(pwd)" --output ~/.codex/MEMORY.md --lessons ~/.codex/lessons.md
```

## Workflow

1. Capture high-signal events with `note`
2. Retrieve with `search -> timeline -> get`
3. Refresh `~/.codex/MEMORY.md` with `build-context`

## Observation types

- `bugfix`, `feature`, `decision`, `discovery`, `change`, `summary`, `note`
