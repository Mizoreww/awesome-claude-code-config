# Codex Selection Reconciliation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make interactive reinstalls remove installer-managed Codex skills that are no longer selected, and change fresh-install defaults to `gpt-5.6-sol`, `max`, and the requested rate-limit footer.

**Architecture:** The interactive menu produces a desired set of concrete skill names. Before additive installation begins, each installer compares that set with the bounded `MANAGED_SKILLS` catalogue, invokes agent-scoped `npx skills remove` for stale global entries, directly clears stale legacy copies under `~/.codex/skills`, and handles the superpowers fallback link/repository separately. Explicit non-interactive flags remain additive and never trigger reconciliation.

**Tech Stack:** Bash 3.2-compatible shell, Windows PowerShell 5.1-compatible script, TOML, Python 3 standard library for structural test assertions, Markdown documentation.

## Global Constraints

- Develop and commit only on `codex-dev`; push only `codex-dev` for user testing.
- Do not advance or push `codex` until the user explicitly confirms the `codex-dev` install test passed.
- Reconciliation runs only after a real interactive menu submission.
- Delete only names in `MANAGED_SKILLS`; preserve `.system`, catalogue-external skills, Core files, and MCP entries.
- Use `npx skills remove --global --agent codex` for global/lock-aware cleanup; never recursively delete `~/.agents/skills`.
- Preserve an existing `config.toml` model and reasoning choice; new defaults apply when the template is created.
- Keep Bash and PowerShell behavior parallel.
- Update both English and Chinese documentation and changelogs.

---

### Task 1: Lock the New Model and Footer Defaults with Regression Tests

**Files:**
- Modify: `tests/check_codex_migration.sh:25-32,205-295`
- Modify: `config.toml:3-14`
- Modify: `install.sh:150`
- Modify: `install.ps1:183`

**Interfaces:**
- Consumes: existing `ensure_status_line_setting` / `Ensure-StatusLineSetting` merge behavior.
- Produces: one shared seven-field footer value and fresh-install model defaults used by later tasks.

- [ ] **Step 1: Change the migration assertions first**

Replace the old model/footer assertions with:

```bash
assert_file_contains "config.toml" 'model = "gpt-5.6-sol"'
assert_file_contains "config.toml" 'model_reasoning_effort = "max"'
assert_file_contains "config.toml" 'approval_policy = "never"'
assert_file_contains "config.toml" 'sandbox_mode = "danger-full-access"'
assert_file_contains "config.toml" "[tui]"
assert_file_contains "config.toml" 'status_line = ["model", "reasoning", "project-name", "git-branch", "context-used", "five-hour-limit", "weekly-limit"]'
assert_file_contains "config.toml" "status_line_use_colors = true"
assert_file_not_contains "config.toml" "model-with-reasoning"
```

In both Python statusline expectations, use:

```python
expected = [
    "model",
    "reasoning",
    "project-name",
    "git-branch",
    "context-used",
    "five-hour-limit",
    "weekly-limit",
]
```

For the multiline fixture assertion, compare to the same `expected` list instead of repeating the previous `context-window-size` and `used-tokens` fields.

- [ ] **Step 2: Run the test and verify RED**

Run:

```bash
bash tests/check_codex_migration.sh
```

Expected: failure stating that `config.toml` does not contain `model = "gpt-5.6-sol"`.

- [ ] **Step 3: Apply the minimal template and installer constant changes**

Set the template keys to:

```toml
model = "gpt-5.6-sol"
model_reasoning_effort = "max"
```

Set both installer constants to:

```bash
CODEX_STATUS_LINE='status_line = ["model", "reasoning", "project-name", "git-branch", "context-used", "five-hour-limit", "weekly-limit"]'
```

```powershell
$script:CODEX_STATUS_LINE = 'status_line = ["model", "reasoning", "project-name", "git-branch", "context-used", "five-hour-limit", "weekly-limit"]'
```

- [ ] **Step 4: Run the focused test and verify GREEN**

Run `bash tests/check_codex_migration.sh`.

Expected: `Codex migration checks passed`.

- [ ] **Step 5: Commit the default change**

```bash
git add config.toml install.sh install.ps1 tests/check_codex_migration.sh
git commit -m "feat(codex): update model and footer defaults"
```

