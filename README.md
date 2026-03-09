<!-- This is the source of truth. README.zh-CN.md is the Chinese translation. Keep both in sync. -->

**English** | [中文](./README.zh-CN.md) | [Codex Branch](https://github.com/Mizoreww/awesome-claude-code-config/tree/codex)

# Awesome Claude Code Configuration

![Statusline](assets/statusline.png)

Production-ready configuration for [Claude Code](https://claude.com/claude-code) — one-command install of global instructions, multi-language coding rules (Python / TypeScript / Go), 20 curated plugins, custom skills (paper-reading, [adversarial-review](https://github.com/poteto/noodle/tree/main/.agents/skills/adversarial-review)), custom status bar, MCP integration, and a self-improvement loop that remembers corrections across sessions.

## Directory Structure

```
.
├── CLAUDE.md              # Global instructions
├── settings.json          # Settings (permissions, plugins, hooks, model)
├── lessons.md             # Self-correction log template (auto-loaded via hook)
├── rules/                 # Multi-language coding standards (common + python/typescript/golang)
├── hooks/                 # Statusline with gradient progress bars (context + 5h usage)
├── mcp/                   # MCP server config (Lark-MCP)
├── plugins/               # Plugin installation guide (20 plugins, 5 marketplaces)
├── skills/                # Custom skills (paper-reading, adversarial-review)
├── VERSION                # Semantic version number
├── install.sh             # One-command installer (macOS / Linux)
└── install.ps1            # One-command installer (Windows PowerShell)
```

## Quick Start

### macOS / Linux

**One-line remote install** (no clone needed):

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Mizoreww/awesome-claude-code-config/main/install.sh)
```

**Local install** (from clone):

```bash
git clone https://github.com/Mizoreww/awesome-claude-code-config.git
cd awesome-claude-code-config
./install.sh              # Install everything
```

### Windows

**One-line remote install** (PowerShell, no clone needed):

```powershell
irm https://raw.githubusercontent.com/Mizoreww/awesome-claude-code-config/main/install.ps1 | iex
```

**From CMD**:

```cmd
powershell -c "irm https://raw.githubusercontent.com/Mizoreww/awesome-claude-code-config/main/install.ps1 | iex"
```

**Local install** (from clone):

```powershell
git clone https://github.com/Mizoreww/awesome-claude-code-config.git
cd awesome-claude-code-config
.\install.ps1             # Install everything
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
| Plugins (ai-research, 6) | No | `--plugins ai-research` |
| MCP (Lark) | No | `--mcp` |

### Selective Install

```bash
# Bash (macOS / Linux)
./install.sh --rules python typescript  # Rules only
./install.sh --plugins                  # Core plugins only (14)
./install.sh --plugins all              # All plugins (20)
./install.sh --plugins ai-research      # AI research plugins only (6)
./install.sh --mcp                      # MCP (Lark)
```

```powershell
# PowerShell (Windows)
.\install.ps1 -Rules python,typescript         # Rules only
.\install.ps1 -Plugins                         # Core plugins only (14)
.\install.ps1 -Plugins -PluginGroup all        # All plugins (20)
.\install.ps1 -Plugins -PluginGroup ai-research # AI research plugins only (6)
.\install.ps1 -Mcp                             # MCP (Lark)
```

### Uninstall

```bash
# Bash (macOS / Linux)
./install.sh --uninstall                # Remove everything (incl. plugins & MCP)
./install.sh --uninstall --rules        # Remove rules only
./install.sh --uninstall --force        # Skip confirmation (CI/non-interactive)
```

```powershell
# PowerShell (Windows)
.\install.ps1 -Uninstall                            # Remove everything (incl. plugins & MCP)
.\install.ps1 -Uninstall -UninstallComponents rules  # Remove rules only
.\install.ps1 -Uninstall -Force                      # Skip confirmation
```

### Version Info

```bash
./install.sh --version                  # Show source / installed / remote versions
```

```powershell
.\install.ps1 -Version                  # Show source / installed / remote versions
```

## Key Features

### Self-Improvement Loop

Two-tier memory with scope-based routing:

1. User corrects Claude → Claude judges scope: **cross-project** corrections go to `~/.claude/lessons.md`; **project-specific** preferences go to the project's `MEMORY.md`
2. Next session → `SessionStart` hook auto-injects global lessons; project `MEMORY.md` is auto-loaded by Claude Code
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

When `settings.json` already exists, the installer performs a smart merge (Bash version requires `jq`; PowerShell version uses built-in JSON support):

- **env**: Incoming values as defaults, existing values take priority
- **permissions.allow**: Union of both arrays (deduped)
- **enabledPlugins**: Merged, existing keys take priority
- **hooks.SessionStart**: Deduplicated by `matcher` field
- **statusLine**: Incoming config takes priority

Without `jq`, a manual merge warning is shown instead.

### Layered Rules

```
common/       → Universal principles (always loaded)
  ↓ extended by
python/       → PEP 8, pytest, black, bandit
typescript/   → Zod, Playwright, Prettier
golang/       → gofmt, table-driven tests, gosec
```

### Plugin-First Approach

20 plugins across 5 marketplaces, organized into two groups:

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

**AI Research plugins** (6) — install with `--plugins ai-research` or `--plugins all`:

| Plugin | Marketplace | What It Does |
|--------|-------------|--------------|
| [**tokenization**](https://github.com/Orchestra-Research/AI-Research-SKILLs) | ai-research-skills | HuggingFace Tokenizers, SentencePiece |
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
| **[adversarial-review](https://github.com/poteto/noodle/tree/main/.agents/skills/adversarial-review)** | Cross-model adversarial code review. Spawns reviewers on the opposite AI model (Claude ↔ Codex) with distinct critical lenses (Skeptic, Architect, Minimalist), then synthesizes a structured verdict (PASS/CONTESTED/REJECT). |

Place custom skills in `skills/<name>/SKILL.md`.

### Adversarial Code Review via Codex CLI

CLAUDE.md includes a **Code Review** rule: whenever a code review is needed — whether requested by the user or triggered by a skill (e.g., `code-reviewer`, `simplify`) — Claude invokes the `adversarial-review` skill (from [poteto/noodle](https://github.com/poteto/noodle/tree/main/.agents/skills/adversarial-review)). This skill spawns reviewers on the **opposite AI model's CLI** (`codex exec` for Claude users, `claude -p` for Codex users), producing cross-model adversarial analysis with structured verdicts (PASS / CONTESTED / REJECT).

Requires Codex CLI installed and `OPENAI_API_KEY` set in your environment.

## Security Note

`settings.json` ships with `bypassPermissions` mode for power users. If you prefer safer defaults, change `defaultMode` to `"default"` and set `skipDangerousModePermissionPrompt` to `false`.

## Customization

- **Add a language**: Create `rules/<lang>/` extending common rules
- **Add a skill**: Place in `skills/<name>/SKILL.md`
- **Adapt CLAUDE.md**: Customize for your shell, package manager, and project context

## Acknowledgements

- [**Claude Code in Action**](https://anthropic.skilljar.com/claude-code-in-action) by Anthropic Academy — Official course covering Claude Code integration, MCP servers, GitHub automation, and dev workflows
- [**Working for 10 Claude Codes**](https://mp.weixin.qq.com/s/9qPD3gXj3HLmrKC64Q6fbQ) by Hu Yuanming — Practical experience running multiple Claude Code instances in parallel
- [**Harness Engineering**](https://openai.com/index/harness-engineering/) by OpenAI — "Harness Engineering": engineers shift from writing code to designing systems, using agents to generate a million lines of code
- [**Claude Code Best Practice**](https://github.com/shanraisshan/claude-code-best-practice) by shanraisshan — Comprehensive best practices, workflows, and implementation patterns for Claude Code

## License

MIT
