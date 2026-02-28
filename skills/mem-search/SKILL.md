---
name: mem-search
description: Search Codex persistent memory using local `codex-mem` CLI (search -> timeline -> get).
---

# Memory Search (Codex)

Use when users ask about previous sessions, prior fixes, or historical decisions.

## 3-step workflow (mandatory)

### 1) Search index first

```bash
~/.codex/bin/codex-mem search --project "$(pwd)" --query "<keyword>" --limit 20
```

### 2) Pull timeline around best match

```bash
~/.codex/bin/codex-mem timeline --project "$(pwd)" --query "<keyword>" --depth-before 3 --depth-after 3
# or
~/.codex/bin/codex-mem timeline --project "$(pwd)" --anchor-id <id>
```

### 3) Fetch full details only for selected IDs

```bash
~/.codex/bin/codex-mem get --ids <id1,id2,...>
```

## Token discipline

Never fetch full details before filtering with search/timeline.
