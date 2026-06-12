# Codex-First Workspace Cleanup Design

> **Historical planning snapshot.** Parts of this document describe behavior that has since been changed or removed (e.g., statusline hooks, lessons.md overwrites, `|| true` MCP setup). Do not implement from this document; treat the current installers and README as the source of truth.

## Goal
Make the workspace Codex-first for user-visible docs, installer UI, and bundled skills while preserving only the minimal Claude-era compatibility needed for migration and legacy installs.

## Scope
- Update user-facing docs in `README.md` and `README.zh-CN.md` to present Codex as the default path.
- Update installer UI text in `install.sh` and `install.ps1` so bundled/recommended skills use Codex-friendly labels instead of Claude-oriented naming.
- Update bundled skill docs in `skills/update/SKILL.md` and `skills/adversarial-review/SKILL.md` to frame legacy support as compatibility rather than the main story.
- Preserve migration docs and legacy version-file fallback support, but standardize active installer variable names and menu identifiers to Codex-first terms.

## Decisions
1. Keep the repository name and upstream source identifiers unchanged when they are required for install URLs or upstream skill packs.
2. Replace user-visible references to `everything-claude-code` with a neutral display label: `coding-foundations`.
3. Keep `docs/claude-main-to-codex-migration.md` as the single explicit migration reference.
4. Keep `.claude-code-config-version` fallback logic, but describe it as legacy compatibility only.

## File Plan
- Modify: `README.md`
- Modify: `README.zh-CN.md`
- Modify: `install.sh`
- Modify: `install.ps1`
- Modify: `skills/update/SKILL.md`
- Modify: `skills/adversarial-review/SKILL.md`
- Modify: `CHANGELOG.md`
- Modify: `VERSION`

## Validation
- Grep for high-visibility `Claude Code` / `everything-claude-code` references in edited files.
- Review installer labels to ensure Codex-first naming is consistent across Bash and PowerShell.
- Keep migration and legacy compatibility references only where intentionally retained.

## DeepXiv Correction
- Treat DeepXiv as a Codex-installed skill set, not as a separately required local CLI runtime for this repo's supported workflow.