---

### Task 2: Implement Bash Interactive Skill Reconciliation

**Files:**
- Create: `tests/check_codex_skill_reconciliation.sh`
- Modify: `install.sh:60-151,799-1171,1173-1611,1700-1746`
- Modify: `tests/check_codex_migration.sh:95-103,141-197`

**Interfaces:**
- Consumes: `MANAGED_SKILLS`, all `SELECT_SKILL_*` / `SELECT_AI_*` booleans, `CODEX_DIR`, `AGENTS_SKILLS_DIR`, `SUPERPOWERS_DIR`, and `SUPERPOWERS_LINK`.
- Produces: `selected_managed_skill_names`, `remove_npx_skill_names`, `remove_superpowers_fallback`, and `reconcile_interactive_skills`.

- [ ] **Step 1: Add the failing behavior test**

Create `tests/check_codex_skill_reconciliation.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

export HOME="$TMP/home"
export NPX_LOG="$TMP/npx.log"
mkdir -p "$HOME" "$TMP/bin"
sed '$d' "$ROOT/install.sh" > "$TMP/install-lib.sh"

cat > "$TMP/bin/npx" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$NPX_LOG"
SH
chmod +x "$TMP/bin/npx"
export PATH="$TMP/bin:$PATH"

# shellcheck source=/dev/null
source "$TMP/install-lib.sh"
SCRIPT_DIR="$ROOT"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
assert_exists() { [[ -e "$1" || -L "$1" ]] || fail "expected path to exist: $1"; }
assert_missing() { [[ ! -e "$1" && ! -L "$1" ]] || fail "expected path to be absent: $1"; }

clear_skill_selections() {
  SELECT_SKILL_SUPERPOWERS=false
  SELECT_SKILL_DOCUMENTS=false
  SELECT_SKILL_EXAMPLES=false
  SELECT_SKILL_FRONTEND_DESIGN=false
  SELECT_SKILL_KARPATHY=false
  SELECT_SKILL_MATTPOCOCK=false
  SELECT_SKILL_CODE_REVIEW=false
  SELECT_SKILL_PUA=false
  SELECT_SKILL_FRONTEND_SLIDES=false
  SELECT_SKILL_PAPER_READING=false
  SELECT_SKILL_HUMANIZER=false
  SELECT_SKILL_HUMANIZER_ZH=false
  SELECT_SKILL_HANDOFF=false
  SELECT_SKILL_ADVERSARIAL_REVIEW=false
  SELECT_SKILL_UPDATE=false
  SELECT_AI_TOKENIZATION=false
  SELECT_AI_FINE_TUNING=false
  SELECT_AI_POST_TRAINING=false
  SELECT_AI_DISTRIBUTED_TRAINING=false
  SELECT_AI_INFERENCE_SERVING=false
  SELECT_AI_OPTIMIZATION=false
  SELECT_AI_DEEPXIV=false
}

clear_skill_selections
SELECT_SKILL_HUMANIZER=true
mkdir -p \
  "$CODEX_DIR/skills/humanizer" \
  "$CODEX_DIR/skills/humanizer-zh" \
  "$CODEX_DIR/skills/private-skill" \
  "$AGENTS_SKILLS_DIR/frontend-slides"
reconcile_interactive_skills
assert_exists "$CODEX_DIR/skills/humanizer"
assert_missing "$CODEX_DIR/skills/humanizer-zh"
assert_exists "$CODEX_DIR/skills/private-skill"
grep -Fq -- 'skills@latest remove' "$NPX_LOG" || fail "npx removal was not invoked"
grep -Fq -- '--global --agent codex --yes' "$NPX_LOG" || fail "npx removal was not Codex-scoped"
grep -Fq -- 'frontend-slides' "$NPX_LOG" || fail "stale npx skill was not requested for removal"

clear_skill_selections
SELECT_SKILL_MATTPOCOCK=true
mkdir -p "$CODEX_DIR/skills/handoff"
reconcile_interactive_skills
assert_exists "$CODEX_DIR/skills/handoff"

clear_skill_selections
mkdir -p "$CODEX_DIR/skills/pua" "$SUPERPOWERS_DIR/skills"
mkdir -p "$(dirname "$SUPERPOWERS_LINK")"
ln -s "$SUPERPOWERS_DIR/skills" "$SUPERPOWERS_LINK"
reconcile_interactive_skills
assert_missing "$CODEX_DIR/skills/pua"
assert_missing "$SUPERPOWERS_LINK"
assert_missing "$SUPERPOWERS_DIR"

clear_skill_selections
mkdir -p "$CODEX_DIR/skills/pua"
DRY_RUN=true
dry_output="$(reconcile_interactive_skills)"
assert_exists "$CODEX_DIR/skills/pua"
[[ "$dry_output" == *"Would remove unselected managed skill"* ]] || fail "dry-run did not report removal"

printf '%s\n' "Codex skill reconciliation checks passed"
```

