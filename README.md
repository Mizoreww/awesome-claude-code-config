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

- Bash plain no-arg runs are interactive when a terminal is available; if it cannot open a terminal, it warns and falls back to the standard non-interactive install. Opt-in ResearchStudio and PPT Master remain excluded.
- PowerShell plain no-arg runs are interactive when console I/O is available; if it cannot use the console, it warns and falls back to the standard non-interactive install. Opt-in ResearchStudio and PPT Master remain excluded.
- In Bash, `--dry-run` previews the standard install non-interactively without opting into ResearchStudio or PPT Master.
- In PowerShell, `-DryRun` alone previews the standard install non-interactively without opting into ResearchStudio or PPT Master.
- Interactive selections are authoritative for installer-owned skills: on a repeat install, owned skills left unchecked are removed, while unowned/custom skills are preserved even if a custom skill has the same name as a catalog entry. Ownership is recorded in `~/.codex/.awesome-claude-code-config-managed-skills`; the first upgraded run adopts only unchanged bundled copies, matching canonical copies with the expected lock source, or a verified superpowers fallback. Verified leftovers from the retired `coding-foundations` pack are cleanup-only and are removed because they no longer have a menu choice.
- If no skills are selected and owned skills would be removed, the installer asks for confirmation before clearing them. It does not delete `.system`, shared-agent or custom skills, core files, or MCP configuration.
- Explicit non-interactive component flags (`--all`, `--core`, `--mcp`, `--skills` and their PowerShell equivalents) remain additive and do not reconcile prior skill selections.

### Codex menu groups and defaults

