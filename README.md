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
├── lessons.md             # This project's correction log (created/maintained on demand)
├── templates/             # Blank global lessons seed installed into ~/.codex
├── skills/                # Bundled local skills (paper-reading, neat-freak, storage-analyzer, handoff, ...)
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

- Bash plain no-arg runs are interactive when a terminal is available; if it cannot open a terminal, it warns and falls back to the standard non-interactive install. Opt-in ResearchStudio, PPT Master, and Storage Analyzer remain excluded.
- PowerShell plain no-arg runs are interactive when console I/O is available; if it cannot use the console, it warns and falls back to the standard non-interactive install. Opt-in ResearchStudio, PPT Master, and Storage Analyzer remain excluded.
- In Bash, `--dry-run` previews the standard install non-interactively without opting into ResearchStudio, PPT Master, or Storage Analyzer.
- In PowerShell, `-DryRun` alone previews the standard install non-interactively without opting into ResearchStudio, PPT Master, or Storage Analyzer.
- `--all` / `-All`, or an explicit `--skills all` / `-Skills -SkillGroup all`, includes Storage Analyzer. A bare `--skills` / `-Skills` keeps it off.
- Interactive selections are authoritative for installer-owned skills: on a repeat install, owned skills left unchecked are removed (even if their files were edited), while unowned/custom skills are preserved even if a custom skill has the same name as a catalog entry. Ownership is recorded in `~/.codex/.awesome-claude-code-config-managed-skills`; the first upgraded run adopts only unchanged bundled copies, Codex-owned copies with the expected lock source and a matching legacy staging tree, or a verified superpowers fallback. The legacy `.agents` comparison is only a one-time ownership-safety check; the final Codex source is always `~/.codex/skills`. Verified leftovers from the retired `coding-foundations` pack are cleanup-only and are removed because they no longer have a menu choice.
- If no skills are selected and owned skills would be removed, the installer asks for confirmation before clearing them. It does not delete `.system`, unowned shared-agent or custom skills, core files, or MCP configuration.
- Explicit non-interactive component flags (`--all`, `--core`, `--mcp`, `--skills` and their PowerShell equivalents) remain additive and do not reconcile prior skill selections.

### Codex menu groups and defaults

| Group | Items | Default |
|-------|-------|---------|
| Core | `AGENTS.md`, `config.toml`, `StatusLine`, global `lessons.md`, `explorer`, `reviewer`, `docs-researcher` | On |
| Review | `code-review`, `adversarial-review` | `code-review` on; `adversarial-review` off |
| Workflow | `andrej-karpathy-skills`, `superpowers`, `mattpocock/skills`, `handoff`, `neat-freak`, `update-config` | On except `superpowers` |
| Development Tools | `context7`, `github`, `playwright`, `openaiDeveloperDocs` | On; `github` requires `GITHUB_PERSONAL_ACCESS_TOKEN` |
| Design & Content | `document-skills`, `example-skills`, `frontend-design`, `humanizer`, `humanizer-zh` | On except `humanizer-zh` |
| Lifestyle | `PUA` | Off |
| Storage | `storage-analyzer` | Off |
| Academic Research | `paper-reading`, `ResearchStudio Idea`, `ResearchStudio Reel`, `tokenization`, `fine-tuning`, `post-training`, `distributed-training`, `inference-serving`, `optimization`, `deepxiv` | `paper-reading` on; others off |
| Slides | `frontend-slides`, `ppt-master` | Both off |
| MCP Servers | `lark-mcp` | Off (needs credentials) |

## Installer Options

```bash
./install.sh                         # interactive selector when a terminal is available
./install.sh --all                   # non-interactive full install
./install.sh --core                  # AGENTS.md / blank global lessons.md / config.toml / agents/*
./install.sh --mcp                   # only MCP servers
./install.sh --skills core           # only core skill sets
./install.sh --skills ai-research    # only AI research skill sets
./install.sh --version               # source/installed/remote version info
./install.sh --uninstall --skills    # uninstall managed skills only
./install.sh --dry-run               # non-interactive full preview
./install.sh --force                 # skip uninstall / empty-skill-removal confirmations
```

## Key Features

### Self-Improvement Loop (Scoped Lessons)

1. A correction tied to the active repository is written to `<project-root>/lessons.md`; the agent creates that file on the first project correction, like an on-demand `CHANGELOG.md`.
2. Only genuinely cross-project corrections are written to `~/.codex/lessons.md`.
3. New sessions auto-load the global log, while `AGENTS.md` tells Codex to locate the current project root and read its `lessons.md` when present.
4. Stable cross-project patterns can be promoted into `~/.codex/AGENTS.md`.

