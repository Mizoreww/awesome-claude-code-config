#Requires -Version 5.1
<#
.SYNOPSIS
  Codex Configuration Installer (Windows)
  https://github.com/Mizoreww/awesome-claude-code-config

.DESCRIPTION
  Install Codex configuration files on Windows. PowerShell equivalent of install.sh.

.PARAMETER All
  Install everything (default)

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
$REPO_URL             = "https://github.com/Mizoreww/awesome-claude-code-config"
$VERSION_STAMP_FILE   = Join-Path $CODEX_DIR ".claude-code-config-version"
$INSTALLER            = Join-Path $CODEX_DIR "skills/.system/skill-installer/scripts/install-skill-from-github.py"
$SUPERPOWERS_REPO_URL = "https://github.com/obra/superpowers.git"
$SUPERPOWERS_DIR      = Join-Path $CODEX_DIR "superpowers"
$AGENTS_SKILLS_DIR    = Join-Path $HOME ".agents/skills"
$SUPERPOWERS_LINK     = Join-Path $AGENTS_SKILLS_DIR "superpowers"

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
    "humanizer"
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

    $version = if ($env:VERSION) { $env:VERSION } else { "codex" }
    $tarball_url = "$REPO_URL/archive/refs/heads/${version}.tar.gz"
    if ($version -match '^v[0-9]') {
        $tarball_url = "$REPO_URL/archive/refs/tags/${version}.tar.gz"
    }

    Write-Info "Remote mode: downloading $version..."
    $tarball = Join-Path $tmpdir "archive.tar.gz"
    try {
        Invoke-WebRequest -Uri $tarball_url -OutFile $tarball -UseBasicParsing
        # tar is available on Windows 10 1803+
        tar -xzf $tarball -C $tmpdir --strip-components=1
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

Options:
  -All                       Install everything (default)
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
  `$env:VERSION='v1.0.0'; irm $REPO_URL/raw/codex/install.ps1 | iex
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
    return "not installed"
}

function Get-RemoteVersion {
    try {
        $r = Invoke-WebRequest -Uri "$REPO_URL/raw/codex/VERSION" -UseBasicParsing -TimeoutSec 10
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
        Set-Content -Path $VERSION_STAMP_FILE -Value $ver -NoNewline
    }
}

# ============================================================
# Install functions
# ============================================================
function Install-Core {
    Write-Info "Installing core files..."
    New-Item -ItemType Directory -Path $CODEX_DIR -Force | Out-Null

    Backup-IfExists (Join-Path $CODEX_DIR "AGENTS.md")
    Backup-IfExists (Join-Path $CODEX_DIR "lessons.md")
    Backup-IfExists (Join-Path $CODEX_DIR "agents")

    if ($DryRun) {
        Write-Info "Would copy: AGENTS.md  -> $CODEX_DIR\AGENTS.md"
        Write-Info "Would copy: lessons.md -> $CODEX_DIR\lessons.md"
        Write-Info "Would copy: agents\*.toml -> $CODEX_DIR\agents\"
    } else {
        Copy-Item (Join-Path $script:SCRIPT_DIR "AGENTS.md")  (Join-Path $CODEX_DIR "AGENTS.md")  -Force
        Copy-Item (Join-Path $script:SCRIPT_DIR "lessons.md") (Join-Path $CODEX_DIR "lessons.md") -Force
        $agentsSrc = Join-Path $script:SCRIPT_DIR "agents"
        if (Test-Path $agentsSrc) {
            $agentsDst = Join-Path $CODEX_DIR "agents"
            New-Item -ItemType Directory -Path $agentsDst -Force | Out-Null
            Copy-Item (Join-Path $agentsSrc "*.toml") $agentsDst -Force
        }
        Write-Ok "AGENTS.md, lessons.md, and agents installed"
    }

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
    Write-Info "Installing MCP servers..."

    if (-not (Get-Command "codex" -ErrorAction SilentlyContinue)) {
        Write-Warn "codex CLI not found. Skip MCP setup."
        return
    }

    if ($DryRun) {
        Write-Info "Would add MCP server: lark-mcp"
        Write-Info "Would add MCP server: context7"
        Write-Info "Would add MCP server: github"
        Write-Info "Would add MCP server: playwright"
        Write-Info "Would add MCP server: openaiDeveloperDocs"
        return
    }

    codex mcp add lark-mcp -- npx -y @larksuiteoapi/lark-mcp mcp -a YOUR_APP_ID -s YOUR_APP_SECRET 2>$null
    codex mcp add context7 -- npx -y @upstash/context7-mcp 2>$null
    codex mcp add github --env GITHUB_PERSONAL_ACCESS_TOKEN=YOUR_GITHUB_PAT -- npx -y @modelcontextprotocol/server-github 2>$null
    codex mcp add playwright -- npx -y "@playwright/mcp@latest" 2>$null
    codex mcp add openaiDeveloperDocs --url https://developers.openai.com/mcp 2>$null
    Write-Ok "MCP setup complete (existing entries are ignored)"
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
        return
    } else {
        git clone $SUPERPOWERS_REPO_URL $SUPERPOWERS_DIR
        if ($LASTEXITCODE -ne 0) {
            Write-Warn "Failed to clone superpowers repo"
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
            return
        }
        # Remove existing reparse point before recreating
        cmd /c rmdir "$SUPERPOWERS_LINK" | Out-Null
    }

    # Use junction (no admin required, unlike directory symlinks on Windows)
    cmd /c mklink /j "$SUPERPOWERS_LINK" "$superPowersSkillsDir" | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Warn "Failed to create junction at $SUPERPOWERS_LINK"
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
        }

        Install-LocalSkills
    }

    if ($SkillGroup -eq "ai-research" -or $SkillGroup -eq "all") {
        if (-not $remoteAvailable) {
            Write-Warn "Skipping AI research skills because skill-installer is unavailable"
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
                Write-Host "  - $CODEX_DIR\lessons.md"
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

    Detect-ScriptDir

    if ($Version) {
        Show-Version
        exit 0
    }

    if ($Uninstall) {
        Invoke-Uninstall
        exit 0
    }

    # Determine what to install
    $installAll    = $All -or (-not $Core -and -not $Mcp -and -not $Skills)
    $installCore   = $Core
    $installMcp    = $Mcp
    $installSkills = $Skills

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

    New-Item -ItemType Directory -Path $CODEX_DIR -Force | Out-Null

    if ($installAll) {
        Install-Core
        Install-Mcp
        Install-Skills
    } else {
        if ($installCore)   { Install-Core }
        if ($installMcp)    { Install-Mcp }
        if ($installSkills) { Install-Skills }
    }

    Set-VersionStamp
    Write-Ok "Done. Restart Codex to load new skills/config if needed."
} finally {
    Remove-TempDir
}
