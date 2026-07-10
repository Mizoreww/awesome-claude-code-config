# Changelog

## [Unreleased] - 2026-07-10

### Features
- Migrated the latest Claude main installer categories into the Codex branch as Codex-native groups: Review, Workflow, Development Tools, Design & Content, Lifestyle, Academic Research, Slides, and MCP Servers.
- Added `npx skills@latest add ... --agent codex --copy --yes --full-depth` as the first-choice installer path for compatible upstream skill packs, with the Python `skill-installer` kept as fallback for path-based packs.
- Set the Codex template defaults to `model = "gpt-5.6-sol"`, `model_reasoning_effort = "max"`, `approval_policy = "never"`, `sandbox_mode = "danger-full-access"`, and a `[tui].status_line` footer showing model, reasoning, project, branch, context use, five-hour quota, and weekly quota.
- Made repeat interactive installs selection-authoritative for installer-owned skills in both Bash and PowerShell: unchecked owned skills are removed, while an empty skill selection requires confirmation before bulk removal.
- Added persistent managed-skill ownership state plus safe adoption of legacy lock sources only when Codex/canonical copies match, unchanged bundled copies, and the verified `obra/superpowers` fallback; retired `coding-foundations` names remain provenance-gated cleanup-only entries, and `handoff` is restored as a visible default-on Workflow choice.
- Updated both installers to ensure statusline settings inside `[tui]`, removing misplaced top-level or project-scoped `status_line` entries during the merge.
- Removed Codex installer entries that have no practical Codex install target, including Claude-only command workflow plugins, `ppt-master`, `claude-mem`, and `claude-health`.
- Enabled the GitHub MCP menu item by default; installation uses `GITHUB_PERSONAL_ACCESS_TOKEN` when present and skips GitHub MCP without writing a placeholder token when absent.
- Hardened installer edge cases found in review: removed orphaned managed skill names, restored npx-first AI/DeepXiv paths, and made statusline merging handle missing or multi-line config safely.
- Added a conditional Matt Pocock post-install quickstart to both installers: after the full pack succeeds, it points users to Codex `/skills` or `@`, names `setup-matt-pocock-skills`, and explains that installed skills are not individual root slash commands.
- Changed the installed Codex review policy to use Matt Pocock's `code-review` Standards/Spec workflow instead of invoking `adversarial-review` or spawning `claude -p` reviewers.

### Design Rationale
- Codex does not have Claude Code's plugin runtime, so the migration preserves user-facing categories while mapping installable capabilities to Codex skills, MCP servers, or explicit skipped items.
- `npx skills` is the most direct cross-agent skill installer for repositories that expose valid `SKILL.md` entries, while the existing Python installer remains useful as a fallback for nested path installs.
- Codex's `/statusline` command persists footer fields under `[tui]`; writing a top-level `status_line` can silently land inside the previous TOML table when appended to an existing config.
- The Codex installer now favors a clean selectable surface over migration parity for items that would only warn or require heavy manual setup.
- A validated ownership file bounds reconciliation so a generic catalogue name is never treated as deletion authority by itself. `npx skills remove --global --agent codex` updates Codex/global metadata before Codex-local fallback cleanup, and generic `~/.agents/skills` children are never scanned or deleted.
- Current `skills@latest` global Codex installs can use the canonical shared `~/.agents/skills` directory even with `--agent codex --copy`; Codex discovers that directory, while its root `/` menu remains a command menu and exposes installed skills through `/skills` or `@`.

### Notes & Caveats
- `github` and `lark-mcp` remain credential-gated; GitHub uses `GITHUB_PERSONAL_ACCESS_TOKEN`, while lark-mcp stays manual because it needs app credentials.
- The Slides group currently installs `frontend-slides` only; `ppt-master` is intentionally omitted because its setup path is too heavy for this installer.
- The autonomous YOLO defaults should only be used in trusted repositories.
- Existing Codex TUI sessions may need a restart or `/statusline` refresh before the new footer fields appear.
- Skill reconciliation runs only after a real interactive menu submission. Explicit non-interactive flags remain additive, and core files, MCP configuration, shared-agent skills, unowned/custom skills, and ambiguous legacy entries are not removed.
- Repeat installs preserve existing `model` and `model_reasoning_effort` values; the new defaults apply only when creating `config.toml`, while a selected StatusLine is refreshed to the managed footer layout.
- The Matt Pocock quickstart is suppressed for dry-runs and failed installs, and an already-open Codex TUI may need to be restarted before newly installed skills appear.

## [1.7.3] - 2026-04-09

### Features
- Removed DeepXiv runtime-missing warnings from both installers so Codex installs no longer tell users to install a separate local `deepxiv` CLI
- Updated English and Chinese README guidance to describe DeepXiv as skills refreshed into Codex on each install run
- Extended the active cleanup spec/plan docs with the corrected DeepXiv installation model

### Design Rationale
- In this repo's supported Codex workflow, DeepXiv is consumed as an installed skill set inside Codex rather than as a separately managed local CLI runtime
- Warning users about a missing standalone runtime created false setup friction and implied an unnecessary manual `pip install` step
- Keeping the install model aligned across scripts and docs reduces confusion and avoids reintroducing the same misconception later

### Notes & Caveats
- This change removes the standalone `deepxiv` CLI requirement only for the Codex workflow documented by this repo
- Upstream DeepXiv skills are still refreshed from `DeepXiv/deepxiv_sdk` during install
- Historical changelog/spec documents may still mention the older runtime-warning behavior as part of the project record