- [ ] **Step 2: Run the new test and verify RED**

Run `bash tests/check_codex_skill_reconciliation.sh`.

Expected: failure because `reconcile_interactive_skills` is undefined.

- [ ] **Step 3: Add the desired-set mapper**

Add one bounded superpowers list beside the existing lists and reuse it in `install_superpowers`:

```bash
SUPERPOWERS_SKILLS=(
  brainstorming dispatching-parallel-agents executing-plans finishing-a-development-branch
  receiving-code-review requesting-code-review subagent-driven-development systematic-debugging
  test-driven-development using-git-worktrees using-superpowers verification-before-completion
  writing-plans writing-skills
)
```

Add:

```bash
selected_managed_skill_names() {
  $SELECT_SKILL_CODE_REVIEW && printf '%s\n' code-review
  $SELECT_SKILL_KARPATHY && printf '%s\n' karpathy-guidelines
  $SELECT_SKILL_SUPERPOWERS && printf '%s\n' "${SUPERPOWERS_SKILLS[@]}"
  $SELECT_SKILL_MATTPOCOCK && printf '%s\n' "${MATTPOCOCK_SKILLS[@]}"
  $SELECT_SKILL_DOCUMENTS && printf '%s\n' pdf docx pptx xlsx
  $SELECT_SKILL_EXAMPLES && printf '%s\n' canvas-design algorithmic-art mcp-builder
  $SELECT_SKILL_FRONTEND_DESIGN && printf '%s\n' frontend-design
  $SELECT_SKILL_PUA && printf '%s\n' "${PUA_SKILLS[@]}"
  $SELECT_SKILL_FRONTEND_SLIDES && printf '%s\n' frontend-slides
  $SELECT_SKILL_PAPER_READING && printf '%s\n' paper-reading
  $SELECT_SKILL_HUMANIZER && printf '%s\n' humanizer
  $SELECT_SKILL_HUMANIZER_ZH && printf '%s\n' humanizer-zh
  $SELECT_SKILL_HANDOFF && printf '%s\n' handoff
  $SELECT_SKILL_ADVERSARIAL_REVIEW && printf '%s\n' adversarial-review
  $SELECT_SKILL_UPDATE && printf '%s\n' update
  $SELECT_AI_TOKENIZATION && printf '%s\n' huggingface-tokenizers sentencepiece
  $SELECT_AI_FINE_TUNING && printf '%s\n' axolotl llama-factory peft unsloth
  $SELECT_AI_POST_TRAINING && printf '%s\n' grpo-rl-training openrlhf simpo trl-fine-tuning verl
  $SELECT_AI_DISTRIBUTED_TRAINING && printf '%s\n' deepspeed pytorch-fsdp2 megatron-core ray-train
  $SELECT_AI_INFERENCE_SERVING && printf '%s\n' vllm sglang tensorrt-llm llama-cpp
  $SELECT_AI_OPTIMIZATION && printf '%s\n' awq gptq gguf flash-attention bitsandbytes
  $SELECT_AI_DEEPXIV && printf '%s\n' deepxiv-cli deepxiv-baseline-table deepxiv-trending-digest
  return 0
}
```

- [ ] **Step 4: Add removal and reconciliation helpers**

Add:

```bash
remove_npx_skill_names() {
  [[ $# -gt 0 ]] || return 0
  if $DRY_RUN; then
    info "Would remove via npx skills for Codex: $*"
    return 0
  fi
  if ! command -v npx >/dev/null 2>&1; then
    warn "npx not found; shared/global Codex skill associations could not be removed: $*"
    SKIPPED_COMPONENTS+=("unselected managed skills (npx unavailable): $*")
    return 0
  fi
  local -a args=(-y skills@latest remove "$@" --global --agent codex --yes)
  if ! DO_NOT_TRACK=1 npx "${args[@]}" </dev/null; then
    warn "npx skills could not remove these Codex skills: $*"
    SKIPPED_COMPONENTS+=("unselected managed skills (npx removal failed): $*")
  fi
}

remove_superpowers_fallback() {
  if $DRY_RUN; then
    [[ -L "$SUPERPOWERS_LINK" || -e "$SUPERPOWERS_LINK" ]] && info "Would remove superpowers link: $SUPERPOWERS_LINK"
    [[ -e "$SUPERPOWERS_DIR" ]] && info "Would remove superpowers repository: $SUPERPOWERS_DIR"
    return 0
  fi
  if [[ -L "$SUPERPOWERS_LINK" ]]; then
    rm -f "$SUPERPOWERS_LINK"
    ok "Removed superpowers link"
  elif [[ -e "$SUPERPOWERS_LINK" ]]; then
    warn "$SUPERPOWERS_LINK is not a symlink; preserving it"
    SKIPPED_COMPONENTS+=("superpowers link cleanup ($SUPERPOWERS_LINK is not a symlink)")
  fi
  if [[ -e "$SUPERPOWERS_DIR" ]]; then
    rm -rf "$SUPERPOWERS_DIR"
    ok "Removed superpowers repository"
  fi
}

reconcile_interactive_skills() {
  local -a desired=() stale=()
  local skill wanted selected
  while IFS= read -r skill; do
    [[ -n "$skill" ]] && desired+=("$skill")
  done < <(selected_managed_skill_names)

  for skill in "${MANAGED_SKILLS[@]}"; do
    wanted=false
    if [[ ${#desired[@]} -gt 0 ]]; then
      for selected in "${desired[@]}"; do
        if [[ "$selected" == "$skill" ]]; then wanted=true; break; fi
      done
    fi
    $wanted && continue
    if [[ -e "$CODEX_DIR/skills/$skill" || -L "$CODEX_DIR/skills/$skill" ||
          -e "$AGENTS_SKILLS_DIR/$skill" || -L "$AGENTS_SKILLS_DIR/$skill" ]]; then
      stale+=("$skill")
    fi
  done

  if [[ ${#stale[@]} -gt 0 ]]; then
    remove_npx_skill_names "${stale[@]}"
    for skill in "${stale[@]}"; do
      if $DRY_RUN; then
        [[ -e "$CODEX_DIR/skills/$skill" || -L "$CODEX_DIR/skills/$skill" ]] &&
          info "Would remove unselected managed skill: $CODEX_DIR/skills/$skill"
      elif [[ -e "$CODEX_DIR/skills/$skill" || -L "$CODEX_DIR/skills/$skill" ]]; then
        rm -rf "$CODEX_DIR/skills/$skill"
        ok "Removed unselected managed skill: $skill"
      fi
    done
  fi
  if ! $SELECT_SKILL_SUPERPOWERS; then remove_superpowers_fallback; fi
}
```

- [ ] **Step 5: Trigger reconciliation only for successful interactive submissions**

Remove the Bash empty-selection `cleanup_and_exit`. Assign all three install booleans and return normally. Update `main` to:

```bash
if $INTERACTIVE_MODE; then
  interactive_menu
  if $INTERACTIVE_MODE; then
    reconcile_interactive_skills
  fi
fi
```

The inner check prevents a no-TTY fallback from being treated as an explicit deselection. Keep non-interactive branches unchanged. Replace the long interactive "selected skills processed" condition with a count derived from `selected_managed_skill_names`, eliminating the stale undefined `SELECT_SKILL_CODING_FOUNDATIONS` reference.

- [ ] **Step 6: Strengthen catalogue consistency checks**

Extend the Python block in `tests/check_codex_migration.sh` to extract the names emitted by both selected-set functions and fail if either implementation can produce a name outside its own `MANAGED_SKILLS`. Also assert that Bash calls `reconcile_interactive_skills` only inside the `$INTERACTIVE_MODE` block.

