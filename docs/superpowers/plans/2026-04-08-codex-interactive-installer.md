# Codex Interactive Installer Implementation Plan

> **Historical planning snapshot.** Parts of this document describe behavior that has since been changed or removed (e.g., statusline hooks, lessons.md overwrites, `|| true` MCP setup). Do not implement from this document; treat the current installers and README as the source of truth.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a main-style interactive installer UI to the Codex branch for both Bash and PowerShell, with Codex-native selectable groups for core files, agents, skill packs, AI research skills, and MCP servers.

**Architecture:** Reuse the proven two-level menu structure from the `main` branch, but remap menu groups, item IDs, defaults, and installation dispatch to Codex semantics. Keep backward-compatible CLI flags, and make no-arg runs interactive while explicit flags continue to drive the existing non-interactive flows.

**Tech Stack:** Bash, PowerShell, git, existing installer shell/PowerShell logic, existing remote skill-installer flow, Codex CLI MCP commands.

---

## File Structure Map

- Modify: `install.sh`
  - Add interactive no-arg entry behavior
  - Add Codex-specific two-level Bash menu
  - Add fine-grained selected-item state
  - Split core/agent/skill/MCP installation into item-aware helpers
- Modify: `install.ps1`
  - Add interactive no-arg entry behavior
  - Add Codex-specific two-level PowerShell menu
  - Add fine-grained selected-item state
  - Split core/agent/skill/MCP installation into item-aware helpers
- Modify: `README.md`
  - Document interactive installer behavior, groups, defaults, and CLI examples
- Modify: `README.zh-CN.md`
  - Chinese mirror of README installer updates
- Modify: `CHANGELOG.md`
  - Record version-level change for Codex installer UX
- Reference only: `docs/superpowers/specs/2026-04-08-codex-interactive-installer-design.md`

---

### Task 1: Add Bash interactive menu entry and selection model

**Files:**
- Modify: `install.sh`
- Test: manual Bash dry-run and interactive checks

- [ ] **Step 1: Write the failing behavior checklist into the script comments and usage text**

Update `usage()` and nearby argument-entry comments so the target behavior is explicit:

```bash
Usage: $(basename "$0") [OPTIONS]

Running without component flags launches an interactive selector.
Use --all for non-interactive full install.
```

Also adjust parse flow comments near `parse_args()` / `main()` to reflect:

```bash
# No args -> interactive mode (when terminal is available)
# Explicit component flags -> non-interactive targeted install
# --all -> non-interactive full install
```

- [ ] **Step 2: Run a text-only verification to confirm current usage text does not yet describe interactive no-arg behavior**

Run:
```bash
grep -n "interactive selector" install.sh
```
Expected: either no match or Claude/main-oriented wording not suitable for Codex.

- [ ] **Step 3: Add fine-grained Bash selection state variables**

Add booleans near the current installer state section for all menu-driven selections:

```bash
SELECT_CORE_AGENTS_MD=false
SELECT_CORE_CONFIG=false
SELECT_CORE_LESSONS=false
SELECT_AGENT_EXPLORER=false
SELECT_AGENT_REVIEWER=false
SELECT_AGENT_DOCS_RESEARCHER=false
SELECT_SKILL_SUPERPOWERS=false
SELECT_SKILL_DOCUMENTS=false
SELECT_SKILL_EXAMPLES=false
SELECT_SKILL_EVERYTHING=false
SELECT_SKILL_PAPER_READING=false
SELECT_SKILL_HUMANIZER=false
SELECT_SKILL_ADVERSARIAL_REVIEW=false
SELECT_SKILL_UPDATE=false
SELECT_AI_TOKENIZATION=false
SELECT_AI_FINE_TUNING=false
SELECT_AI_POST_TRAINING=false
SELECT_AI_DISTRIBUTED_TRAINING=false
SELECT_AI_INFERENCE_SERVING=false
SELECT_AI_OPTIMIZATION=false
SELECT_AI_DEEPXIV=false
SELECT_MCP_CONTEXT7=false
SELECT_MCP_GITHUB=false
SELECT_MCP_PLAYWRIGHT=false
SELECT_MCP_OPENAI_DOCS=false
SELECT_MCP_LARK=false
INTERACTIVE_MODE=false
```