| Group | Items | Default |
|-------|-------|---------|
| Core | `AGENTS.md`, `config.toml`, `StatusLine`, global `lessons.md`, `explorer`, `reviewer`, `docs-researcher` | On |
| Review | `code-review`, `adversarial-review` | `code-review` on; `adversarial-review` off |
| Workflow | `andrej-karpathy-skills`, `superpowers`, `mattpocock/skills`, `handoff`, `update-config` | On except `superpowers` |
| Development Tools | `context7`, `github`, `playwright`, `openaiDeveloperDocs` | On; `github` requires `GITHUB_PERSONAL_ACCESS_TOKEN` |
| Design & Content | `document-skills`, `example-skills`, `frontend-design`, `humanizer`, `humanizer-zh` | On except `humanizer-zh` |
| Lifestyle | `PUA` | Off |
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
| mattpocock/skills | [mattpocock/skills](https://github.com/mattpocock/skills) | `ask-matt`, grilling/design, research, implementation, triage, TDD, architecture and domain-modeling workflows via `npx skills` |
| superpowers | [obra/superpowers](https://github.com/obra/superpowers) | full native superpowers set, including brainstorming, plan execution, review handoff, worktrees; installed via `npx skills` with git/junction fallback |
| andrej-karpathy-skills | [forrestchang/andrej-karpathy-skills](https://github.com/forrestchang/andrej-karpathy-skills) | Karpathy-style coding guidelines via `npx skills` |
| anthropic skills packs | [anthropics/skills](https://github.com/anthropics/skills) | document tools, frontend design, canvas/art, MCP builder |
| DeepXiv skills | [DeepXiv/deepxiv_sdk](https://github.com/DeepXiv/deepxiv_sdk) | latest DeepXiv research workflows (`deepxiv-cli`, `deepxiv-baseline-table`, `deepxiv-trending-digest`) fetched fresh during install |
| ResearchStudio Idea | [microsoft/ResearchStudio](https://github.com/microsoft/ResearchStudio) | opt-in research ideation, paper search, and novelty checking copied from the official source tree |
| ResearchStudio Reel | [microsoft/ResearchStudio](https://github.com/microsoft/ResearchStudio/tree/main/ResearchStudio-Reel) | opt-in paper-to-assets, poster, video, blog, and interactive-reel workflows copied from the official source tree |
| AI research skills | [zechenzhangAGI/AI-research-SKILLs](https://github.com/zechenzhangAGI/AI-research-SKILLs) | tokenization, fine-tuning, post-training, inference, distributed training, optimization |
| frontend-slides | [zarazhangrui/frontend-slides](https://github.com/zarazhangrui/frontend-slides) | slide generation skill via `npx skills`; default off |
| ppt-master | [hugohe3/ppt-master](https://github.com/hugohe3/ppt-master) | native editable PPTX workflow with browser confirmation/live preview; full Python requirements installed on explicit selection; default off |
| PUA | [tanweai/pua](https://github.com/tanweai/pua) | optional productivity coaching skills via `npx skills`; default off |

Remote skills are installed with:

```bash
npx -y skills@latest add <repo> --global --agent codex --copy --yes --full-depth --skill <name>
```

After `mattpocock/skills` installs successfully, the installer prints a 30-second Codex quickstart. With the current `skills` CLI, global Codex installs may use the shared `~/.agents/skills` directory even when `--agent codex --copy` is set; Codex discovers those skills directly. In Codex, type `/skills` and choose **List skills**, or press `@`, then search for `setup-matt-pocock-skills`. Installed skills are not separate root slash commands such as `/setup-matt-pocock-skills`.

Every requested remote skill is accepted only after its `SKILL.md` exists in `~/.agents/skills` or `~/.codex/skills`; a zero `npx` exit code without the requested files is treated as incomplete. For path-based packs, repository folder names are mapped to their declared skill names and the installer retries only missing entries with the bundled `skill-installer` Python helper. The Codex installer does not show Claude-only plugin workflows that have no installable Codex target.

### ResearchStudio Idea and Reel (Opt-In)

Both ResearchStudio entries are **off by default** and can be selected independently in **Academic Research**. An explicit AI-research group request or full-install flag selects both. The installers shallow-clone the official source repository into a temporary directory, validate the exact skill allowlist, reject symlinks/reparse points, copy only the selected bundle, and delete the checkout. They do not execute the upstream `install.sh` and do not invoke `sudo`.

- **Idea** installs `idea-spark`, `paper-search`, and `scoop-check`, installs its six declared Python dependencies, and runs the connector self-check.
- **Reel** installs `paper2assets`, `paper2poster`, `paper2video`, `paper2blog`, and `paper2reel`, installs its Python dependencies and Playwright Chromium, then checks Poppler and the bundled/system FFmpeg path.

The copied skills include their own scripts and references. They do not require a ResearchStudio platform service or a retained source checkout. The installer creates a temporary bootstrap venv only to obtain pip, then installs into the ambient interpreter's user site so later `python3` calls can import the dependencies even on PEP 668 systems. The temporary venv is deleted before exit. Missing packages or failed probes are reported as incomplete rather than successful; optional OpenReview credentials still get a credential-file walkthrough:

```bash
python3 ~/.codex/skills/idea_spark/scripts/run.py check_connectors
```

If Python venv support, Chromium, or Poppler is unavailable, the copied skills remain in place but the selected environment is listed as incomplete with exact repair steps. Reel's core paths require Python 3.10+, Playwright Chromium, and Poppler; `imageio-ffmpeg` supplies a bundled FFmpeg when no system binary exists. LibreOffice is optional for PPTX-to-PDF conversion and DOCX/PPTX visual QA. Paper2Video's advanced deck route additionally needs `ppt-master` or an existing PPTX.

After restarting Codex, type `$` and choose the installed skill, or let Codex trigger it from a matching request. OpenReview and optional higher-rate connectors use environment variables; add only requested credentials to `~/.codex/skills/.env`. The installer preserves that file during deselection/uninstall. Keep it private and never paste credentials into chat.

### PPT Master (Opt-In, Full Environment)

`ppt-master` is a separate **Slides** item and is **off by default**. Selecting it installs the official `ppt-master` skill through the bounded Codex `npx skills` command, locates the resulting skill in either `~/.codex/skills` or the shared `~/.agents/skills` directory, and installs the complete upstream `requirements.txt` with Python 3.10+. An explicit `--all`, `--skills all`, `-All`, or `-Skills -SkillGroup all` also opts in.

The installer does not create or activate a Conda environment. It uses the same temporary-bootstrap/user-site method described above to install the complete upstream `requirements.txt` for the ambient Python. The post-install self-check verifies the Python version, every declared runtime import, and the syntax/presence of the project manager, SVG converter, confirmation UI, and live-preview server. It does not open a panel during installation.

When the skill runs a real deck workflow, its confirmation UI and live-preview/editor open automatically in the browser on a local loopback address. Basic deck creation needs no API credential; optional image providers may require their own environment variables. Never paste or commit secrets.

If venv creation or an import/script check fails, the copied skill remains available but is reported as incomplete. The installer explains how to add Python venv support and rerun the same selection. Pandoc is optional and only needed for uncommon input formats.

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
