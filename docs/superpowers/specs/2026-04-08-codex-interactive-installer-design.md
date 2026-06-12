# Codex Interactive Installer Design

> **Historical planning snapshot.** Parts of this document describe behavior that has since been changed or removed (e.g., statusline hooks, lessons.md overwrites, `|| true` MCP setup). Do not implement from this document; treat the current installers and README as the source of truth.

Date: 2026-04-08
Branch: `codex`
Status: Proposed and user-approved for implementation planning

## Goal

Bring the Codex branch installer experience up to parity with the `main` branch's initial install UX by adding an interactive two-level selection menu to both `install.sh` and `install.ps1`, while keeping the installation model Codex-native rather than Claude-plugin-native.

The result should let Codex users choose a default or customized installation set during first-time setup, instead of only using coarse CLI flags such as `--core`, `--mcp`, or `--skills`.

## Non-Goals

- Do not recreate Claude Code's plugin registry model in the Codex branch.
- Do not restore the `rules/`, `plugins/`, or `mcp/` directory structures from `main`.
- Do not change the upstream repositories used for skills or MCP setup.
- Do not redesign Codex runtime behavior beyond installation-time selection.

## User Experience

### Entry behavior

For both Bash and PowerShell installers:

- Running with no component arguments opens an interactive two-level menu.
- Running with explicit component flags keeps the existing non-interactive behavior.
- `--all` / `-All` remains the non-interactive full install path.
- `--dry-run`, `--uninstall`, and `--version` stay non-interactive.

### Interactive menu behavior

The menu mirrors the `main` branch UX:

- main menu shows install groups and selected item counts
- Enter opens a sub-menu
- Space toggles an item
- `a` selects all items in the current scope
- `n` clears the current scope
- `d` restores defaults in the current scope
- `q` exits the installer
- `Submit` applies the chosen installation set

Bash keeps the alternate-screen terminal UI pattern already proven on `main`.
PowerShell keeps the console-key based two-level menu pattern already proven on `main`.

## Information Architecture

The Codex installer uses a `main`-style interface with Codex-native groups.

### Group 1: Core
Default: all selected

Items:
- `AGENTS.md`
- `config.toml`
- `lessons.md`

### Group 2: Agents
Default: all selected

Items:
- `explorer`
- `reviewer`
- `docs-researcher`

Rationale: these are part of the Codex operating model and should be understandable as first-class selectable capabilities rather than hidden inside a bulk `agents/*` copy.

### Group 3: Skills — Recommended
Defaults:
- selected: `superpowers`, `document-skills`, `example-skills`, `everything-claude-code`, `paper-reading`, `humanizer`, `adversarial-review`, `update`
- not selected: none in this group

Items:
- `superpowers`
- `document-skills`
- `example-skills`
- `everything-claude-code`
- `paper-reading`
- `humanizer`
- `adversarial-review`
- `update`

Interpretation:
- `document-skills` maps to the Anthropic doc-oriented pack currently installed from `anthropics/skills` (`pdf`, `docx`, `pptx`, `xlsx`)
- `example-skills` maps to the Anthropic creative/build pack currently installed from `anthropics/skills` (`frontend-design`, `canvas-design`, `algorithmic-art`, `mcp-builder`)
- `everything-claude-code` maps to the current set of coding-pattern and workflow skills already installed from that repo
- local bundled skills remain individually selectable because they are repo-owned and user-visible in the Codex branch

### Group 4: Skills — AI Research
Default: all unselected

Items:
- `tokenization`
- `fine-tuning`
- `post-training`
- `distributed-training`
- `inference-serving`
- `optimization`
- `deepxiv`

Interpretation:
- the first six items map to grouped subsets from `zechenzhangAGI/AI-research-SKILLs`
- `deepxiv` maps to the three DeepXiv skills currently installed from `DeepXiv/deepxiv_sdk`

### Group 5: MCP Servers
Defaults:
- selected: `context7`, `github`, `playwright`, `openaiDeveloperDocs`
- not selected: `lark-mcp`

Items:
- `context7`
- `github`
- `playwright`
- `openaiDeveloperDocs`
- `lark-mcp`

Rationale: developer-general MCPs should feel like the Codex equivalent of `main`'s default official tool layer, while org-specific Lark credentials remain opt-in.

### Group 6: Submit
Applies the chosen install set.

## Installer Data Model

Both installers will move from a coarse boolean model to a selected-item model.

### Selected state to track

The menu result must produce explicit booleans for:

- core files:
  - `install_agents_md`
  - `install_config_toml`
  - `install_lessons_md`
- agent role files:
  - `install_agent_explorer`
  - `install_agent_reviewer`
  - `install_agent_docs_researcher`
- recommended skill packs / local skills:
  - `install_superpowers`
  - `install_document_skills`
  - `install_example_skills`
  - `install_everything_skills`
  - `install_skill_paper_reading`
  - `install_skill_humanizer`
  - `install_skill_adversarial_review`
  - `install_skill_update`