- [ ] **Step 4: Add the Bash interactive menu function by adapting the `main` branch structure to Codex groups**

Implement a new `interactive_menu()` in `install.sh` using the same alternate-screen and key-reading patterns from `main`, but with Codex groups and item IDs:

```bash
GROUP_LABELS+=("Core")
GROUP_ITEMS+=("AGENTS.md|Global Codex instructions|1|core-agents-md
config.toml|Codex runtime config template|1|core-config
lessons.md|Lessons source-of-truth|1|core-lessons")

GROUP_LABELS+=("Agents")
GROUP_ITEMS+=("explorer|Code-path exploration agent|1|agent-explorer
reviewer|Review/regression agent|1|agent-reviewer
docs-researcher|Docs/API verification agent|1|agent-docs-researcher")

GROUP_LABELS+=("Skills — Recommended")
GROUP_ITEMS+=("superpowers|Planning and execution workflows|1|skill-superpowers
document-skills|PDF/DOCX/PPTX/XLSX skills pack|1|skill-documents
example-skills|Frontend/art/MCP builder pack|1|skill-examples
everything-claude-code|Patterns, testing, security|1|skill-everything
paper-reading|Research paper summarization|1|skill-paper-reading
humanizer|Remove AI writing patterns|1|skill-humanizer
adversarial-review|Cross-model adversarial review|1|skill-adversarial-review
update|Update Codex config branch install|1|skill-update")

GROUP_LABELS+=("Skills — AI Research")
GROUP_ITEMS+=("tokenization|Tokenizer training and usage|0|ai-tokenization
fine-tuning|Fine-tuning workflows|0|ai-fine-tuning
post-training|RLHF / DPO / GRPO workflows|0|ai-post-training
distributed-training|DeepSpeed / FSDP / Megatron / Ray|0|ai-distributed-training
inference-serving|vLLM / SGLang / TensorRT / llama.cpp|0|ai-inference-serving
optimization|Quantization and optimization|0|ai-optimization
deepxiv|DeepXiv research workflow skills|0|ai-deepxiv")

GROUP_LABELS+=("MCP Servers")
GROUP_ITEMS+=("context7|Up-to-date library docs|1|mcp-context7
github|GitHub workflows|1|mcp-github
playwright|Browser automation|1|mcp-playwright
openaiDeveloperDocs|Official OpenAI docs MCP|1|mcp-openai-docs
lark-mcp|Feishu/Lark integration|0|mcp-lark")
```

Keep the shared hotkeys exactly aligned with the `main` menu behavior.

- [ ] **Step 5: Map Bash menu results into installer booleans**

At the end of `interactive_menu()`, convert selected IDs into the booleans introduced above:

```bash
SELECT_CORE_AGENTS_MD=$(_is_selected core-agents-md && echo true || echo false)
SELECT_CORE_CONFIG=$(_is_selected core-config && echo true || echo false)
SELECT_CORE_LESSONS=$(_is_selected core-lessons && echo true || echo false)
SELECT_AGENT_EXPLORER=$(_is_selected agent-explorer && echo true || echo false)
...
SELECT_MCP_LARK=$(_is_selected mcp-lark && echo true || echo false)
INTERACTIVE_MODE=true
INSTALL_ALL=false
```

Where `_is_selected` is a tiny helper that checks a chosen ID in the flattened arrays.

- [ ] **Step 6: Run a syntax check on the Bash installer after the menu addition**

Run:
```bash
bash -n install.sh
```
Expected: no output and exit code 0.

- [ ] **Step 7: Commit the Bash entry/menu scaffolding**

Run:
```bash
git add install.sh
git commit -m "feat: add codex bash interactive installer menu"
```
Expected: one commit containing only the Bash installer menu/state scaffolding.

---

### Task 2: Make Bash core, agents, skills, and MCP installation item-aware

**Files:**
- Modify: `install.sh`
- Test: Bash dry-run output checks

- [ ] **Step 1: Write the failing dry-run expectation list**

Document in comments near the install helpers that interactive mode must no longer behave like coarse bulk install:

```bash
# Interactive selections must install only selected files, agents, skills, and MCP servers.
# No helper may blindly install an entire category when INTERACTIVE_MODE=true.
```

