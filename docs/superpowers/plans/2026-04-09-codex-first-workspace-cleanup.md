# Codex-First Workspace Cleanup Implementation Plan

> **Historical planning snapshot.** Parts of this document describe behavior that has since been changed or removed (e.g., statusline hooks, lessons.md overwrites, `|| true` MCP setup). Do not implement from this document; treat the current installers and README as the source of truth.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the workspace Codex-first in user-visible docs, installer UI, and bundled skill docs while preserving only minimal legacy compatibility.

**Architecture:** Update the repository's high-visibility surfaces first (README files and installer menu labels), then align bundled skill documentation with the same Codex-first language. Preserve legacy version-file fallback and the dedicated Claude-to-Codex migration doc, but demote them to compatibility-only references.

**Tech Stack:** Markdown, Bash, PowerShell

---

### Task 1: Record the approved design in repo docs

**Files:**
- Create: `docs/superpowers/specs/2026-04-09-codex-first-workspace-cleanup-design.md`
- Create: `docs/superpowers/plans/2026-04-09-codex-first-workspace-cleanup.md`

- [ ] **Step 1: Write the design doc**

Add the approved scope, compatibility rules, file list, and validation checklist to `docs/superpowers/specs/2026-04-09-codex-first-workspace-cleanup-design.md`.

- [ ] **Step 2: Write the implementation plan**

Add this implementation plan to `docs/superpowers/plans/2026-04-09-codex-first-workspace-cleanup.md`.

### Task 2: Update English and Chinese README files

**Files:**
- Modify: `README.md`
- Modify: `README.zh-CN.md`

- [ ] **Step 1: Rewrite top-level positioning**

Change the intro paragraphs so the repo is described as a Codex configuration first, with Claude-related content demoted to migration/compatibility context.

- [ ] **Step 2: Rename the displayed remote skill pack**

Replace user-facing `everything-claude-code` labels in tables and prose with `coding-foundations`, while keeping the upstream source link explicit.

- [ ] **Step 3: Reframe review and migration sections**

Describe adversarial review from the Codex user's perspective and keep the Claude migration doc as a compatibility reference rather than the main workflow.

### Task 3: Update installer labels without breaking install sources

**Files:**
- Modify: `install.sh`
- Modify: `install.ps1`

- [ ] **Step 1: Keep upstream install paths intact**

Leave calls to `affaan-m/everything-claude-code` unchanged so installs still work.

- [ ] **Step 2: Change user-visible labels**

Update interactive menu labels and descriptions from `everything-claude-code` to `coding-foundations` (with a brief source hint where useful).

- [ ] **Step 3: Keep legacy compatibility explicit**

Retain `.claude-code-config-version` support, but rename active installer state variables and menu identifiers to Codex-first terms where that does not risk breaking behavior.

### Task 4: Update bundled skill docs

**Files:**
- Modify: `skills/update/SKILL.md`
- Modify: `skills/adversarial-review/SKILL.md`

- [ ] **Step 1: Reword update skill compatibility note**

Describe the legacy version file as a compatibility fallback rather than a Claude-first path.

- [ ] **Step 2: Reword adversarial review intro**

Keep cross-model review behavior intact but frame the workflow in neutral or Codex-first language where possible.

### Task 5: Validate and document the change

**Files:**
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Run focused grep checks**

Verify that high-visibility edited files no longer present Claude-first naming except where intentionally preserved for migration or legacy support.

- [ ] **Step 2: Add changelog entry**

Document the Codex-first cleanup, rationale, and preserved compatibility caveats in `CHANGELOG.md`.


### Task 6: Remove incorrect DeepXiv runtime guidance

**Files:**
- Modify: `install.sh`
- Modify: `install.ps1`
- Modify: `README.md`
- Modify: `README.zh-CN.md`

- [ ] **Step 1: Remove runtime-missing warnings**

Delete the installer logic that warns about a missing local `deepxiv` CLI or recommends manual `pip install` commands.

- [ ] **Step 2: Reword documentation**

Describe DeepXiv as a skill set refreshed into Codex on each install run, without requiring a separate standalone CLI for this repo's supported workflow.
