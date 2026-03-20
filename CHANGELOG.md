# Changelog

## [1.4.0] - 2026-03-20

### Features
- Added a bundled `update_config` skill for refreshing the installed Codex configuration from the `codex` branch
- Added a `docs/claude-main-to-codex-migration.md` reference mapping Claude Code main-branch concepts to Codex equivalents
- Normalized version-stamp handling so the PowerShell installer now writes the Codex-native stamp path while still reading the legacy fallback

### Design Rationale
- A dedicated migration document is clearer than restoring Claude-era top-level plugin/rules structures that no longer match the Codex branch architecture
- The update skill needs consistent version-stamp behavior across platforms to report installed vs remote versions correctly

### Notes & Caveats
- Existing Windows installs using the old `.claude-code-config-version` file continue to work because the installer and update skill now read both paths during transition

## [1.3.0] - 2026-03-11

### Features
- Installer now installs the full `obra/superpowers` repo via native skill discovery instead of copying only four skills
- Installer creates `~/.agents/skills/superpowers` symlink and removes the legacy partial superpowers copies from `~/.codex/skills`
- README and README.zh-CN now document the full superpowers installation model and native discovery paths

### Design Rationale
- Superpowers upstream now expects repo-level installation plus skill-directory symlinking; mirroring that upstream flow avoids partial installs such as missing `brainstorming`
- Keeping superpowers as its own cloned repo makes updates straightforward with `git pull` and preserves the full upstream skill set without curating individual directories

### Notes & Caveats
- Existing users with a non-git directory at `~/.codex/superpowers` will need to resolve that path manually before the installer can manage it
- If `~/.agents/skills/superpowers` already exists as a normal directory instead of a symlink, the installer warns and skips replacing it automatically

## [1.2.0] - 2026-03-09

### Features
- Tokenization skill added to AI Research group (huggingface-tokenizers, sentencepiece)
- Web search date instruction in AGENTS.md Workflow section
- Repo URLs updated from `claude-code-config` to `awesome-claude-code-config`

### Design Rationale
- Synced from main branch to keep shared content consistent across Claude Code and Codex configurations
- Web search date instruction uses `date '+%Y-%m-%d'` with web time API fallback (no Windows variant needed since Codex CLI is Linux/macOS only)

### Notes & Caveats
- One-line install URL also updated to canonical repo name
- Skill installer is best-effort: network failures downgrade to warnings rather than blocking install

## [1.1.0] - 2026-03-05

### Features
- Adversarial code review skill (cross-model review via opposite AI CLI)
- Version changelog policy in AGENTS.md
- Multi-agent roles (explorer, reviewer, docs_researcher)

### Design Rationale
- Adversarial review spawns reviewers on the opposite model's CLI for genuine cross-model challenge
- Changelog policy keeps design decisions traceable

### Notes & Caveats
- Adversarial review requires `claude` CLI installed for Codex users

## [1.0.0] - 2026-03-02

### Features
- Initial Codex branch with AGENTS.md, config.toml, and lessons-based self-improvement loop
- Skill-first installer with open-source ecosystem skills
- Paper-reading skill for structured research paper analysis
- MCP integration (Lark, Context7, GitHub, Playwright, OpenAI docs)

### Design Rationale
- Companion branch to Claude Code main config — shared principles, Codex-specific tooling
- `config.toml` + `model_instructions_file` for lessons injection at session start

### Notes & Caveats
- Requires Codex CLI; power-user defaults (`approval_policy = "never"`, `sandbox_mode = "danger-full-access"`)
- MCP credentials must be filled in manually