- [ ] **Step 2: Run a targeted grep to confirm current helpers are still coarse-grained**

Run:
```bash
grep -nE '^install_core\(|^install_mcp\(|^install_local_skills\(|^install_skills\(' install.sh
```
Expected: current functions exist and still install full categories rather than selected sub-items.

- [ ] **Step 3: Refactor `install_core()` to copy only selected core files and selected agent configs**

Reshape `install_core()` roughly as:

```bash
install_core() {
  info "Installing selected core files..."
  mkdir -p "$CODEX_DIR"

  if $SELECT_CORE_AGENTS_MD; then
    backup_if_exists "$CODEX_DIR/AGENTS.md"
    cp "$SCRIPT_DIR/AGENTS.md" "$CODEX_DIR/AGENTS.md"
  fi

  if $SELECT_CORE_LESSONS; then
    backup_if_exists "$CODEX_DIR/lessons.md"
    cp "$SCRIPT_DIR/lessons.md" "$CODEX_DIR/lessons.md"
  fi

  if $SELECT_CORE_CONFIG; then
    if [[ -f "$CODEX_DIR/config.toml" ]]; then
      warn "$CODEX_DIR/config.toml exists -- skipping (merge manually if needed)"
    else
      cp "$SCRIPT_DIR/config.toml" "$CODEX_DIR/config.toml"
    fi
  fi

  if $SELECT_AGENT_EXPLORER || $SELECT_AGENT_REVIEWER || $SELECT_AGENT_DOCS_RESEARCHER; then
    mkdir -p "$CODEX_DIR/agents"
    $SELECT_AGENT_EXPLORER && cp "$SCRIPT_DIR/agents/explorer.toml" "$CODEX_DIR/agents/"
    $SELECT_AGENT_REVIEWER && cp "$SCRIPT_DIR/agents/reviewer.toml" "$CODEX_DIR/agents/"
    $SELECT_AGENT_DOCS_RESEARCHER && cp "$SCRIPT_DIR/agents/docs-researcher.toml" "$CODEX_DIR/agents/"
  fi
}
```

Preserve dry-run messages for each selected file.

- [ ] **Step 4: Split `install_mcp()` into per-server conditional registration**

Refactor the helper to guard each command independently:

```bash
$SELECT_MCP_LARK && codex mcp add lark-mcp -- npx -y @larksuiteoapi/lark-mcp mcp -a YOUR_APP_ID -s YOUR_APP_SECRET || true
$SELECT_MCP_CONTEXT7 && codex mcp add context7 -- npx -y @upstash/context7-mcp || true
$SELECT_MCP_GITHUB && codex mcp add github --env GITHUB_PERSONAL_ACCESS_TOKEN=YOUR_GITHUB_PAT -- npx -y @modelcontextprotocol/server-github || true
$SELECT_MCP_PLAYWRIGHT && codex mcp add playwright -- npx -y @playwright/mcp@latest || true
$SELECT_MCP_OPENAI_DOCS && codex mcp add openaiDeveloperDocs --url https://developers.openai.com/mcp || true
```

And mirror the same split in dry-run messaging.

- [ ] **Step 5: Split recommended and AI-research skill installers into item-aware helpers**

Replace the current all-or-nothing `install_skills()` flow with explicit dispatch helpers like:

```bash
install_recommended_skills() {
  $SELECT_SKILL_SUPERPOWERS && install_superpowers
  $SELECT_SKILL_DOCUMENTS && install_skill_paths anthropics/skills \
    skills/pdf skills/docx skills/pptx skills/xlsx
  $SELECT_SKILL_EXAMPLES && install_skill_paths anthropics/skills \
    skills/frontend-design skills/canvas-design skills/algorithmic-art skills/mcp-builder
  $SELECT_SKILL_EVERYTHING && install_skill_paths affaan-m/everything-claude-code \
    skills/python-patterns skills/python-testing skills/golang-patterns skills/golang-testing \
    skills/frontend-patterns skills/security-review skills/tdd-workflow skills/verification-loop \
    skills/api-design skills/database-migrations
}

install_ai_research_skills() {
  $SELECT_AI_TOKENIZATION && install_skill_paths zechenzhangAGI/AI-research-SKILLs \
    02-tokenization/huggingface-tokenizers 02-tokenization/sentencepiece
  ...
  $SELECT_AI_DEEPXIV && reinstall_skill_paths DeepXiv/deepxiv_sdk \
    skills/deepxiv-cli skills/deepxiv-baseline-table skills/deepxiv-trending-digest
}
```

