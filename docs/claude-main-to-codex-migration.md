# Claude Code main branch → Codex branch migration map

This document explains how concepts from the repository's `main` branch map to the Codex branch.

## Quick mapping

| Claude Code main branch | Codex branch equivalent | Notes |
|---|---|---|
| `CLAUDE.md` | `AGENTS.md` | Global instructions move from Claude's project doc to Codex's `AGENTS.md` model |
| `settings.json` | `config.toml` | Codex uses TOML config instead of Claude settings JSON |
| Claude plugins | Skills + MCP + built-in Codex capabilities | No 1:1 plugin system exists in Codex |
| `mcp/mcp-servers.json` | `[mcp_servers.*]` in `config.toml` | Codex stores MCP config directly in TOML |
| `rules/` docs | installed skills such as `python-patterns`, `golang-patterns`, `frontend-patterns` | Codex branch keeps rules skills-first rather than restoring the old tree |
| Claude update skill | `skills/update/SKILL.md` | Adapted to Codex install URLs and version files |

## What already migrated well

- Lessons-based self-correction loop
- Core multi-agent role setup
- Context7, GitHub, Playwright, Lark, and OpenAI docs integrations
- Bundled local skills (`paper-reading`, `adversarial-review`, `humanizer`, `update_config`)
- Install-time upstream skills from DeepXiv (`deepxiv-cli`, `deepxiv-baseline-table`, `deepxiv-trending-digest`)
- Open-source skill bootstrapping from `mattpocock/skills`, superpowers, anthropic skills, DeepXiv, and AI research skill packs
- Codex `[tui].status_line` configured to show model, reasoning, project name, git branch, context used, context window size, and used tokens in one consistent footer
- The installer writes statusline settings under `[tui]` and removes misplaced top-level or project-scoped `status_line` entries when ensuring the footer
- Codex defaults set to `model = "gpt-5.5"`, `model_reasoning_effort = "xhigh"`, `approval_policy = "never"`, and `sandbox_mode = "danger-full-access"` for trusted-repo autonomous runs

## What does **not** migrate 1:1

### Claude plugin registry

Codex does not expose the same plugin model as Claude Code. The Codex branch therefore migrates *capabilities* rather than plugin identities:

- documentation lookup → MCP / docs skills
- GitHub workflows → GitHub MCP
- browser automation → Playwright MCP
- coding patterns / testing / security → installed skills
- Claude-only command workflow plugins (`feature-dev`, `ralph-loop`, `commit-commands`, `code-simplifier`) → not shown in the Codex installer because they have no practical Codex install target
- plugin-hosted skill packs with valid `SKILL.md` entries → installed with `npx -y skills@latest add <repo> --global --agent codex --copy --yes --full-depth --skill <name>` where possible

## Practical recommendation for users coming from `main`

If you are familiar with the Claude Code branch, think about the Codex branch in layers:

1. **Instructions:** `AGENTS.md`
2. **Runtime config:** `config.toml`
3. **Reusable behavior:** installed skills
4. **External tools:** MCP servers

That mental model is much closer to how Codex actually works than trying to recreate Claude's exact structure.