- [ ] **Step 7: Run Bash tests and verify GREEN**

```bash
bash -n install.sh
bash tests/check_codex_skill_reconciliation.sh
bash tests/check_codex_migration.sh
```

Expected: both scripts print their success messages and exit 0.

- [ ] **Step 8: Commit the Bash behavior**

```bash
git add install.sh tests/check_codex_skill_reconciliation.sh tests/check_codex_migration.sh
git commit -m "feat(codex): reconcile interactive skill selections"
```

---

### Task 3: Implement PowerShell Parity

**Files:**
- Create: `tests/install_ps1_skill_reconciliation.Tests.ps1`
- Modify: `install.ps1:95-184,671-805,873-1256,1334-1641,1744-1802`
- Modify: `tests/check_codex_migration.sh:141-203`

**Interfaces:**
- Consumes: the same menu booleans and catalogue as Bash.
- Produces: `Get-SelectedManagedSkills`, `Remove-NpxSkillNames`, `Remove-SuperpowersFallback`, and `Sync-InteractiveSkills` with PowerShell 5.1-compatible syntax.

- [ ] **Step 1: Add static RED assertions for PowerShell parity**

Add:

```bash
assert_file_contains "install.ps1" "function Get-SelectedManagedSkills"
assert_file_contains "install.ps1" "function Remove-NpxSkillNames"
assert_file_contains "install.ps1" "function Sync-InteractiveSkills"
assert_file_contains "install.ps1" '"--global", "--agent", "codex", "--yes"'
```

Run `bash tests/check_codex_migration.sh`; expect failure on the first missing function.

- [ ] **Step 2: Add a Windows function-level test**

Create `tests/install_ps1_skill_reconciliation.Tests.ps1` using the AST extraction and `Assert-True` helpers from `install_ps1_python_resolution.Tests.ps1`. Extract the four new functions and define output stubs. Verify the mapper with:

```powershell
$script:SelectSkillHumanizer = $true
$selected = @(Get-SelectedManagedSkills)
Assert-True ($selected -contains "humanizer") "selected local skill should be desired"
Assert-True (-not ($selected -contains "humanizer-zh")) "unselected local skill should be stale"

$script:SelectSkillHumanizer = $false
$script:SelectSkillMattPocock = $true
$selected = @(Get-SelectedManagedSkills)
Assert-True ($selected -contains "handoff") "mattpocock pack should retain overlapping handoff"
```

For filesystem behavior, use a temporary HOME, set `$DryRun = $true`, create managed `pua` and unmanaged `private-skill`, invoke `Sync-InteractiveSkills`, and assert both remain. Then set `$DryRun = $false` with `npx` unavailable in the test PATH, invoke again, and assert `pua` is removed while `private-skill` remains. Restore HOME and PATH in `finally`.

- [ ] **Step 3: Implement the PowerShell desired-set mapper**

Add `$SUPERPOWERS_SKILLS` identical to the Bash list. Set the hidden, non-menu `$script:SelectSkillHandoff` initial/reset value to `$false`; the visible mattpocock pack still contributes `handoff`.

Implement:

```powershell
function Get-SelectedManagedSkills {
    $selected = New-Object 'System.Collections.Generic.HashSet[string]'
    function Add-Names {
        param([bool]$Enabled, [string[]]$Names)
        if ($Enabled) { foreach ($name in $Names) { [void]$selected.Add($name) } }
    }
    Add-Names $script:SelectSkillCodeReview @("code-review")
    Add-Names $script:SelectSkillKarpathy @("karpathy-guidelines")
    Add-Names $script:SelectSkillSuperpowers $SUPERPOWERS_SKILLS
    Add-Names $script:SelectSkillMattPocock $MATTPOCOCK_SKILLS
    Add-Names $script:SelectSkillDocumentSkills @("pdf", "docx", "pptx", "xlsx")
    Add-Names $script:SelectSkillExampleSkills @("canvas-design", "algorithmic-art", "mcp-builder")
    Add-Names $script:SelectSkillFrontendDesign @("frontend-design")
    Add-Names $script:SelectSkillPUA $PUA_SKILLS
    Add-Names $script:SelectSkillFrontendSlides @("frontend-slides")
    Add-Names $script:SelectSkillPaperReading @("paper-reading")
    Add-Names $script:SelectSkillHumanizer @("humanizer")
    Add-Names $script:SelectSkillHumanizerZh @("humanizer-zh")
    Add-Names $script:SelectSkillHandoff @("handoff")
    Add-Names $script:SelectSkillAdversarialReview @("adversarial-review")
    Add-Names $script:SelectSkillUpdate @("update")
    Add-Names $script:SelectAiTokenization @("huggingface-tokenizers", "sentencepiece")
    Add-Names $script:SelectAiFineTuning @("axolotl", "llama-factory", "peft", "unsloth")
    Add-Names $script:SelectAiPostTraining @("grpo-rl-training", "openrlhf", "simpo", "trl-fine-tuning", "verl")
    Add-Names $script:SelectAiDistributedTraining @("deepspeed", "pytorch-fsdp2", "megatron-core", "ray-train")
    Add-Names $script:SelectAiInferenceServing @("vllm", "sglang", "tensorrt-llm", "llama-cpp")
    Add-Names $script:SelectAiOptimization @("awq", "gptq", "gguf", "flash-attention", "bitsandbytes")
    Add-Names $script:SelectAiDeepXiv @("deepxiv-cli", "deepxiv-baseline-table", "deepxiv-trending-digest")
    return @($selected | Sort-Object)
}
```

- [ ] **Step 4: Implement PowerShell removal and reconciliation**

Add:

```powershell
function Remove-NpxSkillNames {
    param([string[]]$SkillNames)
    if ($SkillNames.Count -eq 0) { return }
    if ($DryRun) { Write-Info "Would remove via npx skills for Codex: $($SkillNames -join ', ')"; return }
    if (-not (Get-Command "npx" -ErrorAction SilentlyContinue)) {
        Write-Warn "npx not found; shared/global Codex skill associations could not be removed: $($SkillNames -join ', ')"
        $script:SKIPPED_COMPONENTS += "unselected managed skills (npx unavailable): $($SkillNames -join ', ')"
        return
    }
    $npxArgs = @("-y", "skills@latest", "remove") + $SkillNames + @("--global", "--agent", "codex", "--yes")
    $oldDoNotTrack = $env:DO_NOT_TRACK
    $env:DO_NOT_TRACK = "1"
    try {
        & npx @npxArgs 2>&1 | ForEach-Object { Write-Host $_ }
        if ($LASTEXITCODE -ne 0) {
            Write-Warn "npx skills could not remove these Codex skills: $($SkillNames -join ', ')"
            $script:SKIPPED_COMPONENTS += "unselected managed skills (npx removal failed): $($SkillNames -join ', ')"
        }
    } finally {
        if ($null -eq $oldDoNotTrack) { Remove-Item Env:DO_NOT_TRACK -ErrorAction SilentlyContinue }
        else { $env:DO_NOT_TRACK = $oldDoNotTrack }
    }
}

function Remove-SuperpowersFallback {
    $linkItem = Get-Item -LiteralPath $SUPERPOWERS_LINK -Force -ErrorAction SilentlyContinue
    if ($DryRun) {
        if ($linkItem) { Write-Info "Would remove superpowers link: $SUPERPOWERS_LINK" }
        if (Test-Path $SUPERPOWERS_DIR) { Write-Info "Would remove superpowers repository: $SUPERPOWERS_DIR" }
        return
    }
    if ($linkItem) {
        $isReparsePoint = ($linkItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0
        if ($isReparsePoint) { cmd /c rmdir "$SUPERPOWERS_LINK" | Out-Null; Write-Ok "Removed superpowers link" }
        else {
            Write-Warn "$SUPERPOWERS_LINK is not a junction/symlink; preserving it"
            $script:SKIPPED_COMPONENTS += "superpowers link cleanup ($SUPERPOWERS_LINK is not a junction/symlink)"
        }
    }
    if (Test-Path $SUPERPOWERS_DIR) { Remove-Item -Recurse -Force $SUPERPOWERS_DIR; Write-Ok "Removed superpowers repository" }
}

function Sync-InteractiveSkills {
    $desired = @(Get-SelectedManagedSkills)
    $stale = @()
    foreach ($skill in $MANAGED_SKILLS) {
        if ($desired -contains $skill) { continue }
        $codexPath = Join-Path $CODEX_DIR "skills/$skill"
        $sharedPath = Join-Path $AGENTS_SKILLS_DIR $skill
        if ((Test-Path $codexPath) -or (Test-Path $sharedPath)) { $stale += $skill }
    }
    if ($stale.Count -gt 0) {
        Remove-NpxSkillNames $stale
        foreach ($skill in $stale) {
            $codexPath = Join-Path $CODEX_DIR "skills/$skill"
            if ($DryRun) {
                if (Test-Path $codexPath) { Write-Info "Would remove unselected managed skill: $codexPath" }
            } elseif (Test-Path $codexPath) {
                Remove-Item -Recurse -Force $codexPath
                Write-Ok "Removed unselected managed skill: $skill"
            }
        }
    }
    if (-not $script:SelectSkillSuperpowers) { Remove-SuperpowersFallback }
}
```