- [ ] **Step 6: Make local skill copying selection-based**

Replace the unconditional loop in `install_local_skills()` with a helper that receives exact local skill names:

```bash
install_local_skill() {
  local skill="$1"
  local src="$SCRIPT_DIR/skills/$skill"
  local dest="$CODEX_DIR/skills/$skill"
  [[ -d "$src" ]] || return 0
  mkdir -p "$CODEX_DIR/skills"
  rm -rf "$dest"
  cp -r "$src" "$dest"
}

$SELECT_SKILL_PAPER_READING && install_local_skill paper-reading
$SELECT_SKILL_HUMANIZER && install_local_skill humanizer
$SELECT_SKILL_ADVERSARIAL_REVIEW && install_local_skill adversarial-review
$SELECT_SKILL_UPDATE && install_local_skill update
```

- [ ] **Step 7: Make `main()` choose interactive mode only for no-arg runs and preserve explicit CLI behavior**

Update the top of `main()` / argument handling so the flow is:

```bash
parse_args "$@"
if [[ $# -eq 0 && -t 0 ]]; then
  interactive_menu
fi
```

Then:
- `INSTALL_ALL=true` remains for `--all`
- explicit `--core`, `--mcp`, `--skills` stay non-interactive
- interactive mode applies only the selected booleans and does not call unrelated categories

- [ ] **Step 8: Run Bash dry-run checks for both full and selected flows**

Run:
```bash
bash -n install.sh
./install.sh --dry-run
./install.sh --all --dry-run
```
Expected:
- syntax check passes
- no-arg dry-run path shows interactive-intent code path or safe fallback messaging
- `--all --dry-run` still shows full non-interactive install coverage

- [ ] **Step 9: Commit the Bash item-aware installation refactor**

Run:
```bash
git add install.sh
git commit -m "feat: support item-aware codex bash installs"
```
Expected: one commit containing the Bash installation dispatch refactor.

---

### Task 3: Add PowerShell interactive menu entry and selection model

**Files:**
- Modify: `install.ps1`
- Test: PowerShell syntax and dry-run checks

- [ ] **Step 1: Update PowerShell help text for interactive no-arg behavior**

Adjust the parameter help and usage text so it clearly says:

```powershell
# No component switches -> interactive selector
# -All -> non-interactive full install
# Explicit -Core / -Mcp / -Skills -> targeted non-interactive install
```

And make examples include:

```powershell
.\install.ps1
.\install.ps1 -All
```

- [ ] **Step 2: Run a grep check to confirm the current help text is still all-install-oriented**

Run:
```bash
grep -n "Install everything (default)" install.ps1
```
Expected: current wording still frames no-arg as a full install rather than an interactive flow.

- [ ] **Step 3: Add PowerShell selection state variables**

Introduce a hashtable or explicit booleans near the top-level state, for example:

```powershell
$Selection = @{
  CoreAgentsMd = $false
  CoreConfig = $false
  CoreLessons = $false
  AgentExplorer = $false
  AgentReviewer = $false
  AgentDocsResearcher = $false
  SkillSuperpowers = $false
  SkillDocuments = $false
  SkillExamples = $false
  SkillEverything = $false
  SkillPaperReading = $false
  SkillHumanizer = $false
  SkillAdversarialReview = $false
  SkillUpdate = $false
  AiTokenization = $false
  AiFineTuning = $false
  AiPostTraining = $false
  AiDistributedTraining = $false
  AiInferenceServing = $false
  AiOptimization = $false
  AiDeepXiv = $false
  McpContext7 = $false
  McpGitHub = $false
  McpPlaywright = $false
  McpOpenAIDocs = $false
  McpLark = $false
}
$InteractiveMode = $false
```

- [ ] **Step 4: Add `Show-InteractiveMenu` for Codex groups by adapting the `main` branch structure**

Implement or replace the current menu function with groups like:

```powershell
@{ Label = "Core"; Items = @(
  @{ Label = "AGENTS.md"; Default = $true; Id = "core-agents-md" }
  @{ Label = "config.toml"; Default = $true; Id = "core-config" }
  @{ Label = "lessons.md"; Default = $true; Id = "core-lessons" }
)}
@{ Label = "Agents"; Items = @(
  @{ Label = "explorer"; Default = $true; Id = "agent-explorer" }
  @{ Label = "reviewer"; Default = $true; Id = "agent-reviewer" }
  @{ Label = "docs-researcher"; Default = $true; Id = "agent-docs-researcher" }
)}
@{ Label = "Skills - Recommended"; Items = @( ... ) }
@{ Label = "Skills - AI Research"; Items = @( ... ) }
@{ Label = "MCP Servers"; Items = @( ... ) }
```

Return a result object containing explicit booleans or IDs rather than Claude-specific plugin groups.

- [ ] **Step 5: Map PowerShell menu results into the shared selection state**

After `Show-InteractiveMenu`, assign the returned values into `$Selection` and set:

```powershell
$InteractiveMode = $true
$installAll = $false
```

The mapping should include every group item from core through MCP.

- [ ] **Step 6: Run a PowerShell parse check**

Run:
```bash
pwsh -NoProfile -Command "[void][scriptblock]::Create((Get-Content install.ps1 -Raw)); 'parse-ok'"
```
Expected:
```text
parse-ok
```

- [ ] **Step 7: Commit the PowerShell menu/state scaffolding**

Run:
```bash
git add install.ps1
git commit -m "feat: add codex powershell interactive installer menu"
```
Expected: one commit containing only the PowerShell menu/state changes.

---

### Task 4: Make PowerShell core, agents, skills, and MCP installation item-aware

**Files:**
- Modify: `install.ps1`
- Test: PowerShell dry-run output checks

- [ ] **Step 1: Mark the expected item-aware behavior in helper comments**

Add comments before the install helpers such as:

```powershell
# Interactive selections must install only selected files, agents, skills, and MCP servers.
# Helpers must not bulk-install a category when running from menu selections.
```

- [ ] **Step 2: Run a targeted grep to confirm current helpers are still coarse-grained**

Run:
```bash
grep -nE '^function Install-Core|^function Install-Mcp|^function Install-LocalSkills|^function Install-Skills' install.ps1
```
Expected: current functions still operate at category granularity.

- [ ] **Step 3: Refactor `Install-Core` to honor selected files and selected agent roles**

Shape the function like:

```powershell
if ($Selection.CoreAgentsMd) { Copy-Item ...AGENTS.md... }
if ($Selection.CoreLessons) { Copy-Item ...lessons.md... }
if ($Selection.CoreConfig) {
  if (Test-Path $configDest) { Write-Warn "$configDest exists -- skipping (merge manually if needed)" }
  else { Copy-Item ...config.toml... }
}
if ($Selection.AgentExplorer -or $Selection.AgentReviewer -or $Selection.AgentDocsResearcher) {
  New-Item -ItemType Directory -Path $agentsDst -Force | Out-Null
  if ($Selection.AgentExplorer) { Copy-Item ...explorer.toml... }
  if ($Selection.AgentReviewer) { Copy-Item ...reviewer.toml... }
  if ($Selection.AgentDocsResearcher) { Copy-Item ...docs-researcher.toml... }
}
```

Mirror the same branches in dry-run mode.

- [ ] **Step 4: Split `Install-Mcp` into per-server conditional registration**

Implement item-based registration:

```powershell
if ($Selection.McpContext7) { codex mcp add context7 -- npx -y @upstash/context7-mcp 2>$null }
if ($Selection.McpGitHub) { codex mcp add github --env GITHUB_PERSONAL_ACCESS_TOKEN=YOUR_GITHUB_PAT -- npx -y @modelcontextprotocol/server-github 2>$null }
if ($Selection.McpPlaywright) { codex mcp add playwright -- npx -y "@playwright/mcp@latest" 2>$null }
if ($Selection.McpOpenAIDocs) { codex mcp add openaiDeveloperDocs --url https://developers.openai.com/mcp 2>$null }
if ($Selection.McpLark) { codex mcp add lark-mcp -- npx -y @larksuiteoapi/lark-mcp mcp -a YOUR_APP_ID -s YOUR_APP_SECRET 2>$null }
```