## [1.7.2] - 2026-04-09

### Features
- Standardized installer internals from Claude-oriented names to Codex-first names, including skill selector state variables and menu identifiers
- Updated Codex-branch README navigation labels from `Main` to `Source` to reduce branch ambiguity while keeping links unchanged
- Refreshed the active cleanup spec/plan docs so they document the deeper internal naming pass as well as the user-visible cleanup

### Design Rationale
- User-facing labels are not enough when the active implementation still encodes old naming in variables and menu IDs; consistent internals reduce future drift
- Changing active implementation names is safer now that the compatibility boundary is explicit: preserve legacy file paths, but simplify current code paths
- Historical migration docs and changelog entries remain factual records and should not be rewritten as if the old names never existed

### Notes & Caveats
- Legacy compatibility paths such as `~/.codex/.claude-code-config-version` are still preserved intentionally
- Upstream source identifiers such as `affaan-m/everything-claude-code` are still unchanged where required for installation
- Historical migration/design docs may still mention Claude-specific names when they are recording past decisions or migration mappings

## [1.7.1] - 2026-04-09

### Features
- Reframed README and README.zh-CN so Codex is the default audience, while Claude-related material is limited to migration and compatibility notes
- Renamed the user-facing recommended skill-pack label from `everything-claude-code` to `coding-foundations` in both installer UIs and docs, while keeping the upstream source path intact
- Updated bundled `update_config` and `adversarial-review` skill docs to describe Claude-era paths as compatibility details instead of the main workflow

### Design Rationale
- Codex users should not need to parse Claude-first branding or menu labels to understand what to install; neutral presentation reduces migration friction
- Preserving upstream repo names and legacy version-file fallback avoids breaking installs while still cleaning up the default user experience
- Keeping a single migration document is clearer than scattering Claude-specific explanations throughout the primary setup docs

### Notes & Caveats
- Upstream install sources still include names such as `affaan-m/everything-claude-code`; only the user-facing display labels were changed
- The legacy `~/.codex/.claude-code-config-version` path is still read for compatibility with older installs
- `docs/claude-main-to-codex-migration.md` remains in the repo as the dedicated migration reference

## [1.7.0] - 2026-04-08

### Features
- Added interactive Bash and PowerShell installer UIs for plain no-arg runs when a usable terminal/console is available; explicit dry-run preview paths remain non-interactive where implemented
- Added Codex-native selectable groups for Core, Agents, Skills — Recommended, Skills — AI Research, and MCP Servers
- Kept explicit CLI flags backward-compatible for non-interactive installs and previews (`--all` / `-All`, `--core` / `-Core`, `--mcp` / `-Mcp`, `--skills` / `-Skills`, `--dry-run` / `-DryRun`)

### Design Rationale
- The main-style menu flow gives Codex users a familiar selector while still presenting Codex-specific defaults and install targets
- Preserving explicit flags avoids breaking scripts and automation that already depend on the installer’s non-interactive paths
- Grouping the UI around core files, agents, recommended skills, AI research skills, and MCP servers matches the actual Codex distribution surface instead of a generic all-or-nothing install

### Notes & Caveats
- `~/.codex/config.toml` is still never overwritten automatically; users must merge template changes manually if they want them
- Bash plain no-arg runs fall back to a non-interactive full install with a warning when no terminal is available
- PowerShell plain no-arg runs fall back to a non-interactive full install with a warning when console I/O is unavailable
- PowerShell explicitly treats an empty interactive submission as a no-op

## [1.6.0] - 2026-04-08

### Features
- Installer now refreshes `deepxiv-cli`, `deepxiv-baseline-table`, and `deepxiv-trending-digest` directly from `DeepXiv/deepxiv_sdk` on every install run
- Bash and PowerShell installers now remove existing DeepXiv skill directories before reinstalling them from upstream
- Installers now warn when the `deepxiv` CLI runtime is missing instead of attempting to install it automatically
- Documentation now describes DeepXiv as an install-time upstream dependency instead of a bundled local skill copy

### Design Rationale
- DeepXiv changes frequently enough that mirroring superpowers-style upstream installs is a better fit than snapshotting local copies in this repo
- Reinstalling the managed DeepXiv skills ensures repeat installs actually refresh to the latest upstream version instead of silently keeping stale copies

### Notes & Caveats
- DeepXiv skill refresh still depends on the skill installer being available and GitHub being reachable during install
- The `deepxiv` CLI itself is still a separate runtime dependency and must be installed on PATH by the user

## [1.5.0] - 2026-04-08

### Features
- Added bundled DeepXiv skills: `deepxiv-cli`, `deepxiv-baseline-table`, and `deepxiv-trending-digest`
- Installer uninstall tracking now includes the three DeepXiv skills on both bash and PowerShell paths
- README, Chinese README, and migration notes now document the new DeepXiv skill set and its CLI dependency

### Design Rationale
- DeepXiv's progressive paper-reading workflows complement the existing research-oriented Codex setup without requiring a separate plugin system
- Bundling the upstream skills directly in this repo keeps local installs reproducible and ensures the installer can copy them like other repo-local skills

### Notes & Caveats
- These skills expect the `deepxiv` CLI to already be installed and available on PATH, typically via `pip install deepxiv-sdk`

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
