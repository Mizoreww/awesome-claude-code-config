[Claude Main Branch](https://github.com/Mizoreww/claude-code-config/tree/main) | [中文 README（main）](https://github.com/Mizoreww/claude-code-config/blob/main/README.zh-CN.md) | **English** | [中文](./README.zh-CN.md)

# Codex Configuration

Production-ready configuration for Codex: global instructions, Codex-native persistent memory, layered coding standards through skills, MCP integration, and one-command bootstrap.

## Directory Structure

```
.
├── AGENTS.md              # Global instructions
├── config.toml            # Codex settings (model, permissions, MCP, MEMORY.md injection)
├── lessons.md             # Self-correction source log
├── codex-mem/             # Codex-native memory CLI
├── skills/
│   ├── codex-mem/         # Umbrella memory skill
│   └── mem-search/        # Codex-compatible memory retrieval skill
└── install.sh             # One-command installer
```

## Quick Start

```bash
git clone -b codex https://github.com/Mizoreww/claude-code-config.git
cd claude-code-config
bash install.sh
```

Then restart Codex.

## Key Features

### Self-Improvement + Persistent Memory Loop

1. User correction is recorded into `~/.codex/lessons.md`
2. `codex-mem` writes searchable observations into `~/.codex/memory/codex_mem.db`
3. `codex-mem build-context` compiles lessons + observations into `~/.codex/MEMORY.md`
4. New sessions auto-load `~/.codex/MEMORY.md`
5. Stable patterns are promoted into `~/.codex/AGENTS.md`

### Codex-Native Memory Injection

`config.toml` uses:

```toml
model_instructions_file = "~/.codex/MEMORY.md"
```

This keeps lessons and long-term memory context active in one auto-loaded file.

### `codex-mem` (Inspired by claude-mem, built for Codex)

Installed to: `~/.codex/bin/codex-mem`

```bash
# Add observation
~/.codex/bin/codex-mem note --type decision --title "..." --details "..."

# Retrieve memory
~/.codex/bin/codex-mem search --project "$(pwd)" --query "auth retry"
~/.codex/bin/codex-mem timeline --project "$(pwd)" --query "auth retry"
~/.codex/bin/codex-mem get --ids 12,15

# Refresh auto-loaded context
~/.codex/bin/codex-mem build-context --project "$(pwd)" --output ~/.codex/MEMORY.md --lessons ~/.codex/lessons.md
```

### Layered Rules via Skills

```
core behavior   → AGENTS.md
  ↓ reinforced by
skills/rules    → claude-rules, python-patterns, golang-patterns, frontend-patterns
```

This keeps common principles and language-specific practices aligned.

### Skill-First Setup

`install.sh` bootstraps practical skills from open-source ecosystems:

| Skill Set | Source | Coverage |
|----------|--------|----------|
| superpowers | [obra/superpowers](https://github.com/obra/superpowers) | planning, debugging, TDD workflows |
| everything-claude-code | [affaan-m/everything-claude-code](https://github.com/affaan-m/everything-claude-code) | language patterns, testing, security, verification |
| anthropic skills packs | [anthropics/skills](https://github.com/anthropics/skills) | document tools, frontend design, canvas/art, MCP builder |
| claude-mem workflows | [thedotmack/claude-mem](https://github.com/thedotmack/claude-mem) | planning/execution skills (`make-plan`, `do`) |
| codex-mem (local) | this repo | Codex-native persistent memory (`codex-mem`, `mem-search`, `MEMORY.md` sync) |
| AI research skills | [zechenzhangAGI/AI-research-SKILLs](https://github.com/zechenzhangAGI/AI-research-SKILLs) | fine-tuning, post-training, inference, distributed training, optimization |

### MCP Integration

Default MCP servers in `config.toml`:

| Server | Purpose |
|--------|---------|
| Lark MCP | Feishu/Lark docs, sheets, chats, base ([repo](https://github.com/larksuite/lark-openapi-mcp)) |
| Context7 | up-to-date library documentation lookup ([repo](https://github.com/upstash/context7)) |
| GitHub | issue/PR/repo workflows ([repo](https://github.com/github/github-mcp-server)) |
| Playwright | browser automation and E2E testing ([repo](https://github.com/microsoft/playwright-mcp)) |

## Installation Notes

1. Fill your own credentials:
   - `YOUR_APP_ID` / `YOUR_APP_SECRET` (Lark)
   - `YOUR_GITHUB_PAT` (GitHub MCP)
2. This config uses current Codex style (for example `web_search = "live"` at top-level).
3. If `~/.codex/config.toml` already exists, merge manually.

## Security Note

Template defaults are power-user oriented:
- `approval_policy = "never"`
- `sandbox_mode = "danger-full-access"`

If you prefer safer defaults, adjust these in `~/.codex/config.toml`.

## Customization

- **Adjust global behavior**: edit `AGENTS.md`
- **Add local rules**: extend skills in `~/.codex/skills`
- **Tune model/runtime**: edit `config.toml`
- **Enable/disable MCP servers**: edit MCP sections in `config.toml` or use `codex mcp` commands

## Acknowledgements

- [**AI Agent Workflow Orchestration Guidelines**](https://gist.github.com/OmerFarukOruc/a02a5883e27b5b52ce740cadae0e4d60) by [@OmerFarukOruc](https://github.com/OmerFarukOruc) — Inspiration for workflow orchestration
- [**Harness Engineering**](https://openai.com/index/harness-engineering/) by OpenAI — engineers shift from writing code to designing systems with agents
- [**Working for 10 Claude Codes**](https://mp.weixin.qq.com/s/9qPD3gXj3HLmrKC64Q6fbQ) by Hu Yuanming — practical experience running multiple coding agents in parallel
- [**Claude Code in Action**](https://anthropic.skilljar.com/claude-code-in-action) by Anthropic Academy — official workflow training
- [**ChatGPT Prompt Engineering for Developers**](https://www.deeplearning.ai/short-courses/chatgpt-prompt-engineering-for-developers/) by DeepLearning.AI & OpenAI — prompt engineering foundations

## License

MIT
