# Codex Selection Reconciliation and Default Footer Design

Date: 2026-07-10
Branch: `codex-dev` (promote to `codex` only after user testing)
Status: Implemented with adversarial-review safety amendment

## Goal

Make an interactive reinstall converge the installer-managed Codex skills to the current menu selection. If a skill or skill pack was installed previously but is no longer selected, remove its Codex installation while preserving installer-unmanaged skills, Core files, and MCP servers.

At the same time, update fresh Codex installs to use `gpt-5.6-sol` with `max` reasoning and this footer order:

```toml
[tui]
status_line = ["model", "reasoning", "project-name", "git-branch", "context-used", "five-hour-limit", "weekly-limit"]
status_line_use_colors = true
```

The resulting display is expected to have the shape:

```text
gpt-5.6-sol · max · awesome-claude-code-config · main · Context 0% used · 5h 100% left · weekly 100% left
```

The percentages and repository state remain live session values; only the displayed fields and their order are configured.

## Non-Goals

- Do not delete Core files or MCP registrations merely because their menu items are unselected.
- Do not delete skill directories whose names are outside this installer's managed catalogue.
- Do not add management for Codex plugins that this branch does not install.
- Do not change non-interactive flag semantics. In particular, `--core`, `--mcp`, `--skills`, `--all`, and their PowerShell equivalents do not interpret omitted menu items as removal requests.
- Do not overwrite an existing user's `model` or `model_reasoning_effort` values. The new model defaults apply when the installer creates a new `config.toml`.
- Do not infer installer ownership from a directory name alone.

## Chosen Approach

Use ownership-bounded selection-set reconciliation during interactive installs.

Both installers derive the union of skill names produced by selected menu items, but removal candidates come only from the installer's persisted ownership state (`~/.codex/.awesome-claude-code-config-managed-skills`). Successful local, npx, Python-fallback, and superpowers installs record ownership. A first upgrade adopts only legacy entries whose provenance can be verified: an expected source in `~/.agents/.skill-lock.json` whose Codex copy matches the canonical copy, an unchanged bundled local directory, or an `obra/superpowers` fallback repository.

Alternatives rejected:

- Treating every `MANAGED_SKILLS` name found on disk as installer-owned can delete a user's custom skill with the same generic name.
- Per-menu-item removal branches would duplicate the installation mappings and make Bash and PowerShell drift likely.

## Reconciliation Boundary

### Runs that reconcile

Only a submitted interactive menu performs selection reconciliation. This includes a submission with no skill items selected.

An entirely empty skill selection is a request to remove all installer-owned Codex skills. If any owned skills would be removed, the installer asks for a second confirmation. Core and MCP state remain unchanged.

### Runs that do not reconcile

Explicit non-interactive component flags remain additive/refresh-oriented. For example:

- `install.sh --core` does not remove skills.
- `install.sh --skills core` installs the requested group but does not infer that AI skills should be removed.
- `install.ps1 -Mcp` does not remove skills.
- `--dry-run` / `-DryRun` without an interactive menu retains its existing full-preview behavior.

This prevents automation and targeted repair commands from becoming destructive.

### Managed names only

The removal candidate set is the intersection of persisted/verified ownership and `MANAGED_SKILLS`. A directory such as `~/.codex/skills/my-private-skill` is preserved because it is outside the catalogue; a custom directory that happens to be named `research` is also preserved unless this installer previously recorded ownership.

The current catalogue is an allowlist for state validation, not proof of ownership. Retired `coding-foundations` names live in a separate provenance-gated cleanup-only catalogue; they cannot be selected or newly installed. Tests require every current selection mapper variable to have a real menu entry.

## Selection Mapping

Each selected menu item contributes its concrete skill names to one desired set. Pack overlaps use set-union semantics: if any selected item still provides a skill, that skill remains installed.

Examples:

