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
  Skip uninstall confirmation

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
$script:SelectAgentExplorer = $true
$script:SelectAgentReviewer = $true
$script:SelectAgentDocsResearcher = $true
$script:SelectSkillSuperpowers = $true
$script:SelectSkillDocumentSkills = $true
$script:SelectSkillExampleSkills = $true
$script:SelectSkillCodingFoundations = $true
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
$script:SelectMcpGithub = $false
$script:SelectMcpPlaywright = $true
$script:SelectMcpOpenaiDeveloperDocs = $true
$script:SelectMcpLark = $false

$MANAGED_SKILLS = @(
    "frontend-design", "pdf", "docx", "pptx", "xlsx", "canvas-design", "algorithmic-art", "mcp-builder",
    "python-patterns", "python-testing", "golang-patterns", "golang-testing", "frontend-patterns",
    "security-review", "tdd-workflow", "verification-loop", "api-design", "database-migrations",
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
    "deepxiv-trending-digest"
)

$LEGACY_SUPERPOWERS_SKILLS = @(
    "using-superpowers",
    "systematic-debugging",
    "writing-plans",
    "test-driven-development"
)

# ============================================================
# Output helpers
# ============================================================
function Write-Info  { param($msg) Write-Host "[INFO]  $msg" -ForegroundColor Cyan }
function Write-Ok    { param($msg) Write-Host "[OK]    $msg" -ForegroundColor Green }
function Write-Warn  { param($msg) Write-Host "[WARN]  $msg" -ForegroundColor Yellow }
function Write-Err   { param($msg) Write-Host "[ERROR] $msg" -ForegroundColor Red }

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
  -Force                     Skip uninstall confirmation
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
    $script:SelectAgentExplorer = $true
    $script:SelectAgentReviewer = $true
    $script:SelectAgentDocsResearcher = $true
    $script:SelectSkillSuperpowers = $true
    $script:SelectSkillDocumentSkills = $true
    $script:SelectSkillExampleSkills = $true
    $script:SelectSkillCodingFoundations = $true
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
    $script:SelectMcpGithub = $false
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
        Copy-SelectedFile -Selected $true `
            -Source (Join-Path $script:SCRIPT_DIR "config.toml") `
            -Target (Join-Path $CODEX_DIR "config.toml") `
            -Label "config.toml" `
            -SkipIfExists
        # config.toml references lessons.md via model_instructions_file; make
        # sure the file exists even when the Lessons item was deselected.
        if (-not $script:SelectCoreLessons -and -not (Test-Path (Join-Path $CODEX_DIR "lessons.md"))) {
            Write-Warn "config.toml requires lessons.md (model_instructions_file); seeding it although Lessons was deselected"
        }
        Install-LessonsIfMissing
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
    $remoteAvailable = Test-Path $INSTALLER
    $needsRemote = $script:SelectSkillDocumentSkills -or $script:SelectSkillExampleSkills -or $script:SelectSkillCodingFoundations
    if (-not $remoteAvailable -and $needsRemote) {
        Write-Warn "skill-installer not found at $INSTALLER"
        Write-Warn "Remote skill packs that depend on it will be skipped."
        $script:SKIPPED_COMPONENTS += "recommended remote skill packs (skill-installer not found)"
    }

    if ($script:SelectSkillSuperpowers) {
        Install-Superpowers
    }

    if ($remoteAvailable) {
        if ($script:SelectSkillDocumentSkills) {
            Install-SkillPaths "anthropics/skills" @(
                "skills/pdf", "skills/docx", "skills/pptx", "skills/xlsx"
            )
        }

        if ($script:SelectSkillExampleSkills) {
            Install-SkillPaths "anthropics/skills" @(
                "skills/frontend-design", "skills/canvas-design", "skills/algorithmic-art", "skills/mcp-builder"
            )
        }

        if ($script:SelectSkillCodingFoundations) {
            Install-SkillPaths "affaan-m/everything-claude-code" @(
                "skills/python-patterns", "skills/python-testing", "skills/golang-patterns", "skills/golang-testing",
                "skills/frontend-patterns", "skills/security-review", "skills/tdd-workflow", "skills/verification-loop",
                "skills/api-design", "skills/database-migrations"
            )
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
    $remoteAvailable = Test-Path $INSTALLER
    $needsRemote = $script:SelectAiTokenization -or $script:SelectAiFineTuning -or $script:SelectAiPostTraining -or `
        $script:SelectAiDistributedTraining -or $script:SelectAiInferenceServing -or $script:SelectAiOptimization -or `
        $script:SelectAiDeepXiv
    if (-not $remoteAvailable -and $needsRemote) {
        Write-Warn "skill-installer not found at $INSTALLER"
        Write-Warn "AI research skill packs that depend on it will be skipped."
        $script:SKIPPED_COMPONENTS += "AI research skill packs (skill-installer not found)"
        return
    }

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

function Write-McpResult {
    if ($script:MCP_FAILED_SERVERS.Count -eq 0) {
        Write-Ok "MCP setup complete (existing entries are ignored)"
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
        Add-McpServer "github" @("--env", "GITHUB_PERSONAL_ACCESS_TOKEN=YOUR_GITHUB_PAT", "--", "npx", "-y", "@modelcontextprotocol/server-github")
    }
    if ($script:SelectMcpPlaywright) {
        Add-McpServer "playwright" @("--", "npx", "-y", "@playwright/mcp@latest")
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
                [pscustomobject]@{ Label = "lessons.md"; Description = "Lessons source-of-truth"; Default = $true; StateVar = "SelectCoreLessons" }
            )
        },
        [pscustomobject]@{
            Label = "Agents"
            Hint = ""
            Items = @(
                [pscustomobject]@{ Label = "explorer"; Description = "Code-path exploration agent"; Default = $true; StateVar = "SelectAgentExplorer" },
                [pscustomobject]@{ Label = "reviewer"; Description = "Review/regression agent"; Default = $true; StateVar = "SelectAgentReviewer" },
                [pscustomobject]@{ Label = "docs-researcher"; Description = "Docs/API verification agent"; Default = $true; StateVar = "SelectAgentDocsResearcher" }
            )
        },
        [pscustomobject]@{
            Label = "Skills - Recommended"
            Hint = ""
            Items = @(
                [pscustomobject]@{ Label = "superpowers"; Description = "Planning and execution workflows"; Default = $true; StateVar = "SelectSkillSuperpowers" },
                [pscustomobject]@{ Label = "document-skills"; Description = "PDF/DOCX/PPTX/XLSX skills pack"; Default = $true; StateVar = "SelectSkillDocumentSkills" },
                [pscustomobject]@{ Label = "example-skills"; Description = "Frontend/art/MCP builder pack"; Default = $true; StateVar = "SelectSkillExampleSkills" },
                [pscustomobject]@{ Label = "coding-foundations"; Description = "Patterns, testing, security (upstream everything-claude-code)"; Default = $true; StateVar = "SelectSkillCodingFoundations" },
                [pscustomobject]@{ Label = "paper-reading"; Description = "Research paper summarization"; Default = $true; StateVar = "SelectSkillPaperReading" },
                [pscustomobject]@{ Label = "humanizer"; Description = "Remove AI writing patterns"; Default = $true; StateVar = "SelectSkillHumanizer" },
                [pscustomobject]@{ Label = "humanizer-zh"; Description = "Remove Chinese AI writing patterns"; Default = $false; StateVar = "SelectSkillHumanizerZh" },
                [pscustomobject]@{ Label = "handoff"; Description = "Compact context into a handoff doc"; Default = $true; StateVar = "SelectSkillHandoff" },
                [pscustomobject]@{ Label = "adversarial-review"; Description = "Cross-model adversarial review"; Default = $true; StateVar = "SelectSkillAdversarialReview" },
                [pscustomobject]@{ Label = "update"; Description = "Update Codex config branch install"; Default = $true; StateVar = "SelectSkillUpdate" }
            )
        },
        [pscustomobject]@{
            Label = "Skills - AI Research"
            Hint = ""
            Items = @(
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
            Label = "MCP Servers"
            Hint = ""
            Items = @(
                [pscustomobject]@{ Label = "context7"; Description = "Up-to-date library docs"; Default = $true; StateVar = "SelectMcpContext7" },
                [pscustomobject]@{ Label = "github"; Description = "GitHub workflows (needs a real PAT)"; Default = $false; StateVar = "SelectMcpGithub" },
                [pscustomobject]@{ Label = "playwright"; Description = "Browser automation"; Default = $true; StateVar = "SelectMcpPlaywright" },
                [pscustomobject]@{ Label = "openaiDeveloperDocs"; Description = "Official OpenAI docs MCP"; Default = $true; StateVar = "SelectMcpOpenaiDeveloperDocs" },
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
                'SelectCoreLessons' { if ($selected) { $coreSelected = $true } }
                'SelectAgentExplorer' { if ($selected) { $coreSelected = $true } }
                'SelectAgentReviewer' { if ($selected) { $coreSelected = $true } }
                'SelectAgentDocsResearcher' { if ($selected) { $coreSelected = $true } }
                'SelectSkillSuperpowers' { if ($selected) { $skillsSelected = $true } }
                'SelectSkillDocumentSkills' { if ($selected) { $skillsSelected = $true } }
                'SelectSkillExampleSkills' { if ($selected) { $skillsSelected = $true } }
                'SelectSkillCodingFoundations' { if ($selected) { $skillsSelected = $true } }
                'SelectSkillPaperReading' { if ($selected) { $skillsSelected = $true } }
                'SelectSkillHumanizer' { if ($selected) { $skillsSelected = $true } }
                'SelectSkillHumanizerZh' { if ($selected) { $skillsSelected = $true } }
                'SelectSkillHandoff' { if ($selected) { $skillsSelected = $true } }
                'SelectSkillAdversarialReview' { if ($selected) { $skillsSelected = $true } }
                'SelectSkillUpdate' { if ($selected) { $skillsSelected = $true } }
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
        Write-Info "No items selected. Nothing to do."
        return
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

    # lark-mcp and github need real credentials; configuring them with the
    # template placeholders would create active-but-broken servers. They stay
    # opt-in via the interactive menu or a manual `codex mcp add`.
    Write-Info "Skipping lark-mcp and github MCP servers: they require real credentials."
    Write-Info "Enable them via the interactive installer or 'codex mcp add' after filling credentials."
    Add-McpServer "context7" @("--", "npx", "-y", "@upstash/context7-mcp")
    Add-McpServer "playwright" @("--", "npx", "-y", "@playwright/mcp@latest")
    Add-McpServer "openaiDeveloperDocs" @("--url", "https://developers.openai.com/mcp")
    Write-McpResult
}

function Install-SkillPaths {
    param([string]$Repo, [string[]]$Paths)

    if ($DryRun) {
        Write-Info "Would install from ${Repo}: $($Paths -join ', ')"
        return
    }

    $py = if (Get-Command "python3" -ErrorAction SilentlyContinue) { "python3" } else { "python" }
    & $py $INSTALLER --repo $Repo --path @Paths
    if ($LASTEXITCODE -ne 0) {
        Write-Warn "Skill install from $Repo returned non-zero (possibly already installed)"
        $script:SKIPPED_COMPONENTS += "skill pack from $Repo (installer returned non-zero)"
    }
}

function Reinstall-SkillPaths {
    param([string]$Repo, [string[]]$Paths)

    if ($DryRun) {
        Write-Info "Would reinstall from ${Repo}: $($Paths -join ', ')"
        return
    }

    foreach ($path in $Paths) {
        $skill = Split-Path $path -Leaf
        $dest = Join-Path $CODEX_DIR "skills/$skill"
        if (Test-Path $dest) {
            Remove-Item -Recurse -Force $dest
            Write-Ok "Removed existing skill before reinstall: $skill"
        }
    }

    $py = if (Get-Command "python3" -ErrorAction SilentlyContinue) { "python3" } else { "python" }
    & $py $INSTALLER --repo $Repo --path @Paths
    if ($LASTEXITCODE -ne 0) {
        Write-Warn "Skill reinstall from $Repo returned non-zero"
        $script:SKIPPED_COMPONENTS += "skill pack from $Repo (installer returned non-zero)"
    }
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

function Install-Superpowers {
    Write-Info "Installing full superpowers skill set..."

    if ($DryRun) {
        Write-Info "Would clone or update: $SUPERPOWERS_REPO_URL -> $SUPERPOWERS_DIR"
        Write-Info "Would create junction:  $SUPERPOWERS_LINK -> $SUPERPOWERS_DIR\skills"
        Write-Info "Would remove legacy copied superpowers skills from $CODEX_DIR\skills"
        return
    }

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
            Write-Ok "Installed local skill: $skill"
        }
    }
}

function Install-Skills {
    if ($InteractiveMode) {
        Write-Info "Installing selected skills..."
        Install-SelectedRecommendedSkills
        Install-SelectedAiSkills

        if ($script:SelectSkillPaperReading -or $script:SelectSkillHumanizer -or
            $script:SelectSkillHumanizerZh -or $script:SelectSkillHandoff -or
            $script:SelectSkillAdversarialReview -or $script:SelectSkillUpdate -or
            $script:SelectSkillSuperpowers -or $script:SelectSkillDocumentSkills -or
            $script:SelectSkillExampleSkills -or $script:SelectSkillCodingFoundations -or
            $script:SelectAiTokenization -or $script:SelectAiFineTuning -or
            $script:SelectAiPostTraining -or $script:SelectAiDistributedTraining -or
            $script:SelectAiInferenceServing -or $script:SelectAiOptimization -or
            $script:SelectAiDeepXiv) {
            Write-Ok "Selected skills processed"
        } else {
            Write-Info "No selected skills to install"
        }
        return
    }

    Write-Info "Installing skills (group: $SkillGroup)..."

    $remoteAvailable = Test-Path $INSTALLER
    if (-not $remoteAvailable) {
        Write-Warn "skill-installer not found at $INSTALLER"
        Write-Warn "Remote skill packs that depend on it will be skipped."
    }

    if ($SkillGroup -eq "core" -or $SkillGroup -eq "all") {
        Install-Superpowers

        if ($remoteAvailable) {
            Install-SkillPaths "anthropics/skills" @(
                "skills/frontend-design", "skills/pdf", "skills/docx", "skills/pptx", "skills/xlsx",
                "skills/canvas-design", "skills/algorithmic-art", "skills/mcp-builder"
            )
            Install-SkillPaths "affaan-m/everything-claude-code" @(
                "skills/python-patterns", "skills/python-testing", "skills/golang-patterns", "skills/golang-testing",
                "skills/frontend-patterns", "skills/security-review", "skills/tdd-workflow", "skills/verification-loop",
                "skills/api-design", "skills/database-migrations"
            )
        } else {
            $script:SKIPPED_COMPONENTS += "core remote skill packs (skill-installer not found)"
        }

        Install-LocalSkills
    }

    if ($SkillGroup -eq "ai-research" -or $SkillGroup -eq "all") {
        if (-not $remoteAvailable) {
            Write-Warn "Skipping AI research skills because skill-installer is unavailable"
            $script:SKIPPED_COMPONENTS += "AI research skill packs (skill-installer not found)"
            return
        }

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

        # DeepXiv is grouped under "Skills - AI Research" in the README and the
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
        if ($script:InteractiveMode -and -not $script:InteractiveSelectionHasAny) {
            exit 0
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

    Write-Ok "Done. Restart Codex to load new skills/config if needed."
} finally {
    Remove-TempDir
}