- [ ] **Step 5: Split `Install-Skills` into recommended, AI-research, and local selection-based dispatch**

Refactor toward helper blocks like:

```powershell
if ($Selection.SkillSuperpowers) { Install-Superpowers }
if ($Selection.SkillDocuments) {
  Install-SkillPaths "anthropics/skills" @(
    "skills/pdf", "skills/docx", "skills/pptx", "skills/xlsx"
  )
}
if ($Selection.SkillExamples) {
  Install-SkillPaths "anthropics/skills" @(
    "skills/frontend-design", "skills/canvas-design", "skills/algorithmic-art", "skills/mcp-builder"
  )
}
if ($Selection.SkillEverything) {
  Install-SkillPaths "affaan-m/everything-claude-code" @( ... )
}
if ($Selection.AiDeepXiv) {
  Reinstall-SkillPaths "DeepXiv/deepxiv_sdk" @(
    "skills/deepxiv-cli", "skills/deepxiv-baseline-table", "skills/deepxiv-trending-digest"
  )
  Warn-MissingDeepXivCli
}
```

- [ ] **Step 6: Make local skill installation explicit rather than bulk-copying every repo-local skill**

Replace `Install-LocalSkills` with a helper like:

```powershell
function Install-LocalSkill {
  param([string]$SkillName)
  $src = Join-Path $script:SCRIPT_DIR "skills/$SkillName"
  $dest = Join-Path $CODEX_DIR "skills/$SkillName"
  if (-not (Test-Path $src)) { return }
  New-Item -ItemType Directory -Path (Join-Path $CODEX_DIR "skills") -Force | Out-Null
  if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
  Copy-Item -Recurse $src $dest
}
```

Then call it only for the selected local skills.

- [ ] **Step 7: Update the main PowerShell flow so no-arg runs are interactive and explicit flags stay non-interactive**

Restructure the main section to:

```powershell
$explicitComponentRequest = $Core -or $Mcp -or $Skills -or $All
if (-not $explicitComponentRequest) {
  $menuResult = Show-InteractiveMenu
  if ($null -ne $menuResult) {
    $InteractiveMode = $true
    # assign $Selection entries here
    $installAll = $false
  }
}
```

And keep `-All` / `-Core` / `-Mcp` / `-Skills` behavior intact.

- [ ] **Step 8: Run PowerShell dry-run and parse checks**

Run:
```bash
pwsh -NoProfile -Command "[void][scriptblock]::Create((Get-Content install.ps1 -Raw)); 'parse-ok'"
pwsh -NoProfile -File ./install.ps1 -DryRun
pwsh -NoProfile -File ./install.ps1 -All -DryRun
```
Expected:
- parser check prints `parse-ok`
- `-DryRun` does not crash
- `-All -DryRun` still describes the full install path

- [ ] **Step 9: Commit the PowerShell item-aware installation refactor**

Run:
```bash
git add install.ps1
git commit -m "feat: support item-aware codex powershell installs"
```
Expected: one commit containing the PowerShell dispatch refactor.

---

### Task 5: Update documentation and changelog

**Files:**
- Modify: `README.md`
- Modify: `README.zh-CN.md`
- Modify: `CHANGELOG.md`
- Test: README text grep checks

- [ ] **Step 1: Update `README.md` quick-start and installer sections**

Add/replace content so the English README explicitly says:

```md
./install.sh              # Interactive selector
./install.sh --all        # Install everything (non-interactive)
```

And document the Codex menu groups with defaults:

```md
| Group | Items | Default |
|-------|-------|---------|
| Core (3) | AGENTS.md, config.toml, lessons.md | All On |
| Agents (3) | explorer, reviewer, docs-researcher | All On |
| Skills — Recommended (8) | superpowers, document-skills, example-skills, everything-claude-code, paper-reading, humanizer, adversarial-review, update | All On |
| Skills — AI Research (7) | tokenization, fine-tuning, post-training, distributed-training, inference-serving, optimization, deepxiv | All Off |
| MCP Servers (5) | context7, github, playwright, openaiDeveloperDocs, lark-mcp | All On except lark-mcp |
```

- [ ] **Step 2: Update `README.zh-CN.md` with the same installer behavior and group/default mapping**

