[Source English](https://github.com/Mizoreww/awesome-claude-code-config/blob/main/README.md) | [Source 中文](https://github.com/Mizoreww/awesome-claude-code-config/blob/main/README.zh-CN.md) | **Codex English** | [Codex 中文](./README.zh-CN.md)

# Codex Configuration

Production-ready configuration for [Codex CLI](https://github.com/openai/codex) — an interactive installer plus one-command full install of global instructions, multi-agent roles, layered coding standards through skills, MCP integration, and a lessons-driven self-improvement loop. This branch is Codex-first and keeps a small compatibility bridge for users migrating from the [Claude Code main config](https://github.com/Mizoreww/awesome-claude-code-config/tree/main).

## Directory Structure

```
.
├── AGENTS.md              # Global instructions
├── config.toml            # Codex settings (model, permissions, MCP, lessons injection)
├── agents/                # Multi-agent role configs
├── docs/                  # Migration notes and support docs
├── lessons.md             # Self-correction source log
├── skills/                # Bundled local skills (paper-reading, adversarial-review, handoff, humanizer, update)
├── VERSION                # Installer version
└── install.sh / install.ps1
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

## Interactive Installer

The Codex branch now uses the same two-level interactive selector UX on both shells, and the menu groups, defaults, and install targets are Codex-native.

### Bash

```bash
bash install.sh
bash install.sh --all
bash install.sh --dry-run
```

### PowerShell

```powershell
pwsh -NoProfile -File .\install.ps1
pwsh -NoProfile -File .\install.ps1 -All
pwsh -NoProfile -File .\install.ps1 -DryRun
```

Behavior notes:

- Bash plain no-arg runs are interactive when a terminal is available; if it cannot open a terminal, it warns and falls back to a non-interactive full install.
- PowerShell plain no-arg runs are interactive when console I/O is available; if it cannot use the console, it warns and falls back to a non-interactive full install.
- In Bash, `--dry-run` previews the full install non-interactively.
- In PowerShell, `-DryRun` alone previews the full install non-interactively.
- Both shells treat an empty interactive submission as a no-op (nothing is installed and no version stamp is written).

### Codex menu groups and defaults

| Group | Items | Default |
|-------|-------|---------|
| Core | `AGENTS.md`, `config.toml`, `lessons.md` | On |
| Agents | `explorer`, `reviewer`, `docs-researcher` | On |
| Skills — Recommended | `superpowers`, `document-skills`, `example-skills`, `coding-foundations`, `paper-reading`, `humanizer`, `humanizer-zh`, `handoff`, `adversarial-review`, `update` | On except `humanizer-zh` |
| Skills — AI Research | `tokenization`, `fine-tuning`, `post-training`, `distributed-training`, `inference-serving`, `optimization`, `deepxiv` | Off |
| MCP Servers | `context7`, `github`, `playwright`, `openaiDeveloperDocs`, `lark-mcp` | On except `github` and `lark-mcp` (need credentials) |

## Installer Options

```bash
./install.sh                         # interactive selector when a terminal is available
./install.sh --all                   # non-interactive full install
./install.sh --core                  # only AGENTS.md / lessons.md / config.toml / agents/*
./install.sh --mcp                   # only MCP servers
./install.sh --skills core           # only core skill sets
./install.sh --skills ai-research    # only AI research skill sets
./install.sh --version               # source/installed/remote version info
./install.sh --uninstall --skills    # uninstall managed skills only
./install.sh --dry-run               # non-interactive full preview
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
| coding-foundations | [affaan-m/everything-claude-code](https://github.com/affaan-m/everything-claude-code) | language patterns, testing, security, verification (Codex-facing label for this upstream pack) |
| anthropic skills packs | [anthropics/skills](https://github.com/anthropics/skills) | document tools, frontend design, canvas/art, MCP builder |
| DeepXiv skills | [DeepXiv/deepxiv_sdk](https://github.com/DeepXiv/deepxiv_sdk) | latest DeepXiv research workflows (`deepxiv-cli`, `deepxiv-baseline-table`, `deepxiv-trending-digest`) fetched fresh during install |
| AI research skills | [zechenzhangAGI/AI-research-SKILLs](https://github.com/zechenzhangAGI/AI-research-SKILLs) | tokenization, fine-tuning, post-training, inference, distributed training, optimization |

Superpowers are installed using the repo's current native-discovery flow:
- clone to `~/.codex/superpowers`
- symlink `~/.codex/superpowers/skills` to `~/.agents/skills/superpowers`
- clean up the legacy partial-copy install (`using-superpowers`, `systematic-debugging`, `writing-plans`, `test-driven-development`) under `~/.codex/skills`

Bundled local skills in this repo:
- `paper-reading` (`skills/paper-reading/SKILL.md`) — structured research paper summarization
- `adversarial-review` (`skills/adversarial-review/SKILL.md`) — cross-model adversarial code review via opposite AI CLI (from [poteto/noodle](https://github.com/poteto/noodle/tree/main/.agents/skills/adversarial-review))
- `handoff` (`skills/handoff/SKILL.md`) — compact the current conversation into a handoff document
- `humanizer` (`skills/humanizer/SKILL.md`) — detect and remove AI writing patterns from text (from [blader/humanizer](https://github.com/blader/humanizer))
- `humanizer-zh` (`skills/humanizer-zh/SKILL.md`) — remove AI writing patterns from Chinese text
- `update` (`skills/update/SKILL.md`) — update the installed Codex config to the latest `codex` branch version

DeepXiv skills are refreshed from upstream on every `install.sh` run, similar to superpowers:
- `deepxiv-cli`
- `deepxiv-baseline-table`
- `deepxiv-trending-digest`

For Codex users, no separate local `deepxiv` CLI installation is required. Keeping these skills refreshed inside Codex is enough for the supported workflow in this repo.

### Version Changelog Policy

AGENTS.md includes a **Version Changelog** rule: when making version-level changes (new features, major refactors, breaking changes), the agent proactively maintains a `CHANGELOG.md` in the project root with structured entries covering features, design rationale, and caveats. This keeps design decisions traceable alongside the code.

### MCP Integration

Default MCP servers in `config.toml`:

| Server | Purpose |
|--------|---------|
| Lark MCP | Feishu/Lark docs, sheets, chats, base — commented out by default, needs credentials ([repo](https://github.com/larksuite/lark-openapi-mcp)) |
| Context7 | up-to-date library documentation lookup ([repo](https://github.com/upstash/context7)) |
| GitHub | issue/PR/repo workflows — commented out by default, needs a PAT ([repo](https://github.com/github/github-mcp-server)) |
| Playwright | browser automation and E2E testing ([repo](https://github.com/microsoft/playwright-mcp)) |
| OpenAI Developer Docs | official OpenAI docs MCP endpoint (`https://developers.openai.com/mcp`) |

## Installation Notes

1. The Lark and GitHub MCP entries ship commented out in `config.toml`. To enable them, fill your own credentials and uncomment the blocks:
   - `YOUR_APP_ID` / `YOUR_APP_SECRET` (Lark)
   - `YOUR_GITHUB_PAT` (GitHub MCP)
2. This config uses current Codex style (for example `web_search = "live"` at top-level).
3. If `~/.codex/config.toml` already exists, installer skips overwriting it; merge manually if needed.

### Adversarial Code Review

AGENTS.md includes a **Code Review** rule: whenever a code review is needed, invoke the `adversarial-review` skill (from [poteto/noodle](https://github.com/poteto/noodle/tree/main/.agents/skills/adversarial-review)). In Codex sessions, this skill can call the opposite model's CLI (`claude -p`) to produce cross-model adversarial analysis with structured verdicts (PASS / CONTESTED / REJECT); the reciprocal `codex exec` path remains documented inside the skill for compatibility with other environments.

## Compatibility for users migrating from the Claude Code main branch

See [`docs/claude-main-to-codex-migration.md`](./docs/claude-main-to-codex-migration.md) for a concrete mapping of:

- `CLAUDE.md` → `AGENTS.md`
- `settings.json` → `config.toml`
- Claude-era plugins → Codex skills / MCP / built-ins
- `mcp/mcp-servers.json` → `[mcp_servers.*]` in `config.toml`

## Security Note

Template defaults are conservative:
- `approval_policy = "on-request"`
- `sandbox_mode = "workspace-write"`

If you prefer full autonomy, switch these to `approval_policy = "never"` and `sandbox_mode = "danger-full-access"` in `~/.codex/config.toml`.

## Customization

- **Adjust global behavior**: edit `AGENTS.md`
- **Add local rules**: extend skills in `~/.codex/skills`
- **Tune model/runtime**: edit `config.toml`
- **Enable/disable MCP servers**: edit MCP sections in `config.toml` or use `codex mcp` commands

## Acknowledgements

- [**Harness Engineering**](https://openai.com/index/harness-engineering/) by OpenAI — engineers shift from writing code to designing systems with agents
- [**Anthropic Engineering**](https://www.anthropic.com/engineering) by Anthropic — Engineering blog covering agent development, evaluation methods, and building reliable AI systems
- [**OpenAI Engineering**](https://openai.com/news/engineering/) by OpenAI — Engineering blog sharing technical insights on building and scaling AI systems

## License

MIT
