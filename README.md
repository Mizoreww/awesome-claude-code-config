[Main English](https://github.com/Mizoreww/awesome-claude-code-config/blob/main/README.md) | [Main 中文](https://github.com/Mizoreww/awesome-claude-code-config/blob/main/README.zh-CN.md) | **Codex English** | [Codex 中文](./README.zh-CN.md)

# Codex Configuration

Production-ready configuration for [Codex CLI](https://github.com/openai/codex) — one-command install of global instructions, multi-agent roles, layered coding standards through skills, MCP integration, custom status bar, and a lessons-driven self-improvement loop. Companion branch to the [Claude Code main config](https://github.com/Mizoreww/awesome-claude-code-config/tree/main).

## Directory Structure

```
.
├── AGENTS.md              # Global instructions
├── config.toml            # Codex settings (model, permissions, MCP, lessons injection)
├── agents/                # Multi-agent role configs
├── lessons.md             # Self-correction source log
├── skills/                # Bundled local skills (paper-reading, adversarial-review, humanizer)
├── VERSION                # Installer version
└── install.sh             # One-command installer
```

## Quick Start

One-line remote install:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Mizoreww/awesome-claude-code-config/codex/install.sh)
```

Local install:

```bash
git clone -b codex https://github.com/Mizoreww/awesome-claude-code-config.git
cd awesome-claude-code-config
bash install.sh
```

Then restart Codex.

## Installer Options

```bash
./install.sh                         # install all (core + mcp + all skills)
./install.sh --core                 # only AGENTS.md / lessons.md / config.toml / agents/*
./install.sh --mcp                  # only MCP servers
./install.sh --skills core          # only core skill sets
./install.sh --skills ai-research   # only AI research skill sets
./install.sh --version              # source/installed/remote version info
./install.sh --uninstall --skills   # uninstall managed skills only
./install.sh --dry-run              # preview changes
```

## Key Features

### Self-Improvement Loop (Lessons Only)

1. User correction is recorded into `~/.codex/lessons.md`
2. New sessions auto-load `~/.codex/lessons.md`
3. Stable patterns are promoted into `~/.codex/AGENTS.md`

### Lessons Injection

`config.toml` uses:

```toml
model_instructions_file = "lessons.md"
```

This keeps correction rules active at session start.

### Multi-Agent Ready

`config.toml` ships with experimental multi-agent enabled and three default roles:

- `explorer`: code path exploration and evidence collection
- `reviewer`: correctness/regression/security-focused review
- `docs_researcher`: API/docs verification through OpenAI docs MCP + Context7

Role files live under `agents/*.toml` and are installed to `~/.codex/agents/`.

### Layered Rules via Skills

```
core behavior   → AGENTS.md
  ↓ reinforced by
skills/rules    → python-patterns, golang-patterns, frontend-patterns
```

This keeps common principles and language-specific practices aligned.

### Skill-First Setup

`install.sh` bootstraps practical skills from open-source ecosystems:

| Skill Set | Source | Coverage |
|----------|--------|----------|
| superpowers | [obra/superpowers](https://github.com/obra/superpowers) | full native superpowers set, including brainstorming, plan execution, review handoff, worktrees |
| everything-claude-code | [affaan-m/everything-claude-code](https://github.com/affaan-m/everything-claude-code) | language patterns, testing, security, verification |
| anthropic skills packs | [anthropics/skills](https://github.com/anthropics/skills) | document tools, frontend design, canvas/art, MCP builder |
| AI research skills | [zechenzhangAGI/AI-research-SKILLs](https://github.com/zechenzhangAGI/AI-research-SKILLs) | tokenization, fine-tuning, post-training, inference, distributed training, optimization |

Superpowers are installed using the repo's current native-discovery flow:
- clone to `~/.codex/superpowers`
- symlink `~/.codex/superpowers/skills` to `~/.agents/skills/superpowers`
- clean up the legacy partial-copy install (`using-superpowers`, `systematic-debugging`, `writing-plans`, `test-driven-development`) under `~/.codex/skills`

Bundled local skills in this repo:
- `paper-reading` (`skills/paper-reading/SKILL.md`) — structured research paper summarization
- `adversarial-review` (`skills/adversarial-review/SKILL.md`) — cross-model adversarial code review via opposite AI CLI (from [poteto/noodle](https://github.com/poteto/noodle/tree/main/.agents/skills/adversarial-review))
- `humanizer` (`skills/humanizer/SKILL.md`) — detect and remove AI writing patterns from text (from [blader/humanizer](https://github.com/blader/humanizer))

### Version Changelog Policy

AGENTS.md includes a **Version Changelog** rule: when making version-level changes (new features, major refactors, breaking changes), the agent proactively maintains a `CHANGELOG.md` in the project root with structured entries covering features, design rationale, and caveats. This keeps design decisions traceable alongside the code.

### MCP Integration

Default MCP servers in `config.toml`:

| Server | Purpose |
|--------|---------|
| Lark MCP | Feishu/Lark docs, sheets, chats, base ([repo](https://github.com/larksuite/lark-openapi-mcp)) |
| Context7 | up-to-date library documentation lookup ([repo](https://github.com/upstash/context7)) |
| GitHub | issue/PR/repo workflows ([repo](https://github.com/github/github-mcp-server)) |
| Playwright | browser automation and E2E testing ([repo](https://github.com/microsoft/playwright-mcp)) |
| OpenAI Developer Docs | official OpenAI docs MCP endpoint (`https://developers.openai.com/mcp`) |

## Installation Notes

1. Fill your own credentials:
   - `YOUR_APP_ID` / `YOUR_APP_SECRET` (Lark)
   - `YOUR_GITHUB_PAT` (GitHub MCP)
2. This config uses current Codex style (for example `web_search = "live"` at top-level).
3. If `~/.codex/config.toml` already exists, installer skips overwriting it; merge manually if needed.

### Adversarial Code Review

AGENTS.md includes a **Code Review** rule: whenever a code review is needed, invoke the `adversarial-review` skill (from [poteto/noodle](https://github.com/poteto/noodle/tree/main/.agents/skills/adversarial-review)). This skill spawns reviewers on the **opposite AI model's CLI** (`claude -p` for Codex users, `codex exec` for Claude users), producing cross-model adversarial analysis with structured verdicts (PASS / CONTESTED / REJECT).

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

- [**Claude Code Best Practice**](https://github.com/shanraisshan/claude-code-best-practice) by shanraisshan — Comprehensive best practices, workflows, and implementation patterns for Claude Code
- [**Working for 10 Claude Codes**](https://mp.weixin.qq.com/s/9qPD3gXj3HLmrKC64Q6fbQ) by Hu Yuanming — practical experience running multiple coding agents in parallel
- [**Harness Engineering**](https://openai.com/index/harness-engineering/) by OpenAI — engineers shift from writing code to designing systems with agents
- [**Anthropic Engineering**](https://www.anthropic.com/engineering) by Anthropic — Engineering blog covering agent development, evaluation methods, and building reliable AI systems
- [**OpenAI Engineering**](https://openai.com/news/engineering/) by OpenAI — Engineering blog sharing technical insights on building and scaling AI systems
- [**Claude Code in Action**](https://anthropic.skilljar.com/claude-code-in-action) by Anthropic Academy — official workflow training

## License

MIT
