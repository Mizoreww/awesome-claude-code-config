# Codex Configuration (English)

This branch provides a **Codex-native port** of [`Mizoreww/claude-code-config`](https://github.com/Mizoreww/claude-code-config) with the same intent:

- global behavior instructions
- lessons-based self-correction loop
- layered coding standards via skills
- MCP integrations (Lark, Context7, GitHub, Playwright)
- plugin-name compatibility mapping

## What is Included

```
codex/
├── AGENTS.md      # Global instructions for Codex
├── config.toml    # Codex settings template (no deprecated web_search format)
├── lessons.md     # Lessons template
└── install.sh     # Installer for core files + MCP + key open-source skills
```

## Quick Start

```bash
# from repo root
bash codex/install.sh
```

Then restart Codex.

## Mapping from Claude Config

### Core mapping

- `CLAUDE.md` -> `~/.codex/AGENTS.md`
- `lessons.md` + SessionStart hook -> `~/.codex/lessons.md` + `model_instructions_file`
- `settings.json` model/permissions -> `config.toml` (`model`, `model_reasoning_effort`, `approval_policy`, `sandbox_mode`)
- `plugins` -> open-source skills + compatibility wrappers
- `mcp/mcp-servers.json` -> `codex mcp add ...`

### Enabled plugin set mirrored

- superpowers
- everything-claude-code
- document-skills
- example-skills
- claude-mem
- frontend-design
- context7
- code-review
- github
- playwright
- feature-dev
- code-simplifier
- ralph-loop
- commit-commands
- fine-tuning
- post-training
- inference-serving
- distributed-training
- optimization

## Notes

1. Fill your own credentials:
   - `YOUR_APP_ID` / `YOUR_APP_SECRET` (Lark)
   - `YOUR_GITHUB_PAT` (GitHub MCP)
2. This port removes deprecated Codex config usage:
   - uses top-level `web_search = "live"`
   - does **not** use deprecated `[tools].web_search`
3. If `~/.codex/config.toml` already exists, merge manually.

## Scope

This branch keeps content in English only for Codex-targeted setup.