- [ ] **Step 5: Wire PowerShell interactive submission without changing flag mode**

After the menu loop, always set `InteractiveMode = $true`, `All = $false`, and all three component booleans, even when all are false. Remove the empty-selection return. In main:

```powershell
Show-InteractiveMenu
if ($script:InteractiveMode) { Sync-InteractiveSkills }
```

The console-unavailable branch sets `InteractiveMode` false, so it remains a non-interactive full install and does not reconcile.

- [ ] **Step 6: Run available parity checks**

Run `bash tests/check_codex_migration.sh` and expect `Codex migration checks passed`.

When `pwsh` is available, also run:

```bash
pwsh -NoLogo -NoProfile -File tests/install_ps1_python_resolution.Tests.ps1
pwsh -NoLogo -NoProfile -File tests/install_ps1_skill_reconciliation.Tests.ps1
```

If `pwsh` is unavailable, record that fact; do not claim the PowerShell behavioral test ran.

- [ ] **Step 7: Commit PowerShell parity**

```bash
git add install.ps1 tests/check_codex_migration.sh tests/install_ps1_skill_reconciliation.Tests.ps1
git commit -m "feat(codex): mirror skill reconciliation on Windows"
```

---

### Task 4: Document the Subtractive Reinstall and Version-Level Change

**Files:**
- Modify: `README.md:39-93,208-220`
- Modify: `README.zh-CN.md:39-93,208-220`
- Modify: `docs/claude-main-to-codex-migration.md:20-27`
- Modify: `CHANGELOG.md:3-24`
- Modify: `CHANGELOG.zh-CN.md:3-24`

**Interfaces:**
- Consumes: verified behavior from Tasks 1-3.
- Produces: synchronized English/Chinese guidance and version history.

- [ ] **Step 1: Update English README behavior and defaults**

Replace the empty-selection note with:

```markdown
- Interactive submissions are authoritative for installer-managed Codex skills: previously installed managed skills that are now unchecked are removed. An empty submission removes all managed skills while preserving Core files, MCP entries, `.system`, and catalogue-external skills.
- Explicit non-interactive component flags remain additive and do not remove omitted skill groups.
```

Update the Security Note to:

```markdown
- `model = "gpt-5.6-sol"`
- `model_reasoning_effort = "max"`
- `[tui].status_line = ["model", "reasoning", "project-name", "git-branch", "context-used", "five-hour-limit", "weekly-limit"]`
```

- [ ] **Step 2: Apply equivalent Chinese README text**

```markdown
- 交互提交会作为安装器受管 Codex skills 的最终状态：之前已安装但本次取消勾选的受管 skill 会被删除。空提交会删除全部受管 skills，同时保留 Core、MCP、`.system` 和清单外 skills。
- 显式的非交互组件参数仍是增量安装，不会删除未包含的 skill 分组。
```

Update the same three configuration values in Chinese.

- [ ] **Step 3: Update migration documentation**

Change the footer/default bullets to the new model, reasoning, and seven fields. State that only interactive menu submissions reconcile removed skill selections; targeted flags remain non-destructive.

- [ ] **Step 4: Update both Unreleased changelog sections**

Add/update:

