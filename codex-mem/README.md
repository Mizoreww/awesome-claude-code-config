# codex-mem

Codex-native persistent memory CLI inspired by claude-mem.

## Commands

```bash
codex-mem init
codex-mem start-session [--session-id ...] [--project ...]
codex-mem end-session --session-id ... [--summary ...]
codex-mem note --type decision --title "..." --details "..."
codex-mem search --query "..." [--project ...]
codex-mem timeline --query "..." [--project ...]
codex-mem get --ids 1,2,3
codex-mem recent [--project ...]
codex-mem build-context --project "$(pwd)" --output ~/.codex/MEMORY.md --lessons ~/.codex/lessons.md
codex-mem status
```

## Storage

- DB: `~/.codex/memory/codex_mem.db`
- Auto-loaded context: `~/.codex/MEMORY.md`
- Correction source: `~/.codex/lessons.md`
