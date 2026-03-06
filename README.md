<!-- This is the source of truth. README.zh-CN.md is the Chinese translation. Keep both in sync. -->

**Main English** | [Main 中文](./README.zh-CN.md) | [Codex English](https://github.com/Mizoreww/awesome-claude-code-config/blob/codex/README.md) | [Codex 中文](https://github.com/Mizoreww/awesome-claude-code-config/blob/codex/README.zh-CN.md)

# Awesome Claude Code Configuration

![Statusline](assets/statusline.png)

Production-ready configuration for [Claude Code](https://claude.com/claude-code) — one-command install of global instructions, multi-language coding rules (Python / TypeScript / Go), 19 curated plugins, custom skills, custom status bar, MCP integration, cross-model code review (Claude + Codex), and a self-improvement loop that remembers corrections across sessions. Also ships a [Codex CLI branch](https://github.com/Mizoreww/awesome-claude-code-config/tree/codex) with parallel support for OpenAI's coding agent.

## Directory Structure

```
.
├── CLAUDE.md              # Global instructions
├── settings.json          # Settings (permissions, plugins, hooks, model)
├── lessons.md             # Self-correction log template (auto-loaded via hook)
├── rules/                 # Multi-language coding standards (common + python/typescript/golang)
├── hooks/                 # Statusline with gradient progress bars (context + 5h usage)
├── mcp/                   # MCP server config (Lark-MCP, Codex CLI)
├── plugins/               # Plugin installation guide (19 plugins, 5 marketplaces)
├── skills/                # Custom skills (paper-reading)
├── VERSION                # Semantic version number
└── install.sh             # One-command installer
```

## Quick Start

**One-line remote install** (no clone needed):

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Mizoreww/awesome-claude-code-config/main/install.sh)
```

Or install a specific version:

```bash
VERSION=v1.0.0 bash <(curl -fsSL https://raw.githubusercontent.com/Mizoreww/awesome-claude-code-config/main/install.sh)
```

**Local install** (from clone):

```bash
git clone https://github.com/Mizoreww/awesome-claude-code-config.git
cd awesome-claude-code-config
./install.sh              # Install everything
./install.sh --dry-run    # Preview changes
```

### Default Installation (`--all`)

| Component | Included | Flag to install separately |
|-----------|----------|---------------------------|
| CLAUDE.md | Yes | `--claude-md` |
| settings.json | Yes (smart merge) | `--settings` |
| Rules (all languages) | Yes | `--rules [LANG...]` |
| Skills | Yes | `--skills` |
| lessons.md | Yes (skip if exists) | `--lessons` |
| Plugins (core, 14) | Yes | `--plugins` |
| Plugins (ai-research, 5) | No | `--plugins ai-research` |
| MCP (Lark, Codex CLI) | No | `--mcp` |

### Selective Install

```bash
./install.sh --rules python typescript  # Rules only
./install.sh --plugins                  # Core plugins only (14)
./install.sh --plugins all              # All plugins (19)
./install.sh --plugins ai-research      # AI research plugins only (5)
./install.sh --mcp                      # MCP (Lark, Codex CLI)
```

### Uninstall

```bash
./install.sh --uninstall                # Remove everything
./install.sh --uninstall --rules        # Remove rules only
./install.sh --uninstall --force        # Skip confirmation (CI/non-interactive)
```

### Version Info

```bash
./install.sh --version                  # Show source / installed / remote versions
```

## Key Features

### Self-Improvement Loop

1. User corrects Claude → auto-saved to `~/.claude/lessons.md`
2. Next session → `SessionStart` hook auto-injects lessons into context
3. Pattern confirmed → rule promoted to `CLAUDE.md`

### SessionStart Hook

`settings.json` includes two `SessionStart` hooks:
- **startup**: Injects lessons.md when a new session starts
- **compact**: Re-injects lessons.md after context compaction

Replaces the previous approach of requiring manual `Read lessons.md` in CLAUDE.md (more reliable).

### Statusline

A single-line status bar with gradient progress bars, powered by `hooks/statusline.sh`:

- **Model** + **directory** + **git branch**
- **Context window**: gradient bar (green → yellow → red) with percentage and size
- **5-hour usage**: pulled from `api.anthropic.com/api/oauth/usage` (cached 60s), shows reset countdown
- Progress bars are fixed-width (20 chars) with 16-step color gradients

Configured via `statusLine` in `settings.json`:

```json
"statusLine": {
  "type": "command",
  "command": "bash $HOME/.claude/hooks/statusline.sh"
}
```

### Smart Settings Merge

When `settings.json` already exists, the installer performs a smart merge (requires `jq`):

- **env**: Incoming values as defaults, existing values take priority
- **permissions.allow**: Union of both arrays (deduped)
- **enabledPlugins**: Merged, existing keys take priority
- **hooks.SessionStart**: Deduplicated by `matcher` field
- **statusLine**: Incoming config takes priority

Without `jq`, a manual merge warning is shown instead.

### Code Review via Codex CLI

CLAUDE.md includes a **Code Review** rule: whenever a code review is needed — whether requested by the user or triggered by a skill (e.g., `code-reviewer`, `simplify`) — Claude must invoke the `mcp__codex-cli__review` tool (powered by [codex-mcp-server](https://github.com/tuannvm/codex-mcp-server)) instead of providing text-only feedback. This enables cross-model review: Claude orchestrates while Codex performs the actual diff analysis.

Install the Codex CLI MCP server with `--mcp` to enable this feature.

### Layered Rules

```
common/       → Universal principles (always loaded)
  ↓ extended by
python/       → PEP 8, pytest, black, bandit
typescript/   → Zod, Playwright, Prettier
golang/       → gofmt, table-driven tests, gosec
```

### Plugin-First Approach

19 plugins across 5 marketplaces, organized into two groups:

**Core plugins** (14) — installed by default:

| Plugin | Marketplace | What It Does |
|--------|-------------|--------------|
| [**superpowers**](https://github.com/obra/superpowers) | claude-plugins-official | Brainstorming, debugging, code review, git worktrees, plan writing |
| [**everything-claude-code**](https://github.com/affaan-m/everything-claude-code) | everything-claude-code | TDD, security review, database patterns, Go/Python/Spring Boot |
| [**document-skills**](https://github.com/anthropics/skills) | anthropic-agent-skills | PDF, DOCX, PPTX, XLSX creation and manipulation |
| [**example-skills**](https://github.com/anthropics/skills) | anthropic-agent-skills | Frontend design, MCP builder, canvas design, algorithmic art |
| [**claude-mem**](https://github.com/thedotmack/claude-mem) | thedotmack | Persistent memory with smart search, timeline, AST-aware code search |
| **frontend-design** | claude-plugins-official | Production-grade frontend interfaces |
| [**context7**](https://github.com/upstash/context7) | claude-plugins-official | Up-to-date library documentation lookup |
| **code-review** | claude-plugins-official | Confidence-based code review |
| [**github**](https://github.com/github/github-mcp-server) | claude-plugins-official | GitHub integration (issues, PRs, workflows) |
| [**playwright**](https://github.com/microsoft/playwright-mcp) | claude-plugins-official | Browser automation, E2E testing, screenshots |
| **feature-dev** | claude-plugins-official | Guided feature development |
| **code-simplifier** | claude-plugins-official | Code simplification and refactoring |
| **ralph-loop** | claude-plugins-official | Session-aware AI assistant REPL |
| **commit-commands** | claude-plugins-official | Git commit, clean branches, commit-push-PR |

**AI Research plugins** (5) — install with `--plugins ai-research` or `--plugins all`:

| Plugin | Marketplace | What It Does |
|--------|-------------|--------------|
| [**fine-tuning**](https://github.com/Orchestra-Research/AI-Research-SKILLs) | ai-research-skills | Axolotl, LLaMA-Factory, PEFT, Unsloth |
| [**post-training**](https://github.com/Orchestra-Research/AI-Research-SKILLs) | ai-research-skills | GRPO, RLHF, DPO, SimPO |
| [**inference-serving**](https://github.com/Orchestra-Research/AI-Research-SKILLs) | ai-research-skills | vLLM, SGLang, TensorRT-LLM, llama.cpp |
| [**distributed-training**](https://github.com/Orchestra-Research/AI-Research-SKILLs) | ai-research-skills | DeepSpeed, FSDP, Megatron-Core, Ray Train |
| [**optimization**](https://github.com/Orchestra-Research/AI-Research-SKILLs) | ai-research-skills | AWQ, GPTQ, GGUF, Flash Attention, bitsandbytes |

See [`plugins/README.md`](plugins/README.md) for installation details.

### Version Changelog Policy

CLAUDE.md includes a **Version Changelog** rule: when making version-level changes (new features, major refactors, breaking changes), Claude proactively maintains a `CHANGELOG.md` in the project root with structured entries covering features, design rationale, and caveats. This keeps design decisions traceable alongside the code.

### Custom Skills

| Skill | Description |
|-------|-------------|
| **paper-reading** | Structured research paper summarization with auto-screenshot of key figures. Uses ar5iv HTML for arXiv papers, Playwright for figure capture, outputs standardized markdown (problem, method, experiments, insights). |

Place custom skills in `skills/<name>/SKILL.md`.

## Security Note

`settings.json` ships with `bypassPermissions` mode for power users. If you prefer safer defaults, change `defaultMode` to `"default"` and set `skipDangerousModePermissionPrompt` to `false`.

## Customization

- **Add a language**: Create `rules/<lang>/` extending common rules
- **Add a skill**: Place in `skills/<name>/SKILL.md`
- **Adapt CLAUDE.md**: Customize for your shell, package manager, and project context

## Acknowledgements

- [**Claude Code Best Practice**](https://github.com/shanraisshan/claude-code-best-practice) by shanraisshan — Comprehensive best practices, workflows, and implementation patterns for Claude Code
- [**Working for 10 Claude Codes**](https://mp.weixin.qq.com/s/9qPD3gXj3HLmrKC64Q6fbQ) by Hu Yuanming — Practical experience running multiple Claude Code instances in parallel
- [**Harness Engineering**](https://openai.com/index/harness-engineering/) by OpenAI — "Harness Engineering": engineers shift from writing code to designing systems, using agents to generate a million lines of code
- [**Claude Code in Action**](https://anthropic.skilljar.com/claude-code-in-action) by Anthropic Academy — Official course covering Claude Code integration, MCP servers, GitHub automation, and dev workflows

## License

MIT