- `document-skills` contributes `pdf`, `docx`, `pptx`, and `xlsx`.
- `example-skills` contributes `canvas-design`, `algorithmic-art`, and `mcp-builder`.
- `mattpocock/skills` contributes the bounded `MATTPOCOCK_SKILLS` list.
- `superpowers` contributes the bounded superpowers skill list and retains its fallback repository/link.
- `fine-tuning` contributes `axolotl`, `llama-factory`, `peft`, and `unsloth`.
- Local choices such as `humanizer`, `paper-reading`, and `update-config` contribute their single destination directory names.

The install and reconcile paths must share named arrays for pack contents wherever practical. Tests will assert that every desired name is in `MANAGED_SKILLS` and that Bash and PowerShell catalogues contain no duplicates.

## Removal Mechanics

### Repository-local skills

For bundled skills copied directly into `~/.codex/skills`, remove an unselected managed destination recursively. Dry-run mode prints the exact destination without deleting it.

### Skills installed through `npx skills`

The `skills` CLI maintains global source metadata and agent installations, including `~/.agents/.skill-lock.json`. For stale owned names present in Codex's global skill directory, use an agent-scoped command equivalent to:

```bash
npx -y skills@latest remove --global --agent codex --yes <skill names...>
```

This lets the upstream CLI update its lock and remove the Codex installation while preserving other agent targets. Reconciliation never scans generic children of `~/.agents/skills` and never deletes that shared tree directly.

After the agent-aware removal attempt, directly remove stale paths under `~/.codex/skills` so legacy or fallback copies do not linger. A missing or failed `npx` command produces a visible warning and increments the install warning/skip summary rather than silently claiming convergence.

### Superpowers fallback

When `superpowers` is unselected, also remove the fallback repository and its link or junction only after the repository origin is verified as `obra/superpowers`:

- `~/.codex/superpowers`
- `~/.agents/skills/superpowers`

Only the known link/junction is removed as a link. The installer must not recursively follow it into an unrelated destination.

### Operation order

For an interactive install:

1. Read the final menu state.
2. Load persisted ownership, or safely adopt verified legacy ownership on the first run.
3. Build the desired managed-skill set and reconcile owned entries that are now stale.
4. Run the existing component installation sequence, installing or refreshing only selected items and recording successful ownership.
5. Report installation and cleanup warnings.

This ensures a selected skill shared by two packs is not removed and that old unselected copies disappear during the same run.

## Empty Selection Behavior

The menu's submit action must distinguish between "nothing selected to install" and "nothing to reconcile." If no Core, skill, or MCP items are selected:

- run the managed-skill reconciliation with an empty desired set;
- ask for confirmation, then remove all currently installer-owned names from Codex scope;
- remove the superpowers fallback assets;
- preserve Core files, MCP entries, `.system` skills, shared-agent state, and unowned/custom skills (including same-name collisions);
- exit successfully after reporting what was removed.

If no managed skill is currently installed, the same submission remains an effective no-op.

## Configuration Defaults

Update `config.toml` to:

```toml
model = "gpt-5.6-sol"
model_reasoning_effort = "max"

[tui]
status_line = ["model", "reasoning", "project-name", "git-branch", "context-used", "five-hour-limit", "weekly-limit"]
status_line_use_colors = true
```

The Bash and PowerShell statusline constants use the same field list. When StatusLine is selected on a reinstall, the existing statusline merge replaces old single-line or multi-line footer definitions with this exact list under `[tui]` and removes misplaced copies, while preserving unrelated TOML tables and values.

If `~/.codex/config.toml` already exists, its model and reasoning choices remain unchanged. This preserves the documented non-destructive configuration policy. A fresh install receives `gpt-5.6-sol` and `max` from the template.

The exact item identifiers `five-hour-limit` and `weekly-limit` are supported by the locally installed Codex CLI 0.144.1. The removed `context-window-size` and `used-tokens` items are intentionally absent from the new default footer.

## Error Handling

