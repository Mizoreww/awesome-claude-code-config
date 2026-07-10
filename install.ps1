#Requires -Version 5.1
<#
.SYNOPSIS
  Codex Configuration Installer (Windows)
  https://github.com/Mizoreww/awesome-claude-code-config

.DESCRIPTION
  Install Codex configuration files on Windows. PowerShell equivalent of install.sh.
  Running without component flags launches an interactive selector.
  Use -All for non-interactive full install.

.PARAMETER All
  Install everything non-interactively

.PARAMETER Core
  Install AGENTS.md, lessons.md, config.toml, agents/*

.PARAMETER Mcp
  Install MCP servers only

.PARAMETER Skills
  Install skills only

.PARAMETER SkillGroup
  Skill group: core, ai-research, all (default: all)

.PARAMETER Uninstall
  Uninstall managed files. Combine with -Core, -Mcp, -Skills to select components.

.PARAMETER Version
  Show source / installed / remote versions

.PARAMETER DryRun
  Preview changes without applying

.PARAMETER Force
  Skip destructive confirmations

.EXAMPLE
  .\install.ps1
  .\install.ps1 -All
  .\install.ps1 -Skills -SkillGroup core
  .\install.ps1 -Skills -SkillGroup ai-research
  .\install.ps1 -Uninstall -Skills
  $env:VERSION="v1.0.0"; irm https://raw.githubusercontent.com/Mizoreww/awesome-claude-code-config/codex/install.ps1 | iex
#>
[CmdletBinding()]
param(
    [switch]$All,
    [switch]$Core,
    [switch]$Mcp,
    [switch]$Skills,
    [ValidateSet("core", "ai-research", "all")]
    [string]$SkillGroup = "all",
    [switch]$Uninstall,
    [switch]$Version,
    [switch]$DryRun,
    [switch]$Force,
    [switch]$Help
)

$ErrorActionPreference = "Stop"

# ============================================================
# Paths
# ============================================================
$CODEX_DIR            = Join-Path $HOME ".codex"
$script:REPO_OWNER    = if ($env:REPO_OWNER) { $env:REPO_OWNER } else { "Mizoreww" }
$script:REPO_NAME     = if ($env:REPO_NAME) { $env:REPO_NAME } else { "awesome-claude-code-config" }
$script:REPO_BRANCH   = if ($env:REPO_BRANCH) { $env:REPO_BRANCH } else { "codex" }
# These values are interpolated into download URLs used in remote mode.
# Validate against a safe charset so a hostile/garbled environment cannot
# smuggle unexpected content into the URLs.
if ($script:REPO_OWNER -notmatch '^[A-Za-z0-9._-]+$') {
    Write-Host "[ERROR] Invalid REPO_OWNER: $($script:REPO_OWNER)" -ForegroundColor Red
    exit 1
}
if ($script:REPO_NAME -notmatch '^[A-Za-z0-9._-]+$') {
    Write-Host "[ERROR] Invalid REPO_NAME: $($script:REPO_NAME)" -ForegroundColor Red
    exit 1
}
if ($script:REPO_BRANCH -notmatch '^[A-Za-z0-9._/-]+$') {
    Write-Host "[ERROR] Invalid REPO_BRANCH: $($script:REPO_BRANCH)" -ForegroundColor Red
    exit 1
}
$script:REPO_URL      = "https://github.com/$($script:REPO_OWNER)/$($script:REPO_NAME)"
$VERSION_STAMP_FILE   = Join-Path $CODEX_DIR ".codex-config-version"
$LEGACY_VERSION_STAMP_FILE = Join-Path $CODEX_DIR ".claude-code-config-version"
$INSTALLER            = Join-Path $CODEX_DIR "skills/.system/skill-installer/scripts/install-skill-from-github.py"
$SUPERPOWERS_REPO_URL = "https://github.com/obra/superpowers.git"
$SUPERPOWERS_DIR      = Join-Path $CODEX_DIR "superpowers"
$AGENTS_SKILLS_DIR    = Join-Path $HOME ".agents/skills"
$SUPERPOWERS_LINK     = Join-Path $AGENTS_SKILLS_DIR "superpowers"

$script:InteractiveMode = $false
$script:InteractiveSelectionHasAny = $false
$script:SKIPPED_COMPONENTS = @()
$script:MCP_FAILED_SERVERS = @()
$script:LessonsSeeded = $false
$script:SelectCoreAgentsMd = $true
$script:SelectCoreConfig = $true
$script:SelectCoreLessons = $true
$script:SelectCoreStatusLine = $true
$script:SelectAgentExplorer = $true
$script:SelectAgentReviewer = $true
$script:SelectAgentDocsResearcher = $true
$script:SelectSkillSuperpowers = $false
$script:SelectSkillDocumentSkills = $true
$script:SelectSkillExampleSkills = $true
$script:SelectSkillFrontendDesign = $true
$script:SelectSkillKarpathy = $true
$script:SelectSkillMattPocock = $true
$script:SelectSkillCodeReview = $true
$script:SelectSkillPUA = $false
$script:SelectSkillFrontendSlides = $false
$script:SelectSkillPaperReading = $true
$script:SelectSkillHumanizer = $true
$script:SelectSkillHumanizerZh = $false
$script:SelectSkillHandoff = $true
$script:SelectSkillAdversarialReview = $true
$script:SelectSkillUpdate = $true
$script:SelectAiTokenization = $false
$script:SelectAiFineTuning = $false
$script:SelectAiPostTraining = $false
$script:SelectAiDistributedTraining = $false
$script:SelectAiInferenceServing = $false
$script:SelectAiOptimization = $false
$script:SelectAiDeepXiv = $false
$script:SelectMcpContext7 = $true
$script:SelectMcpGithub = $true
$script:SelectMcpPlaywright = $true
$script:SelectMcpOpenaiDeveloperDocs = $true
$script:SelectMcpLark = $false

$MANAGED_SKILLS = @(
    "frontend-design", "pdf", "docx", "pptx", "xlsx", "canvas-design", "algorithmic-art", "mcp-builder",
    "using-superpowers", "systematic-debugging", "writing-plans", "test-driven-development",
    "huggingface-tokenizers", "sentencepiece",
    "axolotl", "llama-factory", "peft", "unsloth",
    "grpo-rl-training", "openrlhf", "simpo", "trl-fine-tuning", "verl",
    "deepspeed", "pytorch-fsdp2", "megatron-core", "ray-train",
    "awq", "gptq", "gguf", "flash-attention", "bitsandbytes",
    "vllm", "sglang", "tensorrt-llm", "llama-cpp",
    "paper-reading",
    "adversarial-review",
    "handoff",
    "humanizer",
    "humanizer-zh",
    "update",
    "deepxiv-cli",
    "deepxiv-baseline-table",
    "deepxiv-trending-digest",
    "code-review",
    "karpathy-guidelines",
    "brainstorming", "dispatching-parallel-agents", "executing-plans", "finishing-a-development-branch",
    "receiving-code-review", "requesting-code-review", "subagent-driven-development", "using-git-worktrees",
    "verification-before-completion", "writing-skills",
    "frontend-slides",
    "ask-matt", "diagnosing-bugs", "grill-with-docs", "triage",
    "implement", "improve-codebase-architecture", "setup-matt-pocock-skills", "tdd",
    "to-issues", "to-prd", "prototype", "domain-modeling", "codebase-design",
    "grill-me", "grilling", "research", "teach", "writing-great-skills",
    "pua", "pua-en", "pua-ja"
)

$LEGACY_CLEANUP_SKILLS = @(
    "python-patterns", "python-testing", "golang-patterns", "golang-testing", "frontend-patterns",
    "security-review", "tdd-workflow", "verification-loop", "api-design", "database-migrations"
)

$OWNERSHIP_SKILLS = @($MANAGED_SKILLS) + @($LEGACY_CLEANUP_SKILLS)

$LEGACY_SUPERPOWERS_SKILLS = @(
    "using-superpowers",
    "systematic-debugging",
    "writing-plans",
    "test-driven-development"
)

$MATTPOCOCK_SKILLS = @(
    "ask-matt", "diagnosing-bugs", "grill-with-docs", "triage",
    "implement", "improve-codebase-architecture", "setup-matt-pocock-skills", "tdd",
    "to-issues", "to-prd", "prototype", "domain-modeling", "codebase-design",
    "grill-me", "grilling", "research", "teach", "writing-great-skills"
)

$PUA_SKILLS = @("pua", "pua-en", "pua-ja")
$SUPERPOWERS_SKILLS = @(
    "brainstorming", "dispatching-parallel-agents", "executing-plans", "finishing-a-development-branch",
    "receiving-code-review", "requesting-code-review", "subagent-driven-development", "systematic-debugging",
    "test-driven-development", "using-git-worktrees", "using-superpowers", "verification-before-completion",
    "writing-plans", "writing-skills"
)
$LOCAL_MANAGED_SKILLS = @("paper-reading", "humanizer", "humanizer-zh", "handoff", "adversarial-review", "update")
$MANAGED_SKILLS_STATE_FILE = Join-Path $CODEX_DIR ".awesome-claude-code-config-managed-skills"
$GLOBAL_SKILL_LOCK_FILE = Join-Path $HOME ".agents/.skill-lock.json"
$script:OwnedManagedSkills = New-Object 'System.Collections.Generic.HashSet[string]'
$script:ManagedSkillOwnershipLoaded = $false
$script:MattPocockQuickstartReady = $false
$script:CODEX_STATUS_LINE = 'status_line = ["model", "reasoning", "project-name", "git-branch", "context-used", "five-hour-limit", "weekly-limit"]'
$script:CODEX_STATUS_LINE_USE_COLORS = 'status_line_use_colors = true'
$script:PLAYWRIGHT_MCP_VERSION = "0.0.78"
$script:PLAYWRIGHT_MIN_NODE_MAJOR = 20
$script:PLAYWRIGHT_NODE_FALLBACK_VERSION = "24"

# ============================================================
# Output helpers
# ============================================================
function Write-Info  { param($msg) Write-Host "[INFO]  $msg" -ForegroundColor Cyan }
function Write-Ok    { param($msg) Write-Host "[OK]    $msg" -ForegroundColor Green }
function Write-Warn  { param($msg) Write-Host "[WARN]  $msg" -ForegroundColor Yellow }
function Write-Err   { param($msg) Write-Host "[ERROR] $msg" -ForegroundColor Red }

function Show-MattPocockQuickstart {
    if (-not $script:MattPocockQuickstartReady -or $DryRun) { return }

    @(
        "",
        "Matt Pocock skills quickstart (30-second setup)",
        "  Matt Pocock skills are already installed; do not run npx again.",
        "  1. Restart Codex if it was open during installation.",
        "  2. Type /skills (or press @), choose List skills, then search for setup-matt-pocock-skills.",
        "  3. Insert and run it; it will ask about your issue tracker, triage labels, and docs location.",
        "  Note: installed skills are not individual root slash commands such as /setup-matt-pocock-skills."
    )
}

# ============================================================
# Script directory detection
# ============================================================
$script:SCRIPT_DIR   = ""
$script:REMOTE_MODE  = $false
$script:TempDir      = $null

function Detect-ScriptDir {
    # $PSScriptRoot is set when running from a file; empty in piped/iex mode
    $candidate = $PSScriptRoot

    if ($candidate -and (Test-Path (Join-Path $candidate "AGENTS.md"))) {
        $script:SCRIPT_DIR  = $candidate
        $script:REMOTE_MODE = $false
        return
    }

    $script:REMOTE_MODE = $true
    $tmpdir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
    New-Item -ItemType Directory -Path $tmpdir -Force | Out-Null
    $script:TempDir = $tmpdir

    $version = if ($env:VERSION) { $env:VERSION } else { $script:REPO_BRANCH }
    $tarball_url = "$($script:REPO_URL)/archive/refs/heads/${version}.tar.gz"
    if ($version -match '^v[0-9]') {
        $tarball_url = "$($script:REPO_URL)/archive/refs/tags/${version}.tar.gz"
    }

    Write-Info "Remote mode: downloading $version..."
    $tarball = Join-Path $tmpdir "archive.tar.gz"
    try {
        Invoke-WebRequest -Uri $tarball_url -OutFile $tarball -UseBasicParsing
        # tar is available on Windows 10 1803+. Native command failures do not
        # throw under Windows PowerShell 5.1, so check the exit code explicitly
        # instead of relying on the catch block.
        tar -xzf $tarball -C $tmpdir --strip-components=1
        if ($LASTEXITCODE -ne 0) {
            throw "tar extraction failed with exit code $LASTEXITCODE"
        }
        Remove-Item $tarball -Force
    } catch {
        Write-Err "Failed to download source: $_"
        exit 1
    }

    $script:SCRIPT_DIR = $tmpdir
    Write-Ok "Source downloaded to temporary directory"
}

function Remove-TempDir {
    if ($script:TempDir -and (Test-Path $script:TempDir)) {
        Remove-Item -Recurse -Force $script:TempDir -ErrorAction SilentlyContinue
    }
}

# ============================================================
# Utilities
# ============================================================
function Test-PythonCommand {
    param([string[]]$Command)

    if (-not $Command -or $Command.Count -eq 0) {
        return $false
    }

    $exe = $Command[0]
    $baseArgs = @()
    if ($Command.Count -gt 1) {
        $baseArgs = $Command[1..($Command.Count - 1)]
    }

    try {
        $probeArgs = @()
        $probeArgs += $baseArgs
        $probeArgs += @("-c", "import sys; raise SystemExit(0 if sys.version_info[0] >= 3 else 1)")
        & $exe @probeArgs *> $null
        return ($LASTEXITCODE -eq 0)
    } catch {
        return $false
    }
}

function Resolve-PythonCommand {
    $candidates = @()

    if ($env:PYTHON) {
        $candidates += ,@($env:PYTHON)
    }

    foreach ($pyLauncher in @(Get-Command "py" -CommandType Application -ErrorAction SilentlyContinue)) {
        if ($pyLauncher) {
            $candidates += ,@($pyLauncher.Source, "-3")
        }
    }

    foreach ($name in @("python3", "python")) {
        foreach ($cmd in @(Get-Command $name -CommandType Application -ErrorAction SilentlyContinue)) {
            if ($cmd) {
                $candidates += ,@($cmd.Source)
            }
        }
    }

    foreach ($candidate in $candidates) {
        if (Test-PythonCommand $candidate) {
            return ,$candidate
        }
    }

    return $null
}

function Show-Usage {
    @"
Usage: .\install.ps1 [OPTIONS]

Install Codex configuration files.
Running without component flags launches an interactive selector.
Use -All for non-interactive full install.

Options:
  -All                       Install everything non-interactively
  -Core                      Install AGENTS.md, lessons.md, config.toml, agents/*
  -Mcp                       Install MCP servers only
  -Skills [-SkillGroup GROUP] Install skills only. GROUP: core, ai-research, all (default: all)
  -Uninstall [-Core] [-Mcp] [-Skills]
                             Uninstall managed files (all components if none specified)
  -Version                   Show source / installed / remote versions
  -DryRun                    Preview changes without applying
  -Force                     Skip destructive confirmations
  -Help                      Show help

Examples:
  .\install.ps1
  .\install.ps1 -Skills -SkillGroup core
  .\install.ps1 -Skills -SkillGroup ai-research
  .\install.ps1 -Uninstall -Skills
  `$env:VERSION='v1.0.0'; irm $($script:REPO_URL)/raw/$($script:REPO_BRANCH)/install.ps1 | iex
"@
}

function Backup-IfExists {
    param([string]$Target)
    if (Test-Path $Target) {
        $timestamp = Get-Date -Format 'yyyyMMddHHmmss'
        $backup = "${Target}.backup.${timestamp}"
        if ($DryRun) {
            Write-Warn "Would backup: $Target -> $backup"
        } else {
            Copy-Item -Recurse $Target $backup
            Write-Warn "Backed up: $Target -> $backup"
        }
    }
}

function Confirm-Action {
    param([string]$Prompt = "Continue?")
    if ($Force) { return $true }
    $answer = Read-Host "$Prompt [y/N]"
    return ($answer -match '^[Yy]$')
}

function Get-SourceVersion {
    $f = Join-Path $script:SCRIPT_DIR "VERSION"
    if (Test-Path $f) { return (Get-Content $f -Raw).Trim() }
    return "unknown"
}

function Get-InstalledVersion {
    if (Test-Path $VERSION_STAMP_FILE) {
        return (Get-Content $VERSION_STAMP_FILE -Raw).Trim()
    }
    if (Test-Path $LEGACY_VERSION_STAMP_FILE) {
        return (Get-Content $LEGACY_VERSION_STAMP_FILE -Raw).Trim()
    }
    return "not installed"
}

function Get-RemoteVersion {
    try {
        $url = "https://raw.githubusercontent.com/$($script:REPO_OWNER)/$($script:REPO_NAME)/$($script:REPO_BRANCH)/VERSION"
        $r = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 10
        return $r.Content.Trim()
    } catch {
        return "unavailable"
    }
}

function Show-Version {
    $src  = Get-SourceVersion
    $inst = Get-InstalledVersion
    $rem  = Get-RemoteVersion

    Write-Host "codex-config version info:"
    Write-Host "  Source:    $src"
    Write-Host "  Installed: $inst"
    Write-Host "  Remote:    $rem"

    if ($inst -ne "not installed" -and $rem -ne "unavailable" -and $inst -ne $rem) {
        Write-Warn "Update available: $inst -> $rem"
    }
}

function Set-VersionStamp {
    $ver = Get-SourceVersion
    if ($ver -ne "unknown" -and -not $DryRun) {
        # Component-only installs may run before ~/.codex exists.
        New-Item -ItemType Directory -Path $CODEX_DIR -Force | Out-Null
        Set-Content -Path $VERSION_STAMP_FILE -Value $ver -NoNewline
        Remove-Item -Force $LEGACY_VERSION_STAMP_FILE -ErrorAction SilentlyContinue
    }
}

function Reset-InteractiveSelections {
    $script:SelectCoreAgentsMd = $true
    $script:SelectCoreConfig = $true
    $script:SelectCoreLessons = $true
    $script:SelectCoreStatusLine = $true
    $script:SelectAgentExplorer = $true
    $script:SelectAgentReviewer = $true
    $script:SelectAgentDocsResearcher = $true
    $script:SelectSkillSuperpowers = $false
    $script:SelectSkillDocumentSkills = $true
    $script:SelectSkillExampleSkills = $true
    $script:SelectSkillFrontendDesign = $true
    $script:SelectSkillKarpathy = $true
    $script:SelectSkillMattPocock = $true
    $script:SelectSkillCodeReview = $true
    $script:SelectSkillPUA = $false
    $script:SelectSkillFrontendSlides = $false
    $script:SelectSkillPaperReading = $true
    $script:SelectSkillHumanizer = $true
    $script:SelectSkillHumanizerZh = $false
    $script:SelectSkillHandoff = $true
    $script:SelectSkillAdversarialReview = $true
    $script:SelectSkillUpdate = $true
    $script:SelectAiTokenization = $false
    $script:SelectAiFineTuning = $false
    $script:SelectAiPostTraining = $false
    $script:SelectAiDistributedTraining = $false
    $script:SelectAiInferenceServing = $false
    $script:SelectAiOptimization = $false
    $script:SelectAiDeepXiv = $false
    $script:SelectMcpContext7 = $true
    $script:SelectMcpGithub = $true
    $script:SelectMcpPlaywright = $true
    $script:SelectMcpOpenaiDeveloperDocs = $true
    $script:SelectMcpLark = $false
}

function Copy-SelectedFile {
    param(
        [bool]$Selected,
        [string]$Source,
        [string]$Target,
        [string]$Label,
        [switch]$SkipIfExists
    )

    if (-not $Selected) { return }

    if ($SkipIfExists -and (Test-Path $Target)) {
        Write-Warn "$Target exists -- skipping (merge manually if needed)"
        return
    }

    if (Test-Path $Target) {
        Backup-IfExists $Target
    }

    if ($DryRun) {
        Write-Info "Would copy: $Label -> $Target"
    } else {
        $parent = Split-Path $Target -Parent
        if ($parent) {
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
        }
        Copy-Item $Source $Target -Force
        Write-Ok "$Label installed"
    }
}

function Copy-SelectedDirectory {
    param(
        [bool]$Selected,
        [string]$Source,
        [string]$Target,
        [string]$Label
    )

    if (-not $Selected) { return }

    if (Test-Path $Target) {
        Backup-IfExists $Target
    }

    if ($DryRun) {
        Write-Info "Would copy: $Label -> $Target"
    } else {
        $parent = Split-Path $Target -Parent
        if ($parent) {
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
        }
        if (Test-Path $Target) {
            Remove-Item -Recurse -Force $Target
        }
        Copy-Item $Source $Target -Recurse -Force
        $skillName = Split-Path $Target -Leaf
        if (Test-ManagedSkillName $skillName) {
            Add-ManagedSkillOwnership @($skillName)
        }
        Write-Ok "$Label installed"
    }
}

# lessons.md is the user's accumulated correction memory (see AGENTS.md), and
# config.toml points model_instructions_file at it. Never overwrite an existing
# copy; only seed the template when the file is absent.
function Install-LessonsIfMissing {
    if ($script:LessonsSeeded) { return }
    $script:LessonsSeeded = $true

    $target = Join-Path $CODEX_DIR "lessons.md"
    if (Test-Path $target) {
        Write-Info "Preserving existing lessons.md (template not copied)"
        return
    }

    if ($DryRun) {
        Write-Info "Would copy: lessons.md -> $target"
    } else {
        New-Item -ItemType Directory -Path $CODEX_DIR -Force | Out-Null
        Copy-Item (Join-Path $script:SCRIPT_DIR "lessons.md") $target -Force
        Write-Ok "lessons.md installed"
    }
}

function Install-ConfigTemplate {
    $target = Join-Path $CODEX_DIR "config.toml"
    if (Test-Path $target) {
        Write-Warn "$target exists -- skipping (merge manually if needed)"
        return
    }

    if ($DryRun) {
        Write-Info "Would copy: config.toml -> $target"
        return
    }

    if ($script:InteractiveMode -and -not $script:SelectCoreStatusLine) {
        $skipTui = $false
        $templateLines = foreach ($line in (Get-Content (Join-Path $script:SCRIPT_DIR "config.toml"))) {
            if ($line -match '^\[tui\]\s*$') {
                $skipTui = $true
                continue
            }
            if ($line -match '^\[') {
                $skipTui = $false
            }
            if (-not $skipTui) {
                $line
            }
        }
        Set-Content -Path $target -Value $templateLines -Encoding UTF8
    } else {
        Copy-Item (Join-Path $script:SCRIPT_DIR "config.toml") $target -Force
    }
    Write-Ok "config.toml installed"
}

function Ensure-StatusLineSetting {
    $target = Join-Path $CODEX_DIR "config.toml"

    if ($DryRun) {
        Write-Info "Would ensure Codex [tui].status_line in $target"
        return
    }

    New-Item -ItemType Directory -Path $CODEX_DIR -Force | Out-Null
    if (-not (Test-Path $target)) {
        Copy-Item (Join-Path $script:SCRIPT_DIR "config.toml") $target -Force
        if (-not (Test-Path (Join-Path $CODEX_DIR "lessons.md"))) {
            Write-Warn "config.toml requires lessons.md (model_instructions_file); seeding it while installing StatusLine"
        }
        Install-LessonsIfMissing
        Write-Ok "config.toml installed with [tui].status_line"
        return
    }

    $lines = Get-Content $target
    $sawTui = $false
    $skipStatusArray = $false
    $updated = New-Object System.Collections.Generic.List[string]

    foreach ($line in $lines) {
        if ($skipStatusArray) {
            if ($line -match '\]') {
                $skipStatusArray = $false
            }
            continue
        }

        if ($line -match '^\[tui\]\s*$') {
            $updated.Add($line)
            $updated.Add($script:CODEX_STATUS_LINE)
            $updated.Add($script:CODEX_STATUS_LINE_USE_COLORS)
            $sawTui = $true
            continue
        }

        if ($line -match '^\s*status_line\s*=' -or
            $line -match '^\s*status_line_use_colors\s*=') {
            if ($line -match '^\s*status_line\s*=' -and $line -match '\[' -and $line -notmatch '\]') {
                $skipStatusArray = $true
            }
            continue
        }

        $updated.Add($line)
    }

    if (-not $sawTui) {
        if ($updated.Count -gt 0 -and $updated[$updated.Count - 1] -ne "") {
            $updated.Add("")
        }
        $updated.Add("[tui]")
        $updated.Add($script:CODEX_STATUS_LINE)
        $updated.Add($script:CODEX_STATUS_LINE_USE_COLORS)
    }

    Set-Content -Path $target -Value $updated -Encoding UTF8
    Write-Ok "[tui].status_line ensured in config.toml"
}

function Install-SelectedCoreFiles {
    Write-Info "Installing selected core files..."

    if (-not $DryRun) {
        New-Item -ItemType Directory -Path $CODEX_DIR -Force | Out-Null
    }

    Copy-SelectedFile -Selected $script:SelectCoreAgentsMd `
        -Source (Join-Path $script:SCRIPT_DIR "AGENTS.md") `
        -Target (Join-Path $CODEX_DIR "AGENTS.md") `
        -Label "AGENTS.md"
    if ($script:SelectCoreLessons) {
        Install-LessonsIfMissing
    }

    if ($script:SelectCoreConfig) {
        Install-ConfigTemplate
        # config.toml references lessons.md via model_instructions_file; make
        # sure the file exists even when the Lessons item was deselected.
        if (-not $script:SelectCoreLessons -and -not (Test-Path (Join-Path $CODEX_DIR "lessons.md"))) {
            Write-Warn "config.toml requires lessons.md (model_instructions_file); seeding it although Lessons was deselected"
        }
        Install-LessonsIfMissing
    }

    if ($script:SelectCoreStatusLine) {
        Ensure-StatusLineSetting
    }
}

function Install-SelectedAgents {
    $anySelected = $script:SelectAgentExplorer -or $script:SelectAgentReviewer -or $script:SelectAgentDocsResearcher
    if (-not $anySelected) { return }

    Write-Info "Installing selected agents..."
    if (-not $DryRun) {
        New-Item -ItemType Directory -Path (Join-Path $CODEX_DIR "agents") -Force | Out-Null
    }

    Copy-SelectedFile -Selected $script:SelectAgentExplorer `
        -Source (Join-Path $script:SCRIPT_DIR "agents/explorer.toml") `
        -Target (Join-Path $CODEX_DIR "agents/explorer.toml") `
        -Label "agents/explorer.toml"
    Copy-SelectedFile -Selected $script:SelectAgentReviewer `
        -Source (Join-Path $script:SCRIPT_DIR "agents/reviewer.toml") `
        -Target (Join-Path $CODEX_DIR "agents/reviewer.toml") `
        -Label "agents/reviewer.toml"
    Copy-SelectedFile -Selected $script:SelectAgentDocsResearcher `
        -Source (Join-Path $script:SCRIPT_DIR "agents/docs-researcher.toml") `
        -Target (Join-Path $CODEX_DIR "agents/docs-researcher.toml") `
        -Label "agents/docs-researcher.toml"
}

function Install-SelectedRecommendedSkills {
    if ($script:SelectSkillCodeReview) {
        if (-not (Install-NpxSkillNames "mattpocock/skills" @("code-review"))) {
            Skip-UnsupportedItem "code-review" "npx skills install failed; use Codex /review as the native fallback"
        }
    }

    if ($script:SelectSkillKarpathy) {
        if (-not (Install-NpxSkillNames "forrestchang/andrej-karpathy-skills" @("karpathy-guidelines"))) {
            Skip-UnsupportedItem "andrej-karpathy-skills" "npx skills install failed"
        }
    }

    if ($script:SelectSkillSuperpowers) {
        Install-Superpowers
    }

    if ($script:SelectSkillMattPocock) {
        if (Install-NpxSkillNames "mattpocock/skills" $MATTPOCOCK_SKILLS) {
            $script:MattPocockQuickstartReady = $true
        } else {
            Skip-UnsupportedItem "mattpocock/skills" "npx skills install failed"
        }
    }

    if ($script:SelectSkillDocumentSkills) {
        Install-SkillPaths "anthropics/skills" @(
            "skills/pdf", "skills/docx", "skills/pptx", "skills/xlsx"
        )
    }

    if ($script:SelectSkillExampleSkills) {
        Install-SkillPaths "anthropics/skills" @(
            "skills/canvas-design", "skills/algorithmic-art", "skills/mcp-builder"
        )
    }

    if ($script:SelectSkillFrontendDesign) {
        Install-SkillPaths "anthropics/skills" @("skills/frontend-design")
    }

    if ($script:SelectSkillPUA) {
        if (-not (Install-NpxSkillNames "tanweai/pua" $PUA_SKILLS)) {
            Skip-UnsupportedItem "PUA" "npx skills install failed"
        }
    }
    if ($script:SelectSkillFrontendSlides) {
        if (-not (Install-NpxSkillNames "zarazhangrui/frontend-slides" @("frontend-slides"))) {
            Skip-UnsupportedItem "frontend-slides" "npx skills install failed"
        }
    }
    if ($script:SelectSkillPaperReading -or $script:SelectSkillHumanizer -or $script:SelectSkillHumanizerZh -or
        $script:SelectSkillHandoff -or $script:SelectSkillAdversarialReview -or $script:SelectSkillUpdate) {
        if (-not $DryRun) {
            New-Item -ItemType Directory -Path (Join-Path $CODEX_DIR "skills") -Force | Out-Null
        }
    }

    if ($script:SelectSkillPaperReading) {
        Copy-SelectedDirectory -Selected $true `
            -Source (Join-Path $script:SCRIPT_DIR "skills/paper-reading") `
            -Target (Join-Path $CODEX_DIR "skills/paper-reading") `
            -Label "skills/paper-reading/"
    }
    if ($script:SelectSkillHumanizer) {
        Copy-SelectedDirectory -Selected $true `
            -Source (Join-Path $script:SCRIPT_DIR "skills/humanizer") `
            -Target (Join-Path $CODEX_DIR "skills/humanizer") `
            -Label "skills/humanizer/"
    }
    if ($script:SelectSkillHumanizerZh) {
        Copy-SelectedDirectory -Selected $true `
            -Source (Join-Path $script:SCRIPT_DIR "skills/humanizer-zh") `
            -Target (Join-Path $CODEX_DIR "skills/humanizer-zh") `
            -Label "skills/humanizer-zh/"
    }
    if ($script:SelectSkillHandoff) {
        Copy-SelectedDirectory -Selected $true `
            -Source (Join-Path $script:SCRIPT_DIR "skills/handoff") `
            -Target (Join-Path $CODEX_DIR "skills/handoff") `
            -Label "skills/handoff/"
    }
    if ($script:SelectSkillAdversarialReview) {
        Copy-SelectedDirectory -Selected $true `
            -Source (Join-Path $script:SCRIPT_DIR "skills/adversarial-review") `
            -Target (Join-Path $CODEX_DIR "skills/adversarial-review") `
            -Label "skills/adversarial-review/"
    }
    if ($script:SelectSkillUpdate) {
        Copy-SelectedDirectory -Selected $true `
            -Source (Join-Path $script:SCRIPT_DIR "skills/update") `
            -Target (Join-Path $CODEX_DIR "skills/update") `
            -Label "skills/update/"
    }
}

function Install-SelectedAiSkills {
    if ($script:SelectAiTokenization) {
        Install-SkillPaths "zechenzhangAGI/AI-research-SKILLs" @(
            "02-tokenization/huggingface-tokenizers", "02-tokenization/sentencepiece"
        )
    }
    if ($script:SelectAiFineTuning) {
        Install-SkillPaths "zechenzhangAGI/AI-research-SKILLs" @(
            "03-fine-tuning/axolotl", "03-fine-tuning/llama-factory", "03-fine-tuning/peft", "03-fine-tuning/unsloth"
        )
    }
    if ($script:SelectAiPostTraining) {
        Install-SkillPaths "zechenzhangAGI/AI-research-SKILLs" @(
            "06-post-training/grpo-rl-training", "06-post-training/openrlhf", "06-post-training/simpo",
            "06-post-training/trl-fine-tuning", "06-post-training/verl"
        )
    }
    if ($script:SelectAiDistributedTraining) {
        Install-SkillPaths "zechenzhangAGI/AI-research-SKILLs" @(
            "08-distributed-training/deepspeed", "08-distributed-training/pytorch-fsdp2",
            "08-distributed-training/megatron-core", "08-distributed-training/ray-train"
        )
    }
    if ($script:SelectAiInferenceServing) {
        Install-SkillPaths "zechenzhangAGI/AI-research-SKILLs" @(
            "12-inference-serving/vllm", "12-inference-serving/sglang",
            "12-inference-serving/tensorrt-llm", "12-inference-serving/llama-cpp"
        )
    }
    if ($script:SelectAiOptimization) {
        Install-SkillPaths "zechenzhangAGI/AI-research-SKILLs" @(
            "10-optimization/awq", "10-optimization/gptq", "10-optimization/gguf",
            "10-optimization/flash-attention", "10-optimization/bitsandbytes"
        )
    }
    if ($script:SelectAiDeepXiv) {
        Reinstall-SkillPaths "DeepXiv/deepxiv_sdk" @(
            "skills/deepxiv-cli", "skills/deepxiv-baseline-table", "skills/deepxiv-trending-digest"
        )
    }
}

function Add-McpServer {
    param([string]$Name, [string[]]$Arguments)

    if ($DryRun) {
        Write-Info "Would add MCP server: $Name"
        return
    }

    codex mcp add $Name @Arguments 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Warn "Failed to configure MCP server: $Name"
        $script:MCP_FAILED_SERVERS += $Name
    } else {
        Write-Ok "MCP server configured: $Name"
    }
}

function Get-NodeMajorVersion {
    if (-not (Get-Command "node" -ErrorAction SilentlyContinue)) {
        return $null
    }

    $versionText = (& node --version 2>$null)
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($versionText)) {
        return $null
    }

    $major = 0
    $majorText = $versionText.ToString().Trim().TrimStart("v").Split(".")[0]
    if (-not [int]::TryParse($majorText, [ref]$major)) {
        return $null
    }
    return $major
}

function Add-PlaywrightMcpServer {
    $nodeMajor = Get-NodeMajorVersion
    $package = "@playwright/mcp@$($script:PLAYWRIGHT_MCP_VERSION)"

    if ($null -eq $nodeMajor) {
        if (-not $DryRun) {
            Write-Warn "Node.js is unavailable or its version could not be read; skipping Playwright MCP"
            $script:MCP_FAILED_SERVERS += "playwright"
            return
        }
        $nodeMajor = 0
    }

    if (-not (Get-Command "npx" -ErrorAction SilentlyContinue) -and -not $DryRun) {
        Write-Warn "npx is unavailable; skipping Playwright MCP"
        $script:MCP_FAILED_SERVERS += "playwright"
        return
    }

    if ($nodeMajor -lt $script:PLAYWRIGHT_MIN_NODE_MAJOR) {
        Write-Warn "Node.js $nodeMajor detected; using an isolated Node.js $($script:PLAYWRIGHT_NODE_FALLBACK_VERSION) runtime for Playwright MCP"
        $launcherArgs = @(
            "-y",
            "--loglevel=error",
            "--package=node@$($script:PLAYWRIGHT_NODE_FALLBACK_VERSION)",
            "--package=$package",
            "--",
            "playwright-mcp"
        )
    } else {
        $launcherArgs = @("-y", $package)
    }

    if (-not $DryRun) {
        & npx @launcherArgs "--version" *> $null
        if ($LASTEXITCODE -ne 0) {
            Write-Warn "Playwright MCP startup check failed; not registering a broken server"
            $script:MCP_FAILED_SERVERS += "playwright"
            return
        }
    }

    Add-McpServer "playwright" (@("--", "npx") + $launcherArgs)
}

function Add-GithubMcpServer {
    if ([string]::IsNullOrWhiteSpace($env:GITHUB_PERSONAL_ACCESS_TOKEN)) {
        Write-Warn "GITHUB_PERSONAL_ACCESS_TOKEN is not set; skipping GitHub MCP server"
        $script:SKIPPED_COMPONENTS += "github MCP server (GITHUB_PERSONAL_ACCESS_TOKEN not set)"
        return
    }

    Add-McpServer "github" @(
        "--env", "GITHUB_PERSONAL_ACCESS_TOKEN=$($env:GITHUB_PERSONAL_ACCESS_TOKEN)",
        "--", "npx", "-y", "@modelcontextprotocol/server-github"
    )
}

function Write-McpResult {
    if ($script:MCP_FAILED_SERVERS.Count -eq 0) {
        Write-Ok "MCP setup complete (selected entries are refreshed)"
    } else {
        Write-Warn "MCP setup finished with failures: $($script:MCP_FAILED_SERVERS -join ', ')"
        $script:SKIPPED_COMPONENTS += "MCP servers: $($script:MCP_FAILED_SERVERS -join ', ')"
    }
}

function Install-SelectedMcp {
    Write-Info "Installing selected MCP servers..."

    if (-not (Get-Command "codex" -ErrorAction SilentlyContinue)) {
        Write-Warn "codex CLI not found. Skip MCP setup."
        $script:SKIPPED_COMPONENTS += "MCP servers (codex CLI not found)"
        return
    }

    if ($script:SelectMcpContext7) {
        Add-McpServer "context7" @("--", "npx", "-y", "@upstash/context7-mcp")
    }
    if ($script:SelectMcpGithub) {
        Add-GithubMcpServer
    }
    if ($script:SelectMcpPlaywright) {
        Add-PlaywrightMcpServer
    }
    if ($script:SelectMcpOpenaiDeveloperDocs) {
        Add-McpServer "openaiDeveloperDocs" @("--url", "https://developers.openai.com/mcp")
    }
    if ($script:SelectMcpLark) {
        Add-McpServer "lark-mcp" @("--", "npx", "-y", "@larksuiteoapi/lark-mcp", "mcp", "-a", "YOUR_APP_ID", "-s", "YOUR_APP_SECRET")
    }
    Write-McpResult
}

function Show-InteractiveMenu {
    Reset-InteractiveSelections

    if ([Console]::IsInputRedirected -or [Console]::IsOutputRedirected) {
        Write-Warn "No interactive console is available; falling back to non-interactive full install"
        $script:InteractiveMode = $false
        $script:All = $true
        $script:InteractiveSelectionHasAny = $true
        return
    }

    $groups = @(
        [pscustomobject]@{
            Label = "Core"
            Hint = ""
            Items = @(
                [pscustomobject]@{ Label = "AGENTS.md"; Description = "Global Codex instructions"; Default = $true;  StateVar = "SelectCoreAgentsMd" },
                [pscustomobject]@{ Label = "config.toml"; Description = "Codex runtime config template"; Default = $true; StateVar = "SelectCoreConfig" },
                [pscustomobject]@{ Label = "StatusLine"; Description = "Codex footer: model, reasoning, branch, context"; Default = $true; StateVar = "SelectCoreStatusLine" },
                [pscustomobject]@{ Label = "lessons.md"; Description = "Lessons source-of-truth"; Default = $true; StateVar = "SelectCoreLessons" }
                [pscustomobject]@{ Label = "explorer"; Description = "Code-path exploration agent"; Default = $true; StateVar = "SelectAgentExplorer" },
                [pscustomobject]@{ Label = "reviewer"; Description = "Review/regression agent"; Default = $true; StateVar = "SelectAgentReviewer" },
                [pscustomobject]@{ Label = "docs-researcher"; Description = "Docs/API verification agent"; Default = $true; StateVar = "SelectAgentDocsResearcher" }
            )
        },
        [pscustomobject]@{
            Label = "Review"
            Hint = "Claude parity; Codex-native where available"
            Items = @(
                [pscustomobject]@{ Label = "code-review"; Description = "PR code review skill or Codex /review fallback"; Default = $true; StateVar = "SelectSkillCodeReview" },
                [pscustomobject]@{ Label = "adversarial-review"; Description = "Cross-model adversarial review"; Default = $true; StateVar = "SelectSkillAdversarialReview" }
            )
        },
        [pscustomobject]@{
            Label = "Workflow"
            Hint = "planning, iteration, code quality, meta-config"
            Items = @(
                [pscustomobject]@{ Label = "andrej-karpathy-skills"; Description = "Karpathy coding guidelines"; Default = $true; StateVar = "SelectSkillKarpathy" },
                [pscustomobject]@{ Label = "superpowers"; Description = "Planning, brainstorming, TDD, debugging"; Default = $false; StateVar = "SelectSkillSuperpowers" },
                [pscustomobject]@{ Label = "mattpocock/skills"; Description = "Agent workflows via npx skills"; Default = $true; StateVar = "SelectSkillMattPocock" },
                [pscustomobject]@{ Label = "handoff"; Description = "Conversation handoff skill"; Default = $true; StateVar = "SelectSkillHandoff" },
                [pscustomobject]@{ Label = "update-config"; Description = "Update Codex config branch install"; Default = $true; StateVar = "SelectSkillUpdate" }
            )
        },
        [pscustomobject]@{
            Label = "Development Tools"
            Hint = "Codex MCP equivalents"
            Items = @(
                [pscustomobject]@{ Label = "context7"; Description = "Up-to-date library docs (MCP)"; Default = $true; StateVar = "SelectMcpContext7" },
                [pscustomobject]@{ Label = "github"; Description = "GitHub workflows (MCP; needs a real PAT)"; Default = $true; StateVar = "SelectMcpGithub" },
                [pscustomobject]@{ Label = "playwright"; Description = "Browser automation (MCP)"; Default = $true; StateVar = "SelectMcpPlaywright" },
                [pscustomobject]@{ Label = "openaiDeveloperDocs"; Description = "Official OpenAI docs MCP"; Default = $true; StateVar = "SelectMcpOpenaiDeveloperDocs" }
            )
        },
        [pscustomobject]@{
            Label = "Design & Content"
            Hint = "documents, UI, creative artifacts, humanization"
            Items = @(
                [pscustomobject]@{ Label = "document-skills"; Description = "PDF/DOCX/PPTX/XLSX skills pack"; Default = $true; StateVar = "SelectSkillDocumentSkills" },
                [pscustomobject]@{ Label = "example-skills"; Description = "Canvas/art/MCP builder skill pack"; Default = $true; StateVar = "SelectSkillExampleSkills" },
                [pscustomobject]@{ Label = "frontend-design"; Description = "Frontend UI design skill"; Default = $true; StateVar = "SelectSkillFrontendDesign" },
                [pscustomobject]@{ Label = "humanizer"; Description = "Remove AI writing patterns"; Default = $true; StateVar = "SelectSkillHumanizer" },
                [pscustomobject]@{ Label = "humanizer-zh"; Description = "Remove Chinese AI writing patterns"; Default = $false; StateVar = "SelectSkillHumanizerZh" }
            )
        },
        [pscustomobject]@{
            Label = "Lifestyle"
            Hint = "personal productivity"
            Items = @(
                [pscustomobject]@{ Label = "PUA"; Description = "Productivity coaching skills (CN / EN / JA)"; Default = $false; StateVar = "SelectSkillPUA" }
            )
        },
        [pscustomobject]@{
            Label = "Academic Research"
            Hint = "training/inference skills + paper-reading & DeepXiv"
            Items = @(
                [pscustomobject]@{ Label = "paper-reading"; Description = "Research paper summarization"; Default = $true; StateVar = "SelectSkillPaperReading" },
                [pscustomobject]@{ Label = "tokenization"; Description = "Tokenizer training and usage"; Default = $false; StateVar = "SelectAiTokenization" },
                [pscustomobject]@{ Label = "fine-tuning"; Description = "Fine-tuning workflows"; Default = $false; StateVar = "SelectAiFineTuning" },
                [pscustomobject]@{ Label = "post-training"; Description = "RLHF / DPO / GRPO workflows"; Default = $false; StateVar = "SelectAiPostTraining" },
                [pscustomobject]@{ Label = "distributed-training"; Description = "DeepSpeed / FSDP / Megatron / Ray"; Default = $false; StateVar = "SelectAiDistributedTraining" },
                [pscustomobject]@{ Label = "inference-serving"; Description = "vLLM / SGLang / TensorRT / llama.cpp"; Default = $false; StateVar = "SelectAiInferenceServing" },
                [pscustomobject]@{ Label = "optimization"; Description = "Quantization and optimization"; Default = $false; StateVar = "SelectAiOptimization" },
                [pscustomobject]@{ Label = "deepxiv"; Description = "DeepXiv research workflow skills"; Default = $false; StateVar = "SelectAiDeepXiv" }
            )
        },
        [pscustomobject]@{
            Label = "Slides"
            Hint = "AI slide / PPTX generation; default off"
            Items = @(
                [pscustomobject]@{ Label = "frontend-slides"; Description = "HTML slide generator with PPT conversion"; Default = $false; StateVar = "SelectSkillFrontendSlides" }
            )
        },
        [pscustomobject]@{
            Label = "MCP Servers"
            Hint = ""
            Items = @(
                [pscustomobject]@{ Label = "lark-mcp"; Description = "Feishu/Lark integration (needs credentials)"; Default = $false; StateVar = "SelectMcpLark" }
            )
        }
    )

    foreach ($group in $groups) {
        foreach ($item in $group.Items) {
            Set-Variable -Scope Script -Name $item.StateVar -Value $item.Default
        }
    }

    $cursor = 0
    $numGroups = $groups.Count

    function Get-GroupCount {
        param([object]$Group)
        $count = 0
        foreach ($item in $Group.Items) {
            if (Get-Variable -Scope Script -Name $item.StateVar -ValueOnly) { $count++ }
        }
        return $count
    }

    function Set-GroupState {
        param([object]$Group, [bool]$Value)
        foreach ($item in $Group.Items) {
            Set-Variable -Scope Script -Name $item.StateVar -Value $Value
        }
    }

    function Reset-GroupDefaults {
        param([object]$Group)
        foreach ($item in $Group.Items) {
            Set-Variable -Scope Script -Name $item.StateVar -Value $item.Default
        }
    }

    function Draw-MainMenu {
        Clear-Host
        Write-Host "========================================="
        Write-Host "  Codex Config Installer"
        Write-Host "  $(Get-SourceVersion)"
        Write-Host "========================================="
        Write-Host ""
        Write-Host "  Up/Down Navigate   Enter/Right Open   A All   N None   D Defaults   Q Quit"
        Write-Host ""

        for ($g = 0; $g -lt $numGroups; $g++) {
            $group = $groups[$g]
            $count = Get-GroupCount $group
            $total = $group.Items.Count
            $prefix = if ($g -eq $cursor) { ">" } else { " " }
            Write-Host ("{0} [{1}/{2}] {3}" -f $prefix, $count, $total, $group.Label)
        }

        Write-Host ""
        if ($cursor -eq $numGroups) {
            Write-Host "> [ Submit ]"
        } else {
            Write-Host "  [ Submit ]"
        }
    }

    function Draw-SubMenu {
        param([object]$Group, [int]$SubCursor)
        Clear-Host
        Write-Host "========================================="
        Write-Host "  $($Group.Label)"
        if ($Group.Hint) { Write-Host "  ($($Group.Hint))" }
        Write-Host "========================================="
        Write-Host ""
        Write-Host "  Up/Down Navigate   Space Toggle   Left/Esc/Enter Back"
        Write-Host "  A All   N None   D Defaults"
        Write-Host ""

        for ($i = 0; $i -lt $Group.Items.Count; $i++) {
            $item = $Group.Items[$i]
            $value = Get-Variable -Scope Script -Name $item.StateVar -ValueOnly
            $mark = if ($value) { "*" } else { " " }
            $prefix = if ($i -eq $SubCursor) { ">" } else { " " }
            Write-Host ("{0} [{1}] {2} - {3}" -f $prefix, $mark, $item.Label, $item.Description)
        }

        Write-Host ""
        if ($SubCursor -eq $Group.Items.Count) {
            Write-Host "> [ Back ]"
        } else {
            Write-Host "  [ Back ]"
        }
    }

    function Read-Key {
        $keyInfo = [Console]::ReadKey($true)
        switch ($keyInfo.Key) {
            'UpArrow' { return 'UP' }
            'DownArrow' { return 'DOWN' }
            'LeftArrow' { return 'LEFT' }
            'RightArrow' { return 'RIGHT' }
            'Enter' { return 'ENTER' }
            'Spacebar' { return 'SPACE' }
            'A' { return 'ALL' }
            'N' { return 'NONE' }
            'D' { return 'DEFAULT' }
            'Q' { return 'QUIT' }
            'Escape' { return 'ESC' }
            default { return 'OTHER' }
        }
    }

    while ($true) {
        Draw-MainMenu
        $key = Read-Key

        switch ($key) {
            'UP' {
                if ($cursor -gt 0) { $cursor-- }
            }
            'DOWN' {
                if ($cursor -lt $numGroups) { $cursor++ }
            }
            'ALL' {
                foreach ($group in $groups) { Set-GroupState $group $true }
            }
            'NONE' {
                foreach ($group in $groups) { Set-GroupState $group $false }
            }
            'DEFAULT' {
                foreach ($group in $groups) { Reset-GroupDefaults $group }
            }
            'QUIT' {
                Write-Host ""
                Write-Info "Cancelled."
                exit 0
            }
            'ENTER' {
                if ($cursor -eq $numGroups) { break }
                $group = $groups[$cursor]
                $subCursor = 0
                while ($true) {
                    Draw-SubMenu -Group $group -SubCursor $subCursor
                    $subKey = Read-Key
                    switch ($subKey) {
                        'UP' {
                            if ($subCursor -gt 0) { $subCursor-- }
                        }
                        'DOWN' {
                            if ($subCursor -lt $group.Items.Count) { $subCursor++ }
                        }
                        'SPACE' {
                            if ($subCursor -lt $group.Items.Count) {
                                $item = $group.Items[$subCursor]
                                $current = Get-Variable -Scope Script -Name $item.StateVar -ValueOnly
                                Set-Variable -Scope Script -Name $item.StateVar -Value (-not $current)
                            }
                        }
                        'ALL' {
                            Set-GroupState $group $true
                        }
                        'NONE' {
                            Set-GroupState $group $false
                        }
                        'DEFAULT' {
                            Reset-GroupDefaults $group
                        }
                        'LEFT' { break }
                        'ESC' { break }
                        'ENTER' {
                            if ($subCursor -eq $group.Items.Count) {
                                break
                            }
                            $item = $group.Items[$subCursor]
                            $current = Get-Variable -Scope Script -Name $item.StateVar -ValueOnly
                            Set-Variable -Scope Script -Name $item.StateVar -Value (-not $current)
                        }
                    }
                    if ($subKey -in @('LEFT', 'ESC')) { break }
                    if ($subKey -eq 'ENTER' -and $subCursor -eq $group.Items.Count) { break }
                }
            }
            'RIGHT' {
                if ($cursor -lt $numGroups) {
                    $group = $groups[$cursor]
                    $subCursor = 0
                    while ($true) {
                        Draw-SubMenu -Group $group -SubCursor $subCursor
                        $subKey = Read-Key
                        switch ($subKey) {
                            'UP' {
                                if ($subCursor -gt 0) { $subCursor-- }
                            }
                            'DOWN' {
                                if ($subCursor -lt $group.Items.Count) { $subCursor++ }
                            }
                            'SPACE' {
                                if ($subCursor -lt $group.Items.Count) {
                                    $item = $group.Items[$subCursor]
                                    $current = Get-Variable -Scope Script -Name $item.StateVar -ValueOnly
                                    Set-Variable -Scope Script -Name $item.StateVar -Value (-not $current)
                                }
                            }
                            'ALL' {
                                Set-GroupState $group $true
                            }
                            'NONE' {
                                Set-GroupState $group $false
                            }
                            'DEFAULT' {
                                Reset-GroupDefaults $group
                            }
                            'LEFT' { break }
                            'ESC' { break }
                            'ENTER' {
                                if ($subCursor -eq $group.Items.Count) {
                                    break
                                }
                                $item = $group.Items[$subCursor]
                                $current = Get-Variable -Scope Script -Name $item.StateVar -ValueOnly
                                Set-Variable -Scope Script -Name $item.StateVar -Value (-not $current)
                            }
                        }
                        if ($subKey -in @('LEFT', 'ESC')) { break }
                        if ($subKey -eq 'ENTER' -and $subCursor -eq $group.Items.Count) { break }
                    }
                }
            }
        }

        if ($cursor -eq $numGroups -and $key -eq 'ENTER') { break }
    }

    $coreSelected = $false
    $skillsSelected = $false
    $mcpSelected = $false

    foreach ($group in $groups) {
        foreach ($item in $group.Items) {
            $selected = [bool](Get-Variable -Scope Script -Name $item.StateVar -ValueOnly)
            switch ($item.StateVar) {
                'SelectCoreAgentsMd' { if ($selected) { $coreSelected = $true } }
                'SelectCoreConfig' { if ($selected) { $coreSelected = $true } }
                'SelectCoreStatusLine' { if ($selected) { $coreSelected = $true } }
                'SelectCoreLessons' { if ($selected) { $coreSelected = $true } }
                'SelectAgentExplorer' { if ($selected) { $coreSelected = $true } }
                'SelectAgentReviewer' { if ($selected) { $coreSelected = $true } }
                'SelectAgentDocsResearcher' { if ($selected) { $coreSelected = $true } }
                'SelectSkillCodeReview' { if ($selected) { $skillsSelected = $true } }
                'SelectSkillKarpathy' { if ($selected) { $skillsSelected = $true } }
                'SelectSkillSuperpowers' { if ($selected) { $skillsSelected = $true } }
                'SelectSkillMattPocock' { if ($selected) { $skillsSelected = $true } }
                'SelectSkillDocumentSkills' { if ($selected) { $skillsSelected = $true } }
                'SelectSkillExampleSkills' { if ($selected) { $skillsSelected = $true } }
                'SelectSkillFrontendDesign' { if ($selected) { $skillsSelected = $true } }
                'SelectSkillPaperReading' { if ($selected) { $skillsSelected = $true } }
                'SelectSkillHumanizer' { if ($selected) { $skillsSelected = $true } }
                'SelectSkillHumanizerZh' { if ($selected) { $skillsSelected = $true } }
                'SelectSkillHandoff' { if ($selected) { $skillsSelected = $true } }
                'SelectSkillAdversarialReview' { if ($selected) { $skillsSelected = $true } }
                'SelectSkillUpdate' { if ($selected) { $skillsSelected = $true } }
                'SelectSkillPUA' { if ($selected) { $skillsSelected = $true } }
                'SelectSkillFrontendSlides' { if ($selected) { $skillsSelected = $true } }
                'SelectAiTokenization' { if ($selected) { $skillsSelected = $true } }
                'SelectAiFineTuning' { if ($selected) { $skillsSelected = $true } }
                'SelectAiPostTraining' { if ($selected) { $skillsSelected = $true } }
                'SelectAiDistributedTraining' { if ($selected) { $skillsSelected = $true } }
                'SelectAiInferenceServing' { if ($selected) { $skillsSelected = $true } }
                'SelectAiOptimization' { if ($selected) { $skillsSelected = $true } }
                'SelectAiDeepXiv' { if ($selected) { $skillsSelected = $true } }
                'SelectMcpContext7' { if ($selected) { $mcpSelected = $true } }
                'SelectMcpGithub' { if ($selected) { $mcpSelected = $true } }
                'SelectMcpPlaywright' { if ($selected) { $mcpSelected = $true } }
                'SelectMcpOpenaiDeveloperDocs' { if ($selected) { $mcpSelected = $true } }
                'SelectMcpLark' { if ($selected) { $mcpSelected = $true } }
            }
        }
    }

    $script:InteractiveSelectionHasAny = ($coreSelected -or $skillsSelected -or $mcpSelected)
    if (-not $script:InteractiveSelectionHasAny) {
        Write-Info "No items selected. Existing installer-managed skills will be removed."
    }

    $script:InteractiveMode = $true
    $script:All = $false
    Set-Variable -Scope Script -Name Core -Value $coreSelected -Force
    Set-Variable -Scope Script -Name Skills -Value $skillsSelected -Force
    Set-Variable -Scope Script -Name Mcp -Value $mcpSelected -Force
}

# ============================================================
# Install functions
# ============================================================
function Install-Core {
    if ($InteractiveMode) {
        Install-SelectedCoreFiles
        Install-SelectedAgents
        return
    }

    Write-Info "Installing core files..."
    if (-not $DryRun) {
        New-Item -ItemType Directory -Path $CODEX_DIR -Force | Out-Null
    }

    Backup-IfExists (Join-Path $CODEX_DIR "AGENTS.md")
    Backup-IfExists (Join-Path $CODEX_DIR "agents")

    if ($DryRun) {
        Write-Info "Would copy: AGENTS.md  -> $CODEX_DIR\AGENTS.md"
        Write-Info "Would copy: agents\*.toml -> $CODEX_DIR\agents\"
    } else {
        Copy-Item (Join-Path $script:SCRIPT_DIR "AGENTS.md")  (Join-Path $CODEX_DIR "AGENTS.md")  -Force
        $agentsSrc = Join-Path $script:SCRIPT_DIR "agents"
        if (Test-Path $agentsSrc) {
            $agentsDst = Join-Path $CODEX_DIR "agents"
            New-Item -ItemType Directory -Path $agentsDst -Force | Out-Null
            Copy-Item (Join-Path $agentsSrc "*.toml") $agentsDst -Force
        }
        Write-Ok "AGENTS.md and agents installed"
    }

    Install-LessonsIfMissing

    $configDest = Join-Path $CODEX_DIR "config.toml"
    if (Test-Path $configDest) {
        Write-Warn "$configDest exists -- skipping (merge manually if needed)"
    } else {
        if ($DryRun) {
            Write-Info "Would copy: config.toml -> $configDest"
        } else {
            Copy-Item (Join-Path $script:SCRIPT_DIR "config.toml") $configDest -Force
            Write-Ok "config.toml installed"
        }
    }
    Ensure-StatusLineSetting
}

function Install-Mcp {
    if ($InteractiveMode) {
        Install-SelectedMcp
        return
    }

    Write-Info "Installing MCP servers..."

    if (-not (Get-Command "codex" -ErrorAction SilentlyContinue)) {
        Write-Warn "codex CLI not found. Skip MCP setup."
        $script:SKIPPED_COMPONENTS += "MCP servers (codex CLI not found)"
        return
    }

    Write-Info "Skipping lark-mcp: it requires real app credentials."
    Write-Info "Enable it via the interactive installer or 'codex mcp add' after filling credentials."
    Add-McpServer "context7" @("--", "npx", "-y", "@upstash/context7-mcp")
    Add-GithubMcpServer
    Add-PlaywrightMcpServer
    Add-McpServer "openaiDeveloperDocs" @("--url", "https://developers.openai.com/mcp")
    Write-McpResult
}

function Get-SkillNameFromPath {
    param([string]$Path)
    return (Split-Path $Path -Leaf)
}

function Test-SkillInList {
    param([string]$Skill, [string[]]$Skills)
    foreach ($candidate in $Skills) {
        if ($candidate -ceq $Skill) { return $true }
    }
    return $false
}

function Test-ManagedSkillName {
    param([string]$Skill)
    return (Test-SkillInList $Skill $OWNERSHIP_SKILLS)
}

function Get-ExpectedSkillSource {
    param([string]$Skill)

    if ($Skill -ceq "code-review" -or (Test-SkillInList $Skill $MATTPOCOCK_SKILLS)) {
        return "mattpocock/skills"
    }
    if ($Skill -ceq "karpathy-guidelines") {
        return "forrestchang/andrej-karpathy-skills"
    }
    if (Test-SkillInList $Skill $SUPERPOWERS_SKILLS) {
        return "obra/superpowers"
    }
    if ($Skill -cmatch '^(frontend-design|pdf|docx|pptx|xlsx|canvas-design|algorithmic-art|mcp-builder)$') {
        return "anthropics/skills"
    }
    if (Test-SkillInList $Skill $PUA_SKILLS) {
        return "tanweai/pua"
    }
    if ($Skill -ceq "frontend-slides") {
        return "zarazhangrui/frontend-slides"
    }
    if ($Skill -cmatch '^(huggingface-tokenizers|sentencepiece|axolotl|llama-factory|peft|unsloth|grpo-rl-training|openrlhf|simpo|trl-fine-tuning|verl|deepspeed|pytorch-fsdp2|megatron-core|ray-train|awq|gptq|gguf|flash-attention|bitsandbytes|vllm|sglang|tensorrt-llm|llama-cpp)$') {
        return "zechenzhangAGI/AI-research-SKILLs"
    }
    if ($Skill -cmatch '^(deepxiv-cli|deepxiv-baseline-table|deepxiv-trending-digest)$') {
        return "DeepXiv/deepxiv_sdk"
    }
    if (Test-SkillInList $Skill $LEGACY_CLEANUP_SKILLS) {
        return "affaan-m/everything-claude-code"
    }
    if (Test-SkillInList $Skill $LOCAL_MANAGED_SKILLS) {
        return "local:$Skill"
    }
    return $null
}

function Test-DirectoryTreeEqual {
    param([string]$Source, [string]$Target)
    if (-not (Test-Path -LiteralPath $Source -PathType Container) -or
        -not (Test-Path -LiteralPath $Target -PathType Container)) {
        return $false
    }

    $trimChars = [char[]]@([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    $sourceRoot = (Resolve-Path -LiteralPath $Source).Path.TrimEnd($trimChars)
    $targetRoot = (Resolve-Path -LiteralPath $Target).Path.TrimEnd($trimChars)
    $sourceFiles = @(Get-ChildItem -LiteralPath $sourceRoot -Recurse -File | Sort-Object FullName)
    $targetFiles = @(Get-ChildItem -LiteralPath $targetRoot -Recurse -File | Sort-Object FullName)
    if ($sourceFiles.Count -ne $targetFiles.Count) { return $false }

    $targetByRelativePath = @{}
    foreach ($file in $targetFiles) {
        $relative = $file.FullName.Substring($targetRoot.Length).TrimStart($trimChars)
        $targetByRelativePath[$relative] = $file.FullName
    }
    foreach ($file in $sourceFiles) {
        $relative = $file.FullName.Substring($sourceRoot.Length).TrimStart($trimChars)
        if (-not $targetByRelativePath.ContainsKey($relative)) { return $false }
        $sourceHash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
        $targetHash = (Get-FileHash -LiteralPath $targetByRelativePath[$relative] -Algorithm SHA256).Hash
        if ($sourceHash -cne $targetHash) { return $false }
    }
    return $true
}

function Test-SuperpowersFallbackOwned {
    $gitConfig = Join-Path $SUPERPOWERS_DIR ".git/config"
    if (-not (Test-Path -LiteralPath $gitConfig -PathType Leaf)) { return $false }

    $remote = $null
    if (Get-Command "git" -ErrorAction SilentlyContinue) {
        $remote = (& git config --file $gitConfig --get remote.origin.url 2>$null | Select-Object -First 1)
    }
    if (-not $remote) {
        $configText = Get-Content -LiteralPath $gitConfig -Raw
        $match = [regex]::Match($configText, '(?ims)^\[remote\s+"origin"\]\s*$.*?^\s*url\s*=\s*(?<url>[^\r\n]+)')
        if ($match.Success) { $remote = $match.Groups['url'].Value.Trim() }
    }

    return $remote -cin @(
        "https://github.com/obra/superpowers",
        "https://github.com/obra/superpowers.git",
        "git@github.com:obra/superpowers.git",
        "git://github.com/obra/superpowers.git"
    )
}

function Test-SuperpowersOwnershipRecorded {
    foreach ($skill in $SUPERPOWERS_SKILLS) {
        if ($script:OwnedManagedSkills.Contains($skill)) { return $true }
    }
    return $false
}

function Save-ManagedSkillOwnership {
    if ($DryRun) { return }
    $tempState = "$MANAGED_SKILLS_STATE_FILE.tmp.$PID"
    try {
        New-Item -ItemType Directory -Path $CODEX_DIR -Force | Out-Null
        $lines = @()
        foreach ($skill in $OWNERSHIP_SKILLS) {
            if ($script:OwnedManagedSkills.Contains($skill)) { $lines += $skill }
        }
        $encoding = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllLines($tempState, [string[]]$lines, $encoding)
        Move-Item -LiteralPath $tempState -Destination $MANAGED_SKILLS_STATE_FILE -Force
    } catch {
        Remove-Item -LiteralPath $tempState -Force -ErrorAction SilentlyContinue
        Write-Warn "Could not save managed skill ownership to ${MANAGED_SKILLS_STATE_FILE}: $($_.Exception.Message)"
        $script:SKIPPED_COMPONENTS += "managed skill ownership state (write failed)"
    }
}

function Initialize-ManagedSkillOwnership {
    if ($script:ManagedSkillOwnershipLoaded) { return }
    $script:OwnedManagedSkills = New-Object 'System.Collections.Generic.HashSet[string]'

    if (Test-Path -LiteralPath $MANAGED_SKILLS_STATE_FILE -PathType Leaf) {
        foreach ($recorded in @(Get-Content -LiteralPath $MANAGED_SKILLS_STATE_FILE)) {
            if ((Test-ManagedSkillName $recorded)) {
                [void]$script:OwnedManagedSkills.Add($recorded)
            }
        }
        $script:ManagedSkillOwnershipLoaded = $true
        return
    }

    foreach ($skill in $LOCAL_MANAGED_SKILLS) {
        $source = Join-Path $script:SCRIPT_DIR "skills/$skill"
        $target = Join-Path $CODEX_DIR "skills/$skill"
        if (Test-DirectoryTreeEqual $source $target) {
            [void]$script:OwnedManagedSkills.Add($skill)
        }
    }

    if (Test-Path -LiteralPath $GLOBAL_SKILL_LOCK_FILE -PathType Leaf) {
        try {
            $lock = Get-Content -LiteralPath $GLOBAL_SKILL_LOCK_FILE -Raw | ConvertFrom-Json
            foreach ($property in @($lock.skills.PSObject.Properties)) {
                $name = $property.Name
                $source = $property.Value.source
                $expected = Get-ExpectedSkillSource $name
                $canonicalPath = Join-Path $AGENTS_SKILLS_DIR $name
                $codexPath = Join-Path $CODEX_DIR "skills/$name"
                if ((Test-ManagedSkillName $name) -and $expected -and
                    -not $expected.StartsWith("local:") -and $source -ceq $expected -and
                    (Test-DirectoryTreeEqual $canonicalPath $codexPath)) {
                    [void]$script:OwnedManagedSkills.Add($name)
                }
            }
        } catch {
            Write-Warn "Could not parse $GLOBAL_SKILL_LOCK_FILE; preserving untracked legacy skills"
        }
    }

    if (Test-SuperpowersFallbackOwned) {
        foreach ($skill in $SUPERPOWERS_SKILLS) {
            [void]$script:OwnedManagedSkills.Add($skill)
        }
    }

    $script:ManagedSkillOwnershipLoaded = $true
    Save-ManagedSkillOwnership
}

function Add-ManagedSkillOwnership {
    param([string[]]$SkillNames)
    Initialize-ManagedSkillOwnership
    foreach ($skill in $SkillNames) {
        if (Test-ManagedSkillName $skill) {
            [void]$script:OwnedManagedSkills.Add($skill)
        }
    }
    Save-ManagedSkillOwnership
}

function Remove-ManagedSkillOwnership {
    param([string[]]$SkillNames)
    Initialize-ManagedSkillOwnership
    foreach ($skill in $SkillNames) {
        [void]$script:OwnedManagedSkills.Remove($skill)
    }
    Save-ManagedSkillOwnership
}

function Confirm-EmptySkillRemoval {
    param([int]$Count)
    if ($Force) { return $true }
    if ([Console]::IsInputRedirected) {
        Write-Warn "Cannot confirm removal without an interactive console; preserving existing managed skills"
        return $false
    }
    return (Confirm-Action "Remove $Count previously installer-managed skill(s)?")
}

function Install-NpxSkillNames {
    param([string]$Repo, [string[]]$SkillNames)

    if ($DryRun) {
        Write-Info "Would install via npx skills: ${Repo} -> $($SkillNames -join ', ')"
        return $true
    }

    if (-not (Get-Command "npx" -ErrorAction SilentlyContinue)) {
        return $false
    }

    $npxArgs = @("-y", "skills@latest", "add", $Repo, "--global", "--agent", "codex", "--copy", "--yes", "--full-depth")
    foreach ($skill in $SkillNames) {
        $npxArgs += @("--skill", $skill)
    }

    $oldDoNotTrack = $env:DO_NOT_TRACK
    $env:DO_NOT_TRACK = "1"
    try {
        & npx @npxArgs 2>&1 | ForEach-Object { Write-Host $_ }
        $exitCode = $LASTEXITCODE
        if ($exitCode -eq 0) {
            Add-ManagedSkillOwnership $SkillNames
            return $true
        }
        return $false
    } finally {
        if ($null -eq $oldDoNotTrack) {
            Remove-Item Env:DO_NOT_TRACK -ErrorAction SilentlyContinue
        } else {
            $env:DO_NOT_TRACK = $oldDoNotTrack
        }
    }
}

function Get-SelectedManagedSkills {
    $selected = New-Object 'System.Collections.Generic.HashSet[string]'

    function Add-Names {
        param([bool]$Enabled, [string[]]$Names)
        if ($Enabled) {
            foreach ($name in $Names) {
                [void]$selected.Add($name)
            }
        }
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

function Remove-NpxSkillNames {
    param([string[]]$SkillNames)
    if ($SkillNames.Count -eq 0) { return }

    if ($DryRun) {
        Write-Info "Would remove via npx skills for Codex: $($SkillNames -join ', ')"
        return
    }

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
        if ($null -eq $oldDoNotTrack) {
            Remove-Item Env:DO_NOT_TRACK -ErrorAction SilentlyContinue
        } else {
            $env:DO_NOT_TRACK = $oldDoNotTrack
        }
    }
}

function Remove-SuperpowersFallback {
    if (-not (Test-SuperpowersFallbackOwned)) {
        if ((Test-Path $SUPERPOWERS_LINK) -or (Test-Path $SUPERPOWERS_DIR)) {
            Write-Warn "Preserving unrecognized superpowers fallback paths; expected obra/superpowers provenance"
            $script:SKIPPED_COMPONENTS += "superpowers fallback cleanup (ownership could not be verified)"
        }
        return
    }

    $linkItem = Get-Item -LiteralPath $SUPERPOWERS_LINK -Force -ErrorAction SilentlyContinue
    if ($DryRun) {
        if ($linkItem) {
            Write-Info "Would remove superpowers link: $SUPERPOWERS_LINK"
        }
        if (Test-Path $SUPERPOWERS_DIR) {
            Write-Info "Would remove superpowers repository: $SUPERPOWERS_DIR"
        }
        return
    }

    if ($linkItem) {
        $isReparsePoint = ($linkItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0
        if ($isReparsePoint) {
            cmd /c rmdir "$SUPERPOWERS_LINK" | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Ok "Removed superpowers link"
            } else {
                Write-Warn "Failed to remove superpowers junction: $SUPERPOWERS_LINK"
                $script:SKIPPED_COMPONENTS += "superpowers link cleanup (rmdir failed)"
            }
        } else {
            Write-Warn "$SUPERPOWERS_LINK is not a junction/symlink; preserving it"
            $script:SKIPPED_COMPONENTS += "superpowers link cleanup ($SUPERPOWERS_LINK is not a junction/symlink)"
        }
    }

    if (Test-Path $SUPERPOWERS_DIR) {
        Remove-Item -Recurse -Force $SUPERPOWERS_DIR
        Write-Ok "Removed superpowers repository"
    }
}

function Sync-InteractiveSkills {
    $desired = @(Get-SelectedManagedSkills)
    $stale = @()

    Initialize-ManagedSkillOwnership

    foreach ($skill in @($script:OwnedManagedSkills)) {
        if ($desired -contains $skill) { continue }
        $stale += $skill
    }

    if ($stale.Count -gt 0) {
        if ($desired.Count -eq 0 -and -not $DryRun) {
            if (-not (Confirm-EmptySkillRemoval $stale.Count)) {
                Write-Info "Managed skill removal cancelled; existing managed skills were preserved"
                return
            }
        }

        $installedStale = @()
        foreach ($skill in $stale) {
            $codexPath = Join-Path $CODEX_DIR "skills/$skill"
            if (Test-Path $codexPath) { $installedStale += $skill }
        }
        if ($installedStale.Count -gt 0) {
            Remove-NpxSkillNames $installedStale
        }

        foreach ($skill in $stale) {
            $codexPath = Join-Path $CODEX_DIR "skills/$skill"
            if ($DryRun) {
                if (Test-Path $codexPath) {
                    Write-Info "Would remove unselected managed skill: $codexPath"
                }
            } elseif (Test-Path $codexPath) {
                Remove-Item -Recurse -Force $codexPath
                Write-Ok "Removed unselected managed skill: $skill"
            }
        }
    }

    if (-not $script:SelectSkillSuperpowers -and (Test-SuperpowersOwnershipRecorded)) {
        Remove-SuperpowersFallback
    }

    if ($stale.Count -gt 0 -and -not $DryRun) {
        Remove-ManagedSkillOwnership $stale
    }
}

function Install-SkillPathsFallback {
    param([string]$Repo, [string[]]$Paths)

    if (-not (Test-Path $INSTALLER)) {
        Write-Warn "skill-installer not found at $INSTALLER"
        $script:SKIPPED_COMPONENTS += "skill pack from $Repo (no npx and fallback installer not found)"
        return
    }

    $py = Resolve-PythonCommand
    if (-not $py) {
        Write-Warn "No usable Python 3 found. Install Python 3 or set PYTHON to a working interpreter."
        $script:SKIPPED_COMPONENTS += "skill pack from $Repo (Python 3 not found)"
        return
    }

    $exe = $py[0]
    $pyArgs = @()
    if ($py.Count -gt 1) {
        $pyArgs = $py[1..($py.Count - 1)]
    }
    & $exe @pyArgs $INSTALLER --repo $Repo --path @Paths
    if ($LASTEXITCODE -ne 0) {
        Write-Warn "Skill install from $Repo returned non-zero (possibly already installed)"
        $script:SKIPPED_COMPONENTS += "skill pack from $Repo (fallback installer returned non-zero)"
        return
    }
    $installedNames = @()
    foreach ($path in $Paths) {
        $installedNames += Get-SkillNameFromPath $path
    }
    Add-ManagedSkillOwnership $installedNames
}

function Install-SkillPaths {
    param([string]$Repo, [string[]]$Paths)

    $names = @()
    foreach ($path in $Paths) {
        $names += Get-SkillNameFromPath $path
    }

    if ($DryRun) {
        Write-Info "Would install via npx skills: ${Repo} -> $($names -join ', ')"
        Write-Info "Fallback if npx fails: install-skill-from-github.py ${Repo} -> $($Paths -join ', ')"
        return
    }

    if (Install-NpxSkillNames $Repo $names) {
        Write-Ok "Installed skills via npx: $($names -join ', ') ($Repo)"
        return
    }

    Write-Warn "npx skills install failed or npx is unavailable; trying Python fallback for $Repo"
    Install-SkillPathsFallback $Repo $Paths
}

function Reinstall-SkillPaths {
    param([string]$Repo, [string[]]$Paths)

    foreach ($path in $Paths) {
        $skill = Split-Path $path -Leaf
        $dest = Join-Path $CODEX_DIR "skills/$skill"
        if ($DryRun) {
            Write-Info "Would remove existing skill before reinstall: $dest"
        } elseif (Test-Path $dest) {
            Remove-Item -Recurse -Force $dest
            Write-Ok "Removed existing skill before reinstall: $skill"
        }
    }

    if ($DryRun) {
        $names = @()
        foreach ($path in $Paths) {
            $names += Get-SkillNameFromPath $path
        }
        Write-Info "Would reinstall via npx skills: ${Repo} -> $($names -join ', ')"
        Write-Info "Fallback if npx fails: install-skill-from-github.py ${Repo} -> $($Paths -join ', ')"
        return
    }

    Install-SkillPaths $Repo $Paths
}

function Remove-LegacySuperPowersSkills {
    $removed = $false
    foreach ($skill in $LEGACY_SUPERPOWERS_SKILLS) {
        $p = Join-Path $CODEX_DIR "skills/$skill"
        if (Test-Path $p) {
            Remove-Item -Recurse -Force $p
            $removed = $true
            Write-Ok "Removed legacy superpowers skill copy: $skill"
        }
    }
    if (-not $removed) {
        Write-Info "No legacy superpowers skill copies found under $CODEX_DIR\skills"
    }
}

function Skip-UnsupportedItem {
    param([string]$Item, [string]$Reason)
    Write-Warn "$Item is listed for category parity with the Claude installer but is not installed automatically for Codex: $Reason"
    $script:SKIPPED_COMPONENTS += "$Item ($Reason)"
}

function Install-Superpowers {
    Write-Info "Installing superpowers skill set..."

    if ($DryRun) {
        Write-Info "Would install via npx skills: obra/superpowers -> all listed superpowers skills"
        Write-Info "Fallback if npx fails: clone/update $SUPERPOWERS_REPO_URL -> $SUPERPOWERS_DIR and link $SUPERPOWERS_LINK"
        Write-Info "Would remove legacy copied superpowers skills from $CODEX_DIR\skills"
        return
    }

    if (Install-NpxSkillNames "obra/superpowers" $SUPERPOWERS_SKILLS) {
        Write-Ok "Installed superpowers via npx skills"
        Remove-LegacySuperPowersSkills
        return
    }

    Write-Warn "npx skills install failed or npx is unavailable; falling back to git clone/junction for superpowers"

    if (-not (Get-Command "git" -ErrorAction SilentlyContinue)) {
        Write-Warn "git not found. Skip full superpowers install."
        $script:SKIPPED_COMPONENTS += "superpowers skill set (git not found)"
        return
    }

    $gitDir = Join-Path $SUPERPOWERS_DIR ".git"
    if (Test-Path $gitDir) {
        Push-Location $SUPERPOWERS_DIR
        try {
            git pull --ff-only
            if ($LASTEXITCODE -ne 0) {
                Write-Warn "Failed to update existing superpowers repo at $SUPERPOWERS_DIR"
            }
        } finally {
            Pop-Location
        }
    } elseif (Test-Path $SUPERPOWERS_DIR) {
        Write-Warn "$SUPERPOWERS_DIR exists but is not a git repo -- skipping full superpowers install"
        $script:SKIPPED_COMPONENTS += "superpowers skill set ($SUPERPOWERS_DIR is not a git repo)"
        return
    } else {
        git clone $SUPERPOWERS_REPO_URL $SUPERPOWERS_DIR
        if ($LASTEXITCODE -ne 0) {
            Write-Warn "Failed to clone superpowers repo"
            $script:SKIPPED_COMPONENTS += "superpowers skill set (clone failed)"
            return
        }
        Write-Ok "Cloned superpowers repo to $SUPERPOWERS_DIR"
    }

    New-Item -ItemType Directory -Path $AGENTS_SKILLS_DIR -Force | Out-Null

    $superPowersSkillsDir = Join-Path $SUPERPOWERS_DIR "skills"

    if (Test-Path $SUPERPOWERS_LINK) {
        $item = Get-Item $SUPERPOWERS_LINK -Force
        $isReparsePoint = ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0
        if (-not $isReparsePoint) {
            Write-Warn "$SUPERPOWERS_LINK exists and is not a junction/symlink -- skipping link creation"
            $script:SKIPPED_COMPONENTS += "superpowers skills link ($SUPERPOWERS_LINK is not a junction/symlink)"
            return
        }
        # Remove existing reparse point before recreating
        cmd /c rmdir "$SUPERPOWERS_LINK" | Out-Null
    }

    # Use junction (no admin required, unlike directory symlinks on Windows)
    cmd /c mklink /j "$SUPERPOWERS_LINK" "$superPowersSkillsDir" | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Warn "Failed to create junction at $SUPERPOWERS_LINK"
        $script:SKIPPED_COMPONENTS += "superpowers skills link (junction creation failed)"
    } else {
        Add-ManagedSkillOwnership $SUPERPOWERS_SKILLS
        Write-Ok "Linked superpowers skills into $SUPERPOWERS_LINK"
    }

    Remove-LegacySuperPowersSkills
}

function Install-LocalSkills {
    $skillsDir = Join-Path $script:SCRIPT_DIR "skills"
    if (-not (Test-Path $skillsDir)) { return }

    Get-ChildItem -Path $skillsDir -Directory | ForEach-Object {
        $skill = $_.Name
        $dest  = Join-Path $CODEX_DIR "skills/$skill"
        if ($DryRun) {
            Write-Info "Would copy: skills/$skill/ -> $dest/"
        } else {
            New-Item -ItemType Directory -Path (Join-Path $CODEX_DIR "skills") -Force | Out-Null
            if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
            Copy-Item -Recurse $_.FullName $dest
            Add-ManagedSkillOwnership @($skill)
            Write-Ok "Installed local skill: $skill"
        }
    }
}

function Install-Skills {
    if ($InteractiveMode) {
        Write-Info "Installing selected skills..."
        Install-SelectedRecommendedSkills
        Install-SelectedAiSkills

        if (@(Get-SelectedManagedSkills).Count -gt 0) {
            Write-Ok "Selected skills processed"
        } else {
            Write-Info "No selected skills to install"
        }
        return
    }

    Write-Info "Installing skills (group: $SkillGroup)..."

    if ($SkillGroup -eq "core" -or $SkillGroup -eq "all") {
        if (-not (Install-NpxSkillNames "mattpocock/skills" @("code-review"))) {
            Skip-UnsupportedItem "code-review" "npx skills install failed; use Codex /review as the native fallback"
        }

        if (-not (Install-NpxSkillNames "forrestchang/andrej-karpathy-skills" @("karpathy-guidelines"))) {
            Skip-UnsupportedItem "andrej-karpathy-skills" "npx skills install failed"
        }

        Install-Superpowers

        if (Install-NpxSkillNames "mattpocock/skills" $MATTPOCOCK_SKILLS) {
            $script:MattPocockQuickstartReady = $true
        } else {
            Skip-UnsupportedItem "mattpocock/skills" "npx skills install failed"
        }

        Install-SkillPaths "anthropics/skills" @(
            "skills/frontend-design", "skills/pdf", "skills/docx", "skills/pptx", "skills/xlsx",
            "skills/canvas-design", "skills/algorithmic-art", "skills/mcp-builder"
        )

        Install-LocalSkills
    }

    if ($SkillGroup -eq "all") {
        if (-not (Install-NpxSkillNames "zarazhangrui/frontend-slides" @("frontend-slides"))) {
            Skip-UnsupportedItem "frontend-slides" "npx skills install failed"
        }
    }

    if ($SkillGroup -eq "ai-research" -or $SkillGroup -eq "all") {
        Install-SkillPaths "zechenzhangAGI/AI-research-SKILLs" @(
            "02-tokenization/huggingface-tokenizers", "02-tokenization/sentencepiece",
            "03-fine-tuning/axolotl", "03-fine-tuning/llama-factory", "03-fine-tuning/peft", "03-fine-tuning/unsloth",
            "06-post-training/grpo-rl-training", "06-post-training/openrlhf", "06-post-training/simpo",
            "06-post-training/trl-fine-tuning", "06-post-training/verl",
            "08-distributed-training/deepspeed", "08-distributed-training/pytorch-fsdp2",
            "08-distributed-training/megatron-core", "08-distributed-training/ray-train",
            "10-optimization/awq", "10-optimization/gptq", "10-optimization/gguf",
            "10-optimization/flash-attention", "10-optimization/bitsandbytes",
            "12-inference-serving/vllm", "12-inference-serving/sglang",
            "12-inference-serving/tensorrt-llm", "12-inference-serving/llama-cpp"
        )

        # DeepXiv is grouped under "Academic Research" in the README and the
        # interactive menu; keep the non-interactive groups consistent with that.
        Reinstall-SkillPaths "DeepXiv/deepxiv_sdk" @(
            "skills/deepxiv-cli", "skills/deepxiv-baseline-table", "skills/deepxiv-trending-digest"
        )
    }
}

# ============================================================
# Uninstall
# ============================================================
function Invoke-Uninstall {
    # Determine components: if -Core/-Mcp/-Skills flags are set alongside -Uninstall,
    # use those; otherwise uninstall everything.
    $components = @()
    if ($Core)   { $components += "core" }
    if ($Mcp)    { $components += "mcp" }
    if ($Skills) { $components += "skills" }
    if ($components.Count -eq 0) { $components = @("core", "mcp", "skills") }

    Write-Host ""
    Write-Warn "The following will be removed:"
    foreach ($comp in $components) {
        switch ($comp) {
            "core" {
                Write-Host "  - $CODEX_DIR\AGENTS.md"
                Write-Host "  - $CODEX_DIR\lessons.md (backed up first -- it holds your accumulated corrections)"
                Write-Host "  - $CODEX_DIR\config.toml"
                Write-Host "  - $CODEX_DIR\agents\*"
            }
            "mcp" {
                Write-Host "  - MCP servers: lark-mcp, context7, github, playwright, openaiDeveloperDocs"
            }
            "skills" {
                Write-Host "  - Managed skills under $CODEX_DIR\skills"
                Write-Host "  - $MANAGED_SKILLS_STATE_FILE"
                Write-Host "  - $SUPERPOWERS_DIR"
                Write-Host "  - $SUPERPOWERS_LINK"
            }
        }
    }
    if (Test-Path $VERSION_STAMP_FILE) {
        Write-Host "  - $VERSION_STAMP_FILE"
    }
    if (Test-Path $LEGACY_VERSION_STAMP_FILE) {
        Write-Host "  - $LEGACY_VERSION_STAMP_FILE"
    }
    Write-Host ""

    if ($DryRun) {
        Write-Warn "DRY RUN -- nothing will be removed"
        return
    }

    if (-not (Confirm-Action "Proceed with uninstall?")) {
        Write-Info "Cancelled."
        return
    }

    foreach ($comp in $components) {
        switch ($comp) {
            "core" {
                # lessons.md holds the user's accumulated corrections; keep a
                # backup next to it so an uninstall is never silent data loss.
                Backup-IfExists (Join-Path $CODEX_DIR "lessons.md")
                Remove-Item -Force (Join-Path $CODEX_DIR "AGENTS.md")  -ErrorAction SilentlyContinue
                Remove-Item -Force (Join-Path $CODEX_DIR "lessons.md") -ErrorAction SilentlyContinue
                Remove-Item -Force (Join-Path $CODEX_DIR "config.toml") -ErrorAction SilentlyContinue
                Remove-Item -Recurse -Force (Join-Path $CODEX_DIR "agents") -ErrorAction SilentlyContinue
                Write-Ok "Removed core files"
            }
            "mcp" {
                if (Get-Command "codex" -ErrorAction SilentlyContinue) {
                    codex mcp remove lark-mcp          2>$null; $true
                    codex mcp remove context7           2>$null; $true
                    codex mcp remove github             2>$null; $true
                    codex mcp remove playwright         2>$null; $true
                    codex mcp remove openaiDeveloperDocs 2>$null; $true
                    Write-Ok "Removed MCP entries (if present)"
                } else {
                    Write-Warn "codex CLI not found -- skip MCP removal"
                }
            }
            "skills" {
                foreach ($skill in $MANAGED_SKILLS) {
                    Remove-Item -Recurse -Force (Join-Path $CODEX_DIR "skills/$skill") -ErrorAction SilentlyContinue
                }
                if (Test-Path $SUPERPOWERS_LINK) {
                    $item = Get-Item $SUPERPOWERS_LINK -Force
                    $isReparsePoint = ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0
                    if ($isReparsePoint) {
                        cmd /c rmdir "$SUPERPOWERS_LINK" | Out-Null
                    } else {
                        Remove-Item -Force $SUPERPOWERS_LINK -ErrorAction SilentlyContinue
                    }
                }
                Remove-Item -Recurse -Force $SUPERPOWERS_DIR -ErrorAction SilentlyContinue
                Remove-Item -Force $MANAGED_SKILLS_STATE_FILE -ErrorAction SilentlyContinue
                Write-Ok "Removed managed skills"
            }
        }
    }

    Remove-Item -Force $VERSION_STAMP_FILE -ErrorAction SilentlyContinue
    Remove-Item -Force $LEGACY_VERSION_STAMP_FILE -ErrorAction SilentlyContinue
    Write-Ok "Uninstall complete"
}

# ============================================================
# Main
# ============================================================
try {
    if ($Help) {
        Show-Usage
        exit 0
    }

    # Uninstall only touches local state and -Help exits above; neither needs
    # the source archive, so only enter remote download mode after them.
    if ($Uninstall) {
        Invoke-Uninstall
        exit 0
    }

    Detect-ScriptDir

    if ($Version) {
        Show-Version
        exit 0
    }

    $hasExplicitInstallMode = $All -or $Core -or $Mcp -or $Skills
    if (-not $hasExplicitInstallMode -and $DryRun) {
        Write-Info "DRY RUN without component flags -> previewing full install non-interactively"
        $script:All = $true
    } elseif (-not $hasExplicitInstallMode) {
        $script:InteractiveMode = $true
        Show-InteractiveMenu
        if ($script:InteractiveMode) {
            Sync-InteractiveSkills
        }
    }

    Write-Host ""
    Write-Host "========================================="
    Write-Host "  Codex Config Installer"
    Write-Host "  $(Get-SourceVersion)"
    Write-Host "========================================="
    Write-Host ""

    if ($DryRun) {
        Write-Warn "DRY RUN MODE -- no changes will be made"
        Write-Host ""
    }

    if (-not $DryRun) {
        New-Item -ItemType Directory -Path $CODEX_DIR -Force | Out-Null
    }

    if ($All) {
        Install-Core
        Install-Mcp
        Install-Skills
    } else {
        if ($Core)   { Install-Core }
        if ($Mcp)    { Install-Mcp }
        if ($Skills) { Install-Skills }
    }

    Set-VersionStamp

    if ($script:SKIPPED_COMPONENTS.Count -gt 0) {
        Write-Host ""
        Write-Warn "Install finished, but some components were skipped:"
        foreach ($comp in $script:SKIPPED_COMPONENTS) {
            Write-Warn "  - $comp"
        }
        Write-Warn "Resolve the issues above and re-run the installer to complete them."
    }

    Show-MattPocockQuickstart
    Write-Ok "Done. Restart Codex to load new skills/config if needed."
} finally {
    Remove-TempDir
}