### Lessons Injection

`config.toml` uses:

```toml
model_instructions_file = "lessons.md"
```

This injects only the blank-initialized global correction log. Project lessons are never copied into `~/.codex`; they are discovered from the active project root.

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
| mattpocock/skills | [mattpocock/skills](https://github.com/mattpocock/skills) | Pinned v1.1 workflows for `ask-matt`, grilling/design, research, specs/tickets, wayfinding, implementation, triage, TDD, architecture and domain modeling |
| superpowers | [obra/superpowers](https://github.com/obra/superpowers) | full native superpowers set, including brainstorming, plan execution, review handoff, worktrees; installed via `npx skills` with git/junction fallback |
| andrej-karpathy-skills | [forrestchang/andrej-karpathy-skills](https://github.com/forrestchang/andrej-karpathy-skills) | Karpathy-style coding guidelines via `npx skills` |
| anthropic skills packs | [anthropics/skills](https://github.com/anthropics/skills) | document tools, frontend design, canvas/art, MCP builder |
| DeepXiv skills | [DeepXiv/deepxiv_sdk](https://github.com/DeepXiv/deepxiv_sdk) | latest DeepXiv research workflows (`deepxiv-cli`, `deepxiv-baseline-table`, `deepxiv-trending-digest`) fetched fresh during install |
| ResearchStudio Idea | [microsoft/ResearchStudio](https://github.com/microsoft/ResearchStudio) | opt-in research ideation, paper search, and novelty checking copied from the official source tree |
| ResearchStudio Reel | [microsoft/ResearchStudio](https://github.com/microsoft/ResearchStudio/tree/main/ResearchStudio-Reel) | default-off paper-to-assets, poster, video, blog, and interactive-reel workflows copied from the official source tree |
| neat-freak | [KKKKhazix/khazix-skills at `2b4a645`](https://github.com/KKKKhazix/khazix-skills/tree/2b4a645cfdc894156ae347d897723562f719ce95/neat-freak) | default-on vendored project knowledge and governance closeout workflow |
| storage-analyzer | [KKKKhazix/khazix-skills at `fcba3ad`](https://github.com/KKKKhazix/khazix-skills/tree/fcba3adcf5def1ccd4bb688de93060227471b129/storage-analyzer) | default-off vendored disk-usage analysis and interactive cleanup report; this modified copy adds Linux support and security hardening ([provenance](skills/storage-analyzer/UPSTREAM.md), [upstream PR #50](https://github.com/KKKKhazix/khazix-skills/pull/50)) |
| AI research skills | [zechenzhangAGI/AI-research-SKILLs](https://github.com/zechenzhangAGI/AI-research-SKILLs) | tokenization, fine-tuning, post-training, inference, distributed training, optimization |
| frontend-slides | [zarazhangrui/frontend-slides](https://github.com/zarazhangrui/frontend-slides) | slide generation skill via `npx skills`; default off |
| ppt-master | [hugohe3/ppt-master](https://github.com/hugohe3/ppt-master) | default-off native editable PPTX workflow; installs only the skill definition and defers runtime setup until first use |
| PUA | [tanweai/pua](https://github.com/tanweai/pua) | optional productivity coaching skills via `npx skills`; default off |

Remote skills are installed with:

```bash
npx -y skills@latest add <repo> --global --agent codex --copy --yes --full-depth --skill <name>
```

Matt Pocock skills are the exception: both installers download the immutable v1.1.0 release commit first, then pass that local snapshot to `skills@latest`. This avoids mutable `main` content and the current CLI's unreliable handling of remote tag/commit suffixes. Installation succeeds only when every requested skill directory matches the snapshot; matching remote lock entries are retired so a later generic `skills update` cannot overwrite the pinned content. Provenance-verified retired names (`to-prd`, `to-issues`, `decision-mapping`, `review`) are removed across shared agent associations during migration.

After `mattpocock/skills` installs successfully, the installer prints a 30-second Codex quickstart. The current `skills` CLI may stage universal Codex files under the shared `~/.agents/skills` directory even when `--agent codex --copy` is set; the installer verifies and moves every requested, installer-owned skill into the Codex-owned `~/.codex/skills` directory before reporting success. Unowned/shared skills are left alone. In Codex, type `/skills` and choose **List skills**, or press `@`, then search for `setup-matt-pocock-skills`. Installed skills are not separate root slash commands such as `/setup-matt-pocock-skills`.

Every requested npx skill is accepted only after its staged `SKILL.md`, fresh shared-lock hash, and copied `~/.codex/skills/<name>/SKILL.md` are all verified for the requested upstream source; a zero exit code without that fresh provenance or Codex copy is treated as incomplete. For path-based packs, repository folder names are mapped to their declared skill names and the installer retries only entries not verified by the current npx run with the bundled `skill-installer` Python helper. The Codex installer does not show Claude-only plugin workflows that have no installable Codex target.

ResearchStudio Idea, ResearchStudio Reel, and `ppt-master` are independent default-off menu entries. Explicit selection installs only the bounded upstream skill source plus the Codex-specific instruction/path adaptation needed by Idea. The installer does not create Python or Conda environments, install Python packages, browsers, or native tools, or run runtime dependency checks. On first use, the selected skill may set up a project-local environment itself or explain the missing requirements.

Bundled local skills in this repo:
- `paper-reading` (`skills/paper-reading/SKILL.md`) — structured research paper summarization
- `adversarial-review` (`skills/adversarial-review/SKILL.md`) — cross-model adversarial code review via opposite AI CLI (from [poteto/noodle](https://github.com/poteto/noodle/tree/main/.agents/skills/adversarial-review))
- `handoff` (`skills/handoff/SKILL.md`) — compact the current conversation into a handoff document
- [`neat-freak`](https://github.com/KKKKhazix/khazix-skills/tree/2b4a645cfdc894156ae347d897723562f719ce95/neat-freak) (`skills/neat-freak/SKILL.md`) — project knowledge and governance closeout from the pinned upstream snapshot
- [`storage-analyzer`](https://github.com/KKKKhazix/khazix-skills/tree/fcba3adcf5def1ccd4bb688de93060227471b129/storage-analyzer) (`skills/storage-analyzer/SKILL.md`) — modified vendored disk-usage analysis with Linux support and guarded interactive cleanup
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

The installer pins Playwright MCP to the version it has tested and completes an MCP `initialize` handshake before registering it with Codex. With Node.js 20 or newer it uses the standard upstream `npx` commands. On older Node.js installations it prints a warning and uses an isolated Node.js 24 runtime for both Playwright MCP and `npx skills`, without replacing the system Node.js. The static `config.toml` template uses that compatible Playwright launcher too. A supported Node.js 24 LTS installation is still recommended; the compatibility runtime requires `npx` and downloads its packages on first use.

## Installation Notes

1. The Lark and GitHub MCP entries ship commented out in `config.toml`. To enable them, fill your own credentials and uncomment the blocks:
   - `YOUR_APP_ID` / `YOUR_APP_SECRET` (Lark)
   - `YOUR_GITHUB_PAT` (GitHub MCP)
2. This config uses current Codex style (for example `web_search = "live"` at top-level).
3. If `~/.codex/config.toml` already exists, installer skips overwriting it; merge manually if needed.

### Code Review

AGENTS.md uses Matt Pocock's `code-review` Standards/Spec workflow whenever review is needed. `adversarial-review` remains available as a separate opt-in skill, but it is off by default and is not the Codex review policy.

## Compatibility for users migrating from the Claude Code main branch

See [`docs/claude-main-to-codex-migration.md`](./docs/claude-main-to-codex-migration.md) for a concrete mapping of:

- `CLAUDE.md` → `AGENTS.md`
- `settings.json` → `config.toml`
- Claude-era plugins → Codex skills / MCP / built-ins
- `mcp/mcp-servers.json` → `[mcp_servers.*]` in `config.toml`

## Security Note

Template defaults for new Codex configurations are intentionally autonomous for this branch:
- `model = "gpt-5.6-sol"`
- `model_reasoning_effort = "max"`
- `approval_policy = "never"`
- `sandbox_mode = "danger-full-access"`
- `[tui].status_line = ["model", "reasoning", "project-name", "git-branch", "context-used", "five-hour-limit", "weekly-limit"]`
- `[tui].status_line_use_colors = true`

Repeat installs preserve an existing `model` and `model_reasoning_effort`; selecting StatusLine refreshes the managed footer fields above.

Use this config only in trusted repositories. If you prefer approval prompts and a workspace sandbox, switch these back to `approval_policy = "on-request"` and `sandbox_mode = "workspace-write"` in `~/.codex/config.toml`.

If `[tui].status_line` is present in `~/.codex/config.toml` but the current TUI footer has not changed, restart Codex or run `/statusline` inside the TUI to inspect and persist the active footer items.

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