Mirror the English changes in Chinese, using the same examples and defaults, for example:

```md
./install.sh              # 交互式选择安装
./install.sh --all        # 非交互全量安装
```

And add the Chinese table for the five groups and their defaults.

- [ ] **Step 3: Add a version-level `CHANGELOG.md` entry for the installer UX change**

Add a new top entry in this format:

```md
## [next-version] - 2026-04-08
### Features
- Added a main-style interactive installer to the Codex branch for Bash and PowerShell.
- Added Codex-native selectable groups for core files, agents, recommended skills, AI research skills, and MCP servers.

### Design Rationale
- Preserved the familiar first-run UX from the Claude-oriented main branch while keeping Codex concepts honest.
- Kept explicit CLI flags backward-compatible to avoid breaking automation.

### Notes & Caveats
- `config.toml` is still not overwritten when already present.
- MCP setup still requires the `codex` CLI.
- Some remote skill packs still depend on the installed skill-installer and upstream availability.
```

Use the actual version value if the repository updates `VERSION`; otherwise use the next planned version string consistently.

- [ ] **Step 4: Run grep-based documentation verification**

Run:
```bash
grep -n "Interactive selector" README.md
grep -n "交互" README.zh-CN.md
grep -n "Codex branch" CHANGELOG.md
```
Expected: the README files and changelog all mention the new installer flow.

- [ ] **Step 5: Commit docs and changelog updates**

Run:
```bash
git add README.md README.zh-CN.md CHANGELOG.md
git commit -m "docs: document codex interactive installer"
```
Expected: one docs-focused commit.

---

### Task 6: End-to-end verification and final integration check

**Files:**
- Modify if needed: `install.sh`, `install.ps1`, `README.md`, `README.zh-CN.md`, `CHANGELOG.md`
- Test: final manual verification commands

- [ ] **Step 1: Re-run Bash verification suite**

Run:
```bash
bash -n install.sh
./install.sh --all --dry-run
```
Expected:
- Bash parser passes
- dry-run prints all major install categories without crashing

- [ ] **Step 2: Re-run PowerShell verification suite**

Run:
```bash
pwsh -NoProfile -Command "[void][scriptblock]::Create((Get-Content install.ps1 -Raw)); 'parse-ok'"
pwsh -NoProfile -File ./install.ps1 -All -DryRun
```
Expected:
- `parse-ok`
- PowerShell dry-run completes without terminating errors

- [ ] **Step 3: Smoke-test the interactive flows manually**

Run:
```bash
./install.sh
pwsh -NoProfile -File ./install.ps1
```
Expected:
- main menu renders
- submenu navigation works
- defaults match the spec
- submit returns a selected-install path rather than a coarse full install path

- [ ] **Step 4: Inspect the final diff for scope control**

Run:
```bash
git diff --stat HEAD~5..HEAD
git diff -- install.sh install.ps1 README.md README.zh-CN.md CHANGELOG.md
```
Expected: only installer/docs/changelog files changed for this feature.

- [ ] **Step 5: Create the final integration commit**

Run:
```bash
git add install.sh install.ps1 README.md README.zh-CN.md CHANGELOG.md
git commit -m "feat: add interactive installer for codex config"
```
Expected: one final integration commit if there are remaining staged changes after task-level commits.

---

## Self-Review

### Spec coverage

- Interactive no-arg behavior for Bash and PowerShell: covered in Tasks 1 and 3.
- Codex-native groups and defaults: covered in Tasks 1, 3, and 5.
- Item-aware core/agent/skill/MCP installs: covered in Tasks 2 and 4.
- Backward-compatible CLI flags: covered in Tasks 2 and 4.
- README updates: covered in Task 5.
- Version-level changelog maintenance: covered in Task 5.
- Verification: covered in Task 6.

### Placeholder scan

- No `TODO` / `TBD` placeholders intentionally left in plan content.
- All tasks include exact file targets and concrete command examples.
- Code steps include actual snippets rather than abstract instructions.

### Type and naming consistency

- Bash selection names use `SELECT_*` consistently.
- PowerShell selection names use `$Selection.*` consistently.
- Menu IDs map consistently to `core-*`, `agent-*`, `skill-*`, `ai-*`, and `mcp-*` namespaces.