- AI research skill groups:
  - `install_ai_tokenization`
  - `install_ai_fine_tuning`
  - `install_ai_post_training`
  - `install_ai_distributed_training`
  - `install_ai_inference_serving`
  - `install_ai_optimization`
  - `install_deepxiv`
- MCP servers:
  - `install_mcp_context7`
  - `install_mcp_github`
  - `install_mcp_playwright`
  - `install_mcp_openai_docs`
  - `install_mcp_lark`

The existing high-level CLI booleans (`INSTALL_ALL`, `INSTALL_CORE`, `INSTALL_MCP`, `INSTALL_SKILLS`) remain for backward compatibility, but interactive mode should translate menu selections directly into the detailed booleans above.

## Installation Semantics

### Core

`install_core` is split into file-aware behavior:

- copy `AGENTS.md` only when selected
- copy `lessons.md` only when selected
- copy `config.toml` only when selected and destination does not already exist
- copy only selected `agents/*.toml` files

If at least one agent file is selected, ensure `~/.codex/agents/` exists.
If no agent files are selected, do not create or overwrite that directory.

### Recommended skills

The current grouped installers are reused, but dispatched conditionally:

- `superpowers` → `install_superpowers`
- `document-skills` → install only the Anthropic paths for `pdf`, `docx`, `pptx`, `xlsx`
- `example-skills` → install only the Anthropic paths for `frontend-design`, `canvas-design`, `algorithmic-art`, `mcp-builder`
- `everything-claude-code` → install only the current everything-claude-code path list
- local bundled skills → copy only the selected local skill directories

The local copy helper must stop copying every local skill unconditionally and instead accept an explicit selected-skill list.

### AI research skills

The existing one-shot AI research installer is split into grouped path lists:

- `tokenization` → `huggingface-tokenizers`, `sentencepiece`
- `fine-tuning` → `axolotl`, `llama-factory`, `peft`, `unsloth`
- `post-training` → `grpo-rl-training`, `openrlhf`, `simpo`, `trl-fine-tuning`, `verl`
- `distributed-training` → `deepspeed`, `pytorch-fsdp2`, `megatron-core`, `ray-train`
- `inference-serving` → `vllm`, `sglang`, `tensorrt-llm`, `llama-cpp`
- `optimization` → `awq`, `gptq`, `gguf`, `flash-attention`, `bitsandbytes`
- `deepxiv` → `deepxiv-cli`, `deepxiv-baseline-table`, `deepxiv-trending-digest`

`deepxiv` remains independently selectable and continues to warn if the `deepxiv` CLI is missing.

### MCP

`install_mcp` is split into per-server registration steps, each guarded by a selection boolean.

Behavior stays tolerant:
- if `codex` CLI is unavailable, print warning and skip MCP installation
- existing MCP entries remain harmless because add commands are already idempotent/tolerant enough for this installer

## Error Handling

- Interactive mode falls back to a safe default install path if terminal capabilities are unavailable, consistent with `main`.
- Missing skill-installer continues to disable remote skill packs only; local skills and any unrelated selections still proceed.
- Missing `git` only affects `superpowers` installation.
- Missing `codex` only affects MCP installation.
- `config.toml` continues to be skipped when already present to avoid destructive overwrite.

## Documentation Changes

Update both `README.md` and `README.zh-CN.md` to reflect:

- interactive menu is the default no-arg behavior
- Windows installer also supports the same interactive setup flow
- Codex-specific groups and defaults
- `--all` / `-All` is the non-interactive full install path

The README examples must explicitly distinguish:
- interactive no-arg install
- non-interactive full install
- targeted flag-based install

## Testing Strategy

### Bash

Manual verification:
- `./install.sh --dry-run`
- `./install.sh --all --dry-run`
- interactive no-arg run with menu navigation
- remote-mode no-arg run logic remains intact
- selected subset installs only chosen files / skills / MCPs

### PowerShell

Manual verification:
- `./install.ps1 -DryRun`
- `./install.ps1 -All -DryRun`
- interactive no-arg run with menu navigation
- selected subset installs only chosen files / skills / MCPs

### Regression checks

- existing explicit flags still work
- uninstall behavior still removes managed assets correctly
- version reporting remains unchanged
- no selected local skill should be installed twice or via an unintended bulk copy path

## Implementation Notes

1. Reuse as much of the `main` branch interactive menu structure as possible, but replace group labels, item IDs, defaults, and result mapping with Codex semantics.
2. Keep Bash and PowerShell structures parallel so future maintenance stays symmetric.
3. Avoid adding new upstream dependencies.
4. Preserve current installer source URLs and remote-download behavior.

## Rollout Outcome

After implementation, the Codex branch should feel equivalent to `main` in first-run install UX while remaining honest about its actual installation model:

- Claude branch: plugin-first presentation for Claude users
- Codex branch: skill/MCP/agent-first presentation for Codex users

That difference is intentional and should remain visible in both the UI labels and the README copy.