```markdown
### Features
- Made interactive reinstalls selection-authoritative for installer-managed Codex skills: unchecked managed skills are removed with agent-scoped `npx skills` cleanup while catalogue-external skills, Core files, and MCP entries are preserved.
- Updated fresh-install defaults to `model = "gpt-5.6-sol"`, `model_reasoning_effort = "max"`, and a footer showing model, reasoning, project, branch, context used, five-hour limit, and weekly limit.

### Design Rationale
- Selection-set reconciliation handles legacy installs without introducing a manifest, while the bounded `MANAGED_SKILLS` catalogue prevents broad deletion.
- Reconciliation is interactive-only so targeted/non-interactive repair commands remain additive.

### Notes & Caveats
- Existing `config.toml` model and reasoning values remain user-owned; only newly created templates receive the new defaults, while a selected StatusLine is still reconciled on reinstall.
```

Add equivalent statements under `新功能`, `设计理由`, and `注意事项` in `CHANGELOG.zh-CN.md`.

- [ ] **Step 5: Verify README symmetry and tests**

```bash
bash scripts/check-readme-sync.sh
bash tests/check_codex_migration.sh
bash tests/check_codex_skill_reconciliation.sh
git diff --check
```

Expected: all commands exit 0.

- [ ] **Step 6: Commit documentation**

```bash
git add README.md README.zh-CN.md docs/claude-main-to-codex-migration.md CHANGELOG.md CHANGELOG.zh-CN.md
git commit -m "docs(codex): explain selection-authoritative reinstalls"
```

---

### Task 5: Adversarial Review, Final Verification, and `codex-dev` Push

**Files:**
- Review: all changes from `origin/codex-dev..HEAD`
- Modify only if review or verification exposes a defect.

**Interfaces:**
- Consumes: Tasks 1-4 and the user-approved design.
- Produces: a reviewed, verified `codex-dev` commit range ready for user testing; no `codex` change.

- [ ] **Step 1: Run the repository-required adversarial review**

Invoke the `adversarial-review` skill against `origin/codex-dev..HEAD`, focusing on deletion boundaries, `~/.agents/skills` cross-agent safety, Bash 3.2 empty arrays, PowerShell 5.1 syntax/junction safety, no-TTY fallback, pack overlaps, and TOML preservation.

For each valid finding: add or tighten a failing regression test, verify RED, apply the smallest fix, verify GREEN, then commit:

```bash
git add install.sh install.ps1 tests/check_codex_migration.sh tests/check_codex_skill_reconciliation.sh tests/install_ps1_skill_reconciliation.Tests.ps1
git commit -m "fix(codex): address skill reconciliation review"
```

- [ ] **Step 2: Run the fresh full verification gate**

```bash
bash -n install.sh
bash tests/check_codex_migration.sh
bash tests/check_codex_skill_reconciliation.sh
bash scripts/check-readme-sync.sh
git diff --check origin/codex-dev...HEAD
```

Run both PowerShell test scripts when `pwsh` is available; otherwise report `pwsh unavailable` without claiming they passed.

- [ ] **Step 3: Exercise non-interactive dry-run isolation**

```bash
verify_home="$(mktemp -d)"
HOME="$verify_home" bash install.sh --dry-run > "$verify_home/dry-run.log"
test ! -e "$verify_home/.codex/config.toml"
test ! -e "$verify_home/.codex/skills"
rm -rf "$verify_home"
```

Expected: dry-run exits 0 and creates no Codex config or skill directory.

- [ ] **Step 4: Verify branch containment**

```bash
test "$(git branch --show-current)" = "codex-dev"
git status --short --branch
git log --oneline origin/codex-dev..HEAD
git rev-parse origin/codex
```

Expected: current branch is `codex-dev`, the worktree is clean, intended commits are ahead of `origin/codex-dev`, and no command has advanced `codex`.

- [ ] **Step 5: Push only `codex-dev`**

```bash
git push origin codex-dev
```

Expected: push succeeds and `git status --short --branch` shows no ahead/behind count.

- [ ] **Step 6: Hand off for user testing**

Report the pushed commit, exact `codex-dev` install command, expected footer fields, and a short test checklist. Stop there. Do not merge, force-update, or push `codex`; wait for the user's explicit test result.