- A failed stale-skill removal is reported with the affected names.
- Failure to run `npx skills remove` does not authorize deleting the shared `~/.agents/skills` tree directly.
- Direct cleanup remains limited to named children of `~/.codex/skills`.
- State-file entries are validated against `MANAGED_SKILLS`; arbitrary names or paths cannot expand the deletion boundary.
- Ambiguous legacy entries are preserved rather than adopted by name.
- Missing paths are treated as already clean.
- Dry-run paths perform no deletion and make both direct and agent-aware cleanup visible.
- One failed removal does not prevent unrelated selected items from being installed, but the final summary must not describe the failed item as removed.

## Bash and PowerShell Parity

`install.sh` and `install.ps1` must implement the same semantics:

- the same managed catalogue;
- the same menu-item-to-skill mapping;
- the same ownership-state and safe legacy-adoption rules;
- the same interactive-only reconciliation trigger;
- the same empty-selection cleanup behavior;
- the same npx agent-scoped removal;
- the same superpowers special cleanup;
- the same statusline and fresh-install defaults.

Platform-specific path and symlink/junction handling may differ, but the resulting Codex-visible skill set must match.

## Testing Strategy

### Configuration regression tests

Extend `tests/check_codex_migration.sh` to verify:

- `model = "gpt-5.6-sol"`;
- `model_reasoning_effort = "max"`;
- the exact seven-item statusline list;
- `context-window-size` and `used-tokens` are absent from the active default list;
- TOML parsing still places the footer only under `[tui]`;
- single-line and multi-line existing statusline values are replaced cleanly.

### Bash reconciliation tests

Use an isolated temporary HOME and source the installer functions without invoking `main`. Cover:

- an unselected managed local skill is removed;
- a selected managed skill is retained;
- a catalogue-external skill is retained;
- a custom skill with a managed-catalogue name but no ownership record is retained;
- matching legacy lock provenance and unchanged bundled copies are safely adopted;
- shared `~/.agents/skills` entries are retained;
- an unselected npx-managed skill invokes an agent-scoped global removal;
- overlapping selected packs retain their shared skill;
- an empty desired set requires confirmation and removes all owned managed skills;
- dry-run reports removals without changing files;
- non-interactive install paths do not call reconciliation.

Mock `npx` in PATH for removal tests so they do not access the network or modify the real global lock.

### PowerShell tests

Add equivalent function-level coverage when `pwsh` is available. The portable Bash migration check also performs structural assertions over `install.ps1` so CI environments without PowerShell still catch missing constants, mappings, or removal calls.

### Full verification

Run at least:

```bash
bash -n install.sh
bash tests/check_codex_migration.sh
bash scripts/check-readme-sync.sh
git diff --check
```

Run PowerShell syntax/Pester checks when `pwsh` is available. Exercise the existing dry-run paths with a temporary HOME and confirm no real user configuration or skills are modified.

## Documentation and Changelog

Update `README.md` and `README.zh-CN.md` to document:

- interactive reinstall selections are authoritative for installer-managed Codex skills;
- unselected installer-owned managed skills are removed;
- ownership state, same-name custom skills, shared-agent skills, Core, and MCP state are preserved;
- empty skill selections require confirmation before bulk removal;
- non-interactive component flags remain non-destructive;
- the new model, reasoning, and footer defaults.

Update both changelogs' current Unreleased sections. This is a version-level installer behavior change because an interactive reinstall becomes intentionally subtractive for managed skills.

## Acceptance Criteria

1. Re-running the interactive installer and deselecting a previously installed managed skill removes it from Codex scope.
2. Submitting with all skills unselected asks for confirmation, then removes all installer-owned managed skills without deleting Core, MCP, `.system`, shared-agent, or unowned/custom skill state.
3. A skill supplied by any still-selected menu item remains installed.
4. Explicit non-interactive component flags do not remove omitted skill groups.
5. Fresh installs default to `gpt-5.6-sol` and `max`.
6. The default/ensured footer contains exactly model, reasoning, project name, git branch, context used, five-hour limit, and weekly limit in that order.
7. Bash and PowerShell implementations remain behaviorally parallel.
8. Documentation and changelogs describe the new subtractive reinstall behavior and configuration defaults.
