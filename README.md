<!-- This is the source of truth. README.zh-CN.md is the Chinese translation. Keep both in sync. -->

**English** | [中文](./README.zh-CN.md) | [Codex Branch](https://github.com/Mizoreww/awesome-claude-code-config/tree/codex) | [Cursor Branch](https://github.com/Mizoreww/awesome-claude-code-config/tree/cursor) | [Changelog](./CHANGELOG.md)

# Awesome Claude Code Configuration

![Statusline](assets/statusline.png)

Production-ready configuration for [Claude Code](https://claude.com/claude-code). One-command install of global instructions, multi-language coding rules (Python / TypeScript / Go), 24 curated plugins across 9 marketplaces, seven bundled skills, a gradient status bar, and a self-improvement loop that remembers corrections across sessions.

## Showcase

![Claude Code Demo](images/claude-code-demo.png)

- [paper-reading skill — *Attention Is All You Need*](docs/Attention_Is_All_You_Need.md)
- [adversarial-review skill — worked example](docs/adversarial-review-showcase.md)

## Quick Start

**macOS / Linux**:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Mizoreww/awesome-claude-code-config/main/install.sh)
```

**Windows (PowerShell)**:

```powershell
irm https://raw.githubusercontent.com/Mizoreww/awesome-claude-code-config/main/install.ps1 | iex
```

Launches a two-level interactive selector. Append `--all` / `-All` to skip the menu and install everything non-interactively. Other flags: `--dry-run`, `--uninstall`, `--version` (PowerShell: `-DryRun`, `-Uninstall`, `-Version`).

```
  > [5/5] Core                   Global instructions, settings, rules...
    [0/3] Language Rules          Python / TypeScript / Go
    [2/3] Review                  code-review + adversarial-review
    [9/10] Workflow                karpathy, superpowers, update-config, handoff...
    [3/3] Integrations            context7, github, playwright
    [4/5] Design & Content        document-skills, frontend-design, humanizer...
    [0/3] Memory & Lifestyle      claude-mem, claude-health, PUA
    [1/10] Academic Research      paper-reading, deepxiv-cli...
    [0/1] MCP Servers             Lark/Feishu
```

- **Main menu**: ↑↓ navigate groups, **Enter or →** open a group's sub-menu, **q** quit. Arrow to *Submit* and press Enter to install.
- **Sub-menu**: ↑↓ navigate items, **Space** toggle, **← or Esc** back to main menu (same as pressing Enter on *[ Back ]*).
- Shortcuts (any level): **a** all on, **n** all off, **d** defaults; in sub-menus these only affect that group.
- The Review group's `adversarial-review` and `codex` are mutually exclusive — selecting one deselects the other.

**Core (5)** — foundational files, all on by default.

| Item | What It Does | Default |
|------|--------------|---------|
| CLAUDE.md | Global instructions template | on |
| settings.json | Smart-merged Claude Code settings | on |
| Common rules | `rules/common/` — coding style, git, security, testing | on |
| StatusLine | Gradient progress bar & 5h usage (`hooks/statusline.sh`) | on |
| Lessons | `lessons.md` template + `SessionStart` hook | on |

**Language Rules (3)** — off by default, enable only what your projects use.

| Item | What It Does | Default |
|------|--------------|---------|
| Python rules | PEP 8, pytest, type hints, bandit | off |
| TypeScript rules | Zod, Playwright, immutability | off |
| Go rules | gofmt, table-driven tests, gosec | off |

**Review (3)** — `adversarial-review` and `codex` are mutually exclusive.

| Item | Source | What It Does | Default |
|------|--------|--------------|---------|
| **code-review** | claude-plugins-official (plugin) | Confidence-based PR code review | on |
| [**adversarial-review**](https://github.com/poteto/noodle/blob/main/.agents/skills/adversarial-review/SKILL.md) | bundled skill | Cross-model review (Skeptic / Architect / Minimalist lenses) | on |
| [**codex**](https://github.com/openai/codex-plugin-cc) | openai-codex (plugin) | Codex CLI-backed adversarial review | off |

**Workflow (10)** — planning, iteration, code quality, meta-config.

| Item | Source | What It Does | Default |
|------|--------|--------------|---------|
| [**andrej-karpathy-skills**](https://github.com/forrestchang/andrej-karpathy-skills) | karpathy-skills (plugin) | Karpathy coding guidelines: Think-First, Simplicity, Surgical, Goal-Driven | on |
| [**superpowers**](https://github.com/obra/superpowers) | claude-plugins-official | Brainstorming, debugging, code review, git worktrees, plan writing | on |
| **feature-dev** | claude-plugins-official | Guided feature development | on |
| **ralph-loop** | claude-plugins-official | Automated iteration loop (session-aware REPL) | on |
| **commit-commands** | claude-plugins-official | Git commit / push / PR workflow | on |
| **code-simplifier** | claude-plugins-official | Code simplification and refactoring | on |
| [**everything-claude-code**](https://github.com/affaan-m/everything-claude-code) | everything-claude-code | TDD, security, database, Go/Python/Spring Boot | off |
| [**update-config**](skills/update-config/) | bundled skill | `/update-config` — re-run installer from inside a session | on |
| [**handoff**](https://github.com/mattpocock/skills/blob/main/skills/productivity/handoff/SKILL.md) | bundled skill | Compact the current conversation into a handoff doc for the next agent | on |
| [**teach**](https://github.com/mattpocock/skills/blob/main/skills/productivity/teach/SKILL.md) | bundled skill | Teach a topic over multiple sessions (mission, lessons, learning records) | on |

**Integrations (3)** — external tools and services.

| Item | Source | What It Does | Default |
|------|--------|--------------|---------|
| [**context7**](https://github.com/upstash/context7) | claude-plugins-official | Up-to-date library documentation lookup | on |
| [**github**](https://github.com/github/github-mcp-server) | claude-plugins-official | GitHub integration (issues, PRs, workflows) | on |
| [**playwright**](https://github.com/microsoft/playwright-mcp) | claude-plugins-official | Browser automation, E2E testing, screenshots | on |

**Design & Content (5)** — documents, UI, creative artifacts, text humanization.

| Item | Source | What It Does | Default |
|------|--------|--------------|---------|
| [**document-skills**](https://github.com/anthropics/skills) | anthropic-agent-skills | PDF, DOCX, PPTX, XLSX creation and manipulation | on |
| [**example-skills**](https://github.com/anthropics/skills) | anthropic-agent-skills | Frontend design, MCP builder, canvas, algorithmic art | on |
| **frontend-design** | claude-plugins-official | Production-grade frontend interfaces | on |
| [**humanizer**](https://github.com/blader/humanizer) | bundled skill | Remove AI writing patterns (English) | on |
| [**humanizer-zh**](https://github.com/op7418/Humanizer-zh) | bundled skill | Remove AI writing patterns (Chinese) | off |

**Memory & Lifestyle (3)** — session memory and personal productivity, all off by default.

| Item | Source | What It Does | Default |
|------|--------|--------------|---------|
| [**claude-mem**](https://github.com/thedotmack/claude-mem) | thedotmack | Persistent memory with smart search, timeline, AST-aware code search | off |
| [**claude-health**](https://github.com/tw93/claude-health) | claude-health | Health check & wellness dashboard for Claude Code sessions | off |
| [**PUA**](https://github.com/tanweai/pua) | pua-skills | AI agent productivity booster (CN / EN / JA) | off |

**Academic Research (10)** — training / inference plugins + paper-reading skills, off by default except `paper-reading`.

| Item | Source | What It Does | Default |
|------|--------|--------------|---------|
| [**paper-reading**](skills/paper-reading/) | bundled skill | Research paper summarization with figure extraction | on |
| [**tokenization**](https://github.com/Orchestra-Research/AI-Research-SKILLs) | ai-research-skills | HuggingFace Tokenizers, SentencePiece | off |
| [**fine-tuning**](https://github.com/Orchestra-Research/AI-Research-SKILLs) | ai-research-skills | Axolotl, LLaMA-Factory, PEFT, Unsloth | off |
| [**post-training**](https://github.com/Orchestra-Research/AI-Research-SKILLs) | ai-research-skills | GRPO, RLHF, DPO, SimPO | off |
| [**inference-serving**](https://github.com/Orchestra-Research/AI-Research-SKILLs) | ai-research-skills | vLLM, SGLang, TensorRT-LLM, llama.cpp | off |
| [**distributed-training**](https://github.com/Orchestra-Research/AI-Research-SKILLs) | ai-research-skills | DeepSpeed, FSDP, Megatron-Core, Ray Train | off |
| [**optimization**](https://github.com/Orchestra-Research/AI-Research-SKILLs) | ai-research-skills | AWQ, GPTQ, GGUF, Flash Attention, bitsandbytes | off |
| [**deepxiv-cli**](https://github.com/DeepXiv/deepxiv_sdk) | DeepXiv (GitHub) | arXiv/PMC paper search & reading CLI (hybrid BM25+Vector, 2M+ papers) | off |
| [**deepxiv-trending-digest**](https://github.com/DeepXiv/deepxiv_sdk) | DeepXiv (GitHub) | Markdown digests of trending papers (last 7 days) | off |
| [**deepxiv-baseline-table**](https://github.com/DeepXiv/deepxiv_sdk) | DeepXiv (GitHub) | Build baseline comparison tables from research papers | off |

**MCP Servers (1)** — non-plugin MCP integrations, off by default.

| Item | Source | What It Does | Default |
|------|--------|--------------|---------|
| [**Lark MCP server**](https://github.com/larksuite/lark-openapi-mcp) | `mcp/` | Feishu / Lark integration (replace `YOUR_APP_ID`/`YOUR_APP_SECRET` after install) | off |

## Directory Structure

```
.
├── CLAUDE.md              # Global instructions
├── settings.json          # Permissions, plugins, hooks, model
├── lessons.md             # Self-correction log template (auto-loaded via hook)
├── rules/                 # Coding standards (common + python/typescript/golang)
├── hooks/                 # Statusline with gradient progress bars
├── mcp/                   # MCP server config (Lark-MCP)
├── plugins/               # Plugin catalogue & install guide
├── skills/                # Bundled custom skills
├── docs/                  # Paper summaries, showcases
└── install.sh / install.ps1
```

## Key Mechanisms

- **Layered rules** — `rules/common/` (universal) extended by per-language directories. Each file references a deeper skill for patterns, testing, security.
- **Statusline** — model, directory, venv, git branch, context window (gradient bar), 5-hour usage countdown. Script at `hooks/statusline.sh`.
- **Self-improvement loop** — corrections route to `~/.claude/lessons.md` (cross-project) or project `MEMORY.md` (local). `SessionStart` hooks re-inject them on startup and after context compaction.
- **Plugin catalogue & marketplace URLs** — full list with install commands: [plugins/README.md](plugins/README.md).

## Settings Defaults

`settings.json` ships with high-performance defaults. Unknown keys are ignored by older Claude Code; only `auto` mode is version-gated (installer auto-downgrades to `bypassPermissions` below 2.1.80).

| Key | Value | Effect |
|-----|-------|--------|
| `permissions.defaultMode` | `auto` | Auto-approve safe actions, block risky ones |
| `effortLevel` | `max` | Pin `/effort` to highest reasoning tier |
| `betas` | `extended-cache-ttl-2025-04-11` | 1-hour prompt cache (vs default 5 min) |
| `env.CLAUDE_CODE_NO_FLICKER` | `1` | Fullscreen rendering |
| `env.CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING` | `1` | Fixed thinking budget (no effect on Opus 4.7) |

Smart merge on re-install preserves your overrides for `env`, `permissions.allow`, `enabledPlugins`, `hooks.SessionStart`, and `statusLine`. Third-party plugins in your `enabledPlugins` that are outside this catalogue are left untouched.

## Customization

- **Add a language**: create `rules/<lang>/` extending `rules/common/`
- **Add a skill**: place in `skills/<name>/SKILL.md`
- **Adapt CLAUDE.md**: tune for your shell, package manager, project context

## Acknowledgements

- [Claude Code in Action](https://anthropic.skilljar.com/claude-code-in-action) — Anthropic Academy's official course
- [Working for 10 Claude Codes](https://mp.weixin.qq.com/s/9qPD3gXj3HLmrKC64Q6fbQ) by Hu Yuanming — multi-instance patterns
- [Harness Engineering](https://openai.com/index/harness-engineering/) by OpenAI
- [Anthropic Engineering](https://www.anthropic.com/engineering) / [OpenAI Engineering](https://openai.com/news/engineering/)
- [Claude Code Best Practice](https://github.com/shanraisshan/claude-code-best-practice) by shanraisshan
- [Claude How To](https://github.com/luongnv89/claude-howto) by luongnv89

## License

MIT
