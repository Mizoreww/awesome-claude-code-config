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
  Install AGENTS.md, blank global lessons.md, config.toml, agents/*

.PARAMETER Mcp
  Install MCP servers only

.PARAMETER Skills
  Install skills only

.PARAMETER SkillGroup
  Skill group: core, ai-research, all (default: all). Default-off
  ResearchStudio/PPT entries require an explicit SkillGroup or -All.

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

function Get-GlobalSkillLockFile {
    param(
        [string]$HomePath = $HOME,
        [AllowEmptyString()]
        [string]$XdgStateHome = $env:XDG_STATE_HOME
    )

    if ($XdgStateHome) {
        return (Join-Path $XdgStateHome "skills/.skill-lock.json")
    }
    return (Join-Path $HomePath ".agents/.skill-lock.json")
}

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
# skills@latest currently stages universal Codex installs under ~/.agents/skills
# even with --agent codex --copy. Keep that directory as an upstream
# staging/compatibility location only; Codex-branch skills are owned and loaded
# from ~/.codex/skills.
$SUPERPOWERS_LINK     = Join-Path $CODEX_DIR "skills/superpowers"
$LEGACY_SUPERPOWERS_LINK = Join-Path $AGENTS_SKILLS_DIR "superpowers"

$script:InteractiveMode = $false
$script:InteractiveSelectionHasAny = $false
$script:SkillGroupExplicit = $PSBoundParameters.ContainsKey("SkillGroup")
$script:ResearchStudioNonInteractiveRequested = [bool](
    $All -or ($Skills -and $script:SkillGroupExplicit -and ($SkillGroup -eq "ai-research" -or $SkillGroup -eq "all"))
)
$script:ResearchStudioReelNonInteractiveRequested = $script:ResearchStudioNonInteractiveRequested
$script:PptMasterNonInteractiveRequested = [bool]($All -or ($Skills -and $script:SkillGroupExplicit -and $SkillGroup -eq "all"))
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
$script:SelectSkillPptMaster = $false
$script:SelectSkillPaperReading = $true
$script:SelectSkillHumanizer = $true
$script:SelectSkillHumanizerZh = $false
$script:SelectSkillHandoff = $true
$script:SelectSkillAdversarialReview = $false
$script:SelectSkillUpdate = $true
$script:SelectAiTokenization = $false
$script:SelectAiFineTuning = $false
$script:SelectAiPostTraining = $false
$script:SelectAiDistributedTraining = $false
$script:SelectAiInferenceServing = $false
$script:SelectAiOptimization = $false
$script:SelectAiDeepXiv = $false
$script:SelectAiResearchStudio = $false
$script:SelectAiResearchStudioReel = $false
$script:SelectMcpContext7 = $true
$script:SelectMcpGithub = $true
$script:SelectMcpPlaywright = $true
$script:SelectMcpOpenaiDeveloperDocs = $true
$script:SelectMcpLark = $false

$MANAGED_SKILLS = @(
    "frontend-design", "pdf", "docx", "pptx", "xlsx", "canvas-design", "algorithmic-art", "mcp-builder",
    "using-superpowers", "systematic-debugging", "writing-plans", "test-driven-development",
    "huggingface-tokenizers", "sentencepiece",
    "axolotl", "llama-factory", "peft-fine-tuning", "unsloth",
    "grpo-rl-training", "openrlhf-training", "simpo-training", "fine-tuning-with-trl", "verl-rl-training",
    "deepspeed", "pytorch-fsdp2", "training-llms-megatron", "ray-train",
    "awq-quantization", "gptq", "gguf-quantization", "optimizing-attention-flash", "quantizing-models-bitsandbytes",
    "serving-llms-vllm", "sglang", "tensorrt-llm", "llama-cpp",
    "paper-reading",
    "adversarial-review",
    "handoff",
    "humanizer",
    "humanizer-zh",
    "update",
    "deepxiv-cli",
    "deepxiv-baseline-table",
    "deepxiv-trending-digest",
    "idea_spark",
    "paper_search",
    "scoop_check",
    "paper2assets",
    "paper2poster",
    "paper2video",
    "paper2blog",
    "paper2reel",
    "code-review",
    "karpathy-guidelines",
    "brainstorming", "dispatching-parallel-agents", "executing-plans", "finishing-a-development-branch",
    "receiving-code-review", "requesting-code-review", "subagent-driven-development", "using-git-worktrees",
    "verification-before-completion", "writing-skills",
    "frontend-slides",
    "ppt-master",
    "ask-matt", "diagnosing-bugs", "grill-with-docs", "triage",
    "implement", "improve-codebase-architecture", "setup-matt-pocock-skills", "tdd",
    "to-spec", "to-tickets", "wayfinder", "prototype", "domain-modeling", "codebase-design",
    "grill-me", "grilling", "research", "teach", "writing-great-skills",
    "pua", "pua-en", "pua-ja"
)

$LEGACY_CLEANUP_SKILLS = @(
    "python-patterns", "python-testing", "golang-patterns", "golang-testing", "frontend-patterns",
    "security-review", "tdd-workflow", "verification-loop", "api-design", "database-migrations"
)

$MATTPOCOCK_LEGACY_SKILLS = @(
    "to-issues", "to-prd", "decision-mapping", "review"
)

$OWNERSHIP_SKILLS = @($MANAGED_SKILLS) + @($LEGACY_CLEANUP_SKILLS) + @($MATTPOCOCK_LEGACY_SKILLS)

$LEGACY_SUPERPOWERS_SKILLS = @(
    "using-superpowers",
    "systematic-debugging",
    "writing-plans",
    "test-driven-development"
)

$MATTPOCOCK_SKILLS = @(
    "ask-matt", "diagnosing-bugs", "grill-with-docs", "triage",
    "implement", "improve-codebase-architecture", "setup-matt-pocock-skills", "tdd",
    "to-spec", "to-tickets", "wayfinder", "prototype", "domain-modeling", "codebase-design",
    "grill-me", "grilling", "research", "teach", "writing-great-skills"
)

$RESEARCHSTUDIO_SKILLS = @("idea_spark", "paper_search", "scoop_check")
$RESEARCHSTUDIO_REEL_SKILLS = @("paper2assets", "paper2poster", "paper2video", "paper2blog", "paper2reel")
$RESEARCHSTUDIO_REPO_URL = "https://github.com/microsoft/ResearchStudio.git"
$PUA_SKILLS = @("pua", "pua-en", "pua-ja")
$SUPERPOWERS_SKILLS = @(
    "brainstorming", "dispatching-parallel-agents", "executing-plans", "finishing-a-development-branch",
    "receiving-code-review", "requesting-code-review", "subagent-driven-development", "systematic-debugging",
    "test-driven-development", "using-git-worktrees", "using-superpowers", "verification-before-completion",
    "writing-plans", "writing-skills"
)
$LOCAL_MANAGED_SKILLS = @("paper-reading", "humanizer", "humanizer-zh", "handoff", "adversarial-review", "update")
$MANAGED_SKILLS_STATE_FILE = Join-Path $CODEX_DIR ".awesome-claude-code-config-managed-skills"
$GLOBAL_SKILL_LOCK_FILE = Get-GlobalSkillLockFile
$script:OwnedManagedSkills = New-Object 'System.Collections.Generic.HashSet[string]'
$script:ManagedSkillOwnershipLoaded = $false
$script:MattPocockQuickstartReady = $false
$script:MATTPOCOCK_VERSION = "v1.1.0"
$script:MATTPOCOCK_COMMIT = "d574778f94cf620fcc8ce741584093bc650a61d3"
$script:CODEX_STATUS_LINE = 'status_line = ["model", "reasoning", "project-name", "git-branch", "context-used", "five-hour-limit", "weekly-limit"]'
$script:CODEX_STATUS_LINE_USE_COLORS = 'status_line_use_colors = true'
$script:PLAYWRIGHT_MCP_VERSION = "0.0.78"
$script:PLAYWRIGHT_MIN_NODE_MAJOR = 20
$script:PLAYWRIGHT_NODE_FALLBACK_VERSION = "24"
$script:SKILLS_MIN_NODE_MAJOR = 20
$script:NpxVerifiedSkillNames = @()
$script:SKILLS_NODE_FALLBACK_VERSION = "24"
$script:SkillsNodeFallbackNotified = $false

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
        "  3. Insert and run it; it will configure the issue tracker, triage labels when applicable, and domain docs.",
        "  Note: installed skills are not individual root slash commands such as /setup-matt-pocock-skills."
    )
}

function Convert-ResearchStudioIdeaForCodex {
    $paperSkill = Join-Path $CODEX_DIR "skills/paper_search/SKILL.md"
    $scoopSkill = Join-Path $CODEX_DIR "skills/scoop_check/SKILL.md"
    $fetchScript = Join-Path $CODEX_DIR "skills/scoop_check/scripts/fetch_paper.sh"
    foreach ($path in @($paperSkill, $scoopSkill, $fetchScript)) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $false }
    }

    try {
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        $searchScript = (Join-Path $CODEX_DIR "skills/paper_search/scripts/search_papers.py") -replace '\\', '/'

        $paperText = [System.IO.File]::ReadAllText($paperSkill)
        $paperText = $paperText.Replace('${CLAUDE_PROJECT_DIR}/skills/paper_search/scripts/search_papers.py', $searchScript)
        $paperText = $paperText.Replace('${CLAUDE_PROJECT_DIR}/allinone.md', '${PWD}/allinone.md')
        [System.IO.File]::WriteAllText($paperSkill, $paperText, $utf8NoBom)

        $scoopText = [System.IO.File]::ReadAllText($scoopSkill)
        $scoopText = $scoopText.Replace('.claude/skills/', 'the installed Codex skills directory')
        $scoopText = $scoopText.Replace('${CLAUDE_PROJECT_DIR}', '${PWD}')
        $scoopText = $scoopText.Replace(
            'Do **not** use `AskUserQuestion` or pause for confirmation at any point',
            'Do **not** ask a blocking clarification question or pause for confirmation at any point'
        )
        $scoopText = $scoopText.Replace(
            'use `TaskCreate` to register all seven steps as tasks up front',
            "use Codex's ``update_plan`` tool to register all seven steps up front"
        )
        $scoopText = $scoopText.Replace(
            'handing the PDF URL to `WebFetch` directly',
            'asking Codex web browsing to summarize the PDF directly'
        )
        $scoopText = $scoopText.Replace(
            'Use `WebFetch` first only to locate the PDF URL',
            'Use Codex web browsing only to locate the PDF URL'
        )
        $scoopText = $scoopText.Replace(
            'Use the `Read` tool on the printed `.txt` path.',
            "Read the printed ``.txt`` path with Codex's local filesystem tools."
        )
        $scoopText = $scoopText.Replace(
            'try `WebFetch` on the abstract / HTML version',
            'use Codex web browsing on the abstract / HTML version'
        )
        $scoopFetch = (Join-Path $CODEX_DIR "skills/scoop_check/scripts/fetch_paper.sh") -replace '\\', '/'
        $scoopText = [regex]::Replace($scoopText, '(?<![/\\\w])scripts/fetch_paper\.sh', ('bash "' + $scoopFetch + '"'))
        [System.IO.File]::WriteAllText($scoopSkill, $scoopText, $utf8NoBom)

        $fetchText = [System.IO.File]::ReadAllText($fetchScript)
        $fetchText = $fetchText.Replace(': "${CLAUDE_PROJECT_DIR:?CLAUDE_PROJECT_DIR must be set}"', 'PROJECT_DIR="${CODEX_PROJECT_DIR:-${CLAUDE_PROJECT_DIR:-$PWD}}"')
        $fetchText = $fetchText.Replace('${CLAUDE_PROJECT_DIR}', '${PROJECT_DIR}')
        $fetchText = $fetchText.Replace(': "${PROJECT_DIR:?CLAUDE_PROJECT_DIR must be set}"', 'PROJECT_DIR="${CODEX_PROJECT_DIR:-${CLAUDE_PROJECT_DIR:-$PWD}}"')
        [System.IO.File]::WriteAllText($fetchScript, $fetchText, $utf8NoBom)
        return $true
    } catch {
        Write-Warn "ResearchStudio Idea Codex path adaptation failed: $_"
        return $false
    }
}

function Test-ResearchStudioIdeaAdapter {
    $paperSkill = Join-Path $CODEX_DIR "skills/paper_search/SKILL.md"
    $paperScript = Join-Path $CODEX_DIR "skills/paper_search/scripts/search_papers.py"
    $scoopSkill = Join-Path $CODEX_DIR "skills/scoop_check/SKILL.md"
    $fetchScript = Join-Path $CODEX_DIR "skills/scoop_check/scripts/fetch_paper.sh"
    foreach ($path in @(
        (Join-Path $CODEX_DIR "skills/idea_spark/SKILL.md"),
        $paperSkill,
        $paperScript,
        $scoopSkill,
        $fetchScript
    )) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $false }
    }

    $paperText = [System.IO.File]::ReadAllText($paperSkill)
    $scoopText = [System.IO.File]::ReadAllText($scoopSkill)
    $fetchText = [System.IO.File]::ReadAllText($fetchScript)
    $paperPath = $paperScript -replace '\\', '/'
    $fetchPath = $fetchScript -replace '\\', '/'
    if (-not $paperText.Contains($paperPath)) { return $false }
    if (-not $scoopText.Contains('bash "' + $fetchPath + '"')) { return $false }
    if ($scoopText -match 'TaskCreate|AskUserQuestion|WebFetch|`Read` tool') { return $false }
    if ($fetchText.Contains('CLAUDE_PROJECT_DIR must be set')) { return $false }
    return $true
}

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
    param(
        [string[]]$Command,
        [int]$MinimumMajor = 3,
        [int]$MinimumMinor = 0
    )

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
        $probeArgs += @(
            "-c",
            "import sys; raise SystemExit(0 if sys.version_info[:2] >= ($MinimumMajor, $MinimumMinor) else 1)"
        )
        & $exe @probeArgs *> $null
        return ($LASTEXITCODE -eq 0)
    } catch {
        return $false
    }
}

function Resolve-PythonCommand {
    param(
        [int]$MinimumMajor = 3,
        [int]$MinimumMinor = 0
    )
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
        if (Test-PythonCommand -Command $candidate -MinimumMajor $MinimumMajor -MinimumMinor $MinimumMinor) {
            return ,$candidate
        }
    }

    return $null
}

function Get-SkillsNpxLauncherArgs {
    if (-not (Get-Command "npx" -ErrorAction SilentlyContinue)) {
        return $null
    }

    $nodeMajor = Get-NodeMajorVersion
    if ($null -eq $nodeMajor) {
        return $null
    }
    if ($nodeMajor -lt $script:SKILLS_MIN_NODE_MAJOR) {
        if (-not $script:SkillsNodeFallbackNotified) {
            Write-Warn "Node.js $nodeMajor detected; using an isolated Node.js $($script:SKILLS_NODE_FALLBACK_VERSION) runtime for npx skills"
            $script:SkillsNodeFallbackNotified = $true
        }
        return @(
            "-y",
            "--loglevel=error",
            "--package=node@$($script:SKILLS_NODE_FALLBACK_VERSION)",
            "--package=skills@latest",
            "--",
            "skills"
        )
    }
    return @("-y", "skills@latest")
}

function Show-Usage {
    @"
Usage: .\install.ps1 [OPTIONS]

Install Codex configuration files.
Running without component flags launches an interactive selector.
Use -All for non-interactive full install.

Options:
  -All                       Install everything non-interactively
  -Core                      Install AGENTS.md, blank global lessons.md, config.toml, agents/*
  -Mcp                       Install MCP servers only
  -Skills [-SkillGroup GROUP] Install skills only. GROUP: core, ai-research, all (default: all)
                             Default-off ResearchStudio/PPT entries require an explicit GROUP or -All
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
    $script:SelectSkillPptMaster = $false
    $script:SelectSkillPaperReading = $true
    $script:SelectSkillHumanizer = $true
    $script:SelectSkillHumanizerZh = $false
    $script:SelectSkillHandoff = $true
    $script:SelectSkillAdversarialReview = $false
    $script:SelectSkillUpdate = $true
    $script:SelectAiTokenization = $false
    $script:SelectAiFineTuning = $false
    $script:SelectAiPostTraining = $false
    $script:SelectAiDistributedTraining = $false
    $script:SelectAiInferenceServing = $false
    $script:SelectAiOptimization = $false
    $script:SelectAiDeepXiv = $false
    $script:SelectAiResearchStudio = $false
    $script:SelectAiResearchStudioReel = $false
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

    $skillName = Split-Path $Target -Leaf
    $stagingWasOwned = $false
    if (-not $DryRun -and (Test-ManagedSkillName $skillName)) {
        Initialize-ManagedSkillOwnership
        $stagingWasOwned = $script:OwnedManagedSkills.Contains($skillName)
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
        if (Test-Path $Target) {
            Remove-Item -Recurse -Force $Target
        }
        Copy-Item $Source $Target -Recurse -Force
        if ($stagingWasOwned) {
            [void](Remove-ManagedStagingSkill $skillName)
        }
        if (Test-ManagedSkillName $skillName) {
            Add-ManagedSkillOwnership @($skillName)
        }
        Write-Ok "$Label installed"
    }
}

# ~/.codex/lessons.md is the user's cross-project correction memory (see
# AGENTS.md), and config.toml points model_instructions_file at it. Never copy
# this repository's project lessons into global state; seed only the dedicated
# global template, and never overwrite an existing global log.
function Install-LessonsIfMissing {
    if ($script:LessonsSeeded) { return }
    $script:LessonsSeeded = $true

    $target = Join-Path $CODEX_DIR "lessons.md"
    if (Test-Path $target) {
        Write-Info "Preserving existing lessons.md (template not copied)"
        return
    }

    if ($DryRun) {
        Write-Info "Would copy: templates/global-lessons.md -> $target"
    } else {
        New-Item -ItemType Directory -Path $CODEX_DIR -Force | Out-Null
        Copy-Item (Join-Path $script:SCRIPT_DIR "templates/global-lessons.md") $target -Force
        Write-Ok "Global lessons.md installed"
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
        if (-not (Install-MattPocockSkillNames @("code-review"))) {
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
        if (Install-MattPocockSkillNames $MATTPOCOCK_SKILLS) {
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
    if ($script:SelectSkillPptMaster) {
        Install-PptMaster
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
    if ($script:SelectAiResearchStudio) {
        Install-ResearchStudio
    }
    if ($script:SelectAiResearchStudioReel) {
        Install-ResearchStudioReel
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
        $initializeRequest = '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"awesome-claude-code-config-installer","version":"1.0.0"}}}'
        $initializeOutput = $initializeRequest | & npx @launcherArgs 2>&1
        $initializeExitCode = $LASTEXITCODE
        $initializeText = ($initializeOutput | ForEach-Object { $_.ToString() }) -join "`n"
        if ($initializeExitCode -ne 0 -or
            $initializeText -notmatch '"result"\s*:' -or
            $initializeText -notmatch '"serverInfo"\s*:') {
            Write-Warn "Playwright MCP initialize check failed; not registering a broken server"
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
                [pscustomobject]@{ Label = "lessons.md"; Description = "Blank global correction log"; Default = $true; StateVar = "SelectCoreLessons" }
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
                [pscustomobject]@{ Label = "adversarial-review"; Description = "Cross-model adversarial review"; Default = $false; StateVar = "SelectSkillAdversarialReview" }
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
            Hint = "research ideation, literature, training/inference"
            Items = @(
                [pscustomobject]@{ Label = "paper-reading"; Description = "Research paper summarization"; Default = $true; StateVar = "SelectSkillPaperReading" },
                [pscustomobject]@{ Label = "ResearchStudio Idea"; Description = "Research ideation: idea-spark, paper-search, scoop-check"; Default = $false; StateVar = "SelectAiResearchStudio" },
                [pscustomobject]@{ Label = "ResearchStudio Reel"; Description = "Paper-to-poster, video, blog, and interactive reel"; Default = $false; StateVar = "SelectAiResearchStudioReel" },
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
                [pscustomobject]@{ Label = "frontend-slides"; Description = "HTML slide generator with PPT conversion"; Default = $false; StateVar = "SelectSkillFrontendSlides" },
                [pscustomobject]@{ Label = "ppt-master"; Description = "Native editable PPTX generation with live preview"; Default = $false; StateVar = "SelectSkillPptMaster" }
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
                'SelectSkillPptMaster' { if ($selected) { $skillsSelected = $true } }
                'SelectAiTokenization' { if ($selected) { $skillsSelected = $true } }
                'SelectAiFineTuning' { if ($selected) { $skillsSelected = $true } }
                'SelectAiPostTraining' { if ($selected) { $skillsSelected = $true } }
                'SelectAiDistributedTraining' { if ($selected) { $skillsSelected = $true } }
                'SelectAiInferenceServing' { if ($selected) { $skillsSelected = $true } }
                'SelectAiOptimization' { if ($selected) { $skillsSelected = $true } }
                'SelectAiDeepXiv' { if ($selected) { $skillsSelected = $true } }
                'SelectAiResearchStudio' { if ($selected) { $skillsSelected = $true } }
                'SelectAiResearchStudioReel' { if ($selected) { $skillsSelected = $true } }
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
    $leaf = Split-Path $Path -Leaf
    $mappedNames = @{
        "peft" = "peft-fine-tuning"
        "openrlhf" = "openrlhf-training"
        "simpo" = "simpo-training"
        "trl-fine-tuning" = "fine-tuning-with-trl"
        "verl" = "verl-rl-training"
        "megatron-core" = "training-llms-megatron"
        "awq" = "awq-quantization"
        "gguf" = "gguf-quantization"
        "flash-attention" = "optimizing-attention-flash"
        "bitsandbytes" = "quantizing-models-bitsandbytes"
        "vllm" = "serving-llms-vllm"
    }
    if ($mappedNames.ContainsKey($leaf)) {
        return $mappedNames[$leaf]
    }
    return $leaf
}

function Test-InstalledSkill {
    param([string]$Skill)
    return (Test-Path -LiteralPath (Join-Path $CODEX_DIR "skills/$Skill/SKILL.md") -PathType Leaf)
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

    if ($Skill -ceq "code-review" -or
        (Test-SkillInList $Skill $MATTPOCOCK_SKILLS) -or
        (Test-SkillInList $Skill $MATTPOCOCK_LEGACY_SKILLS)) {
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
    if ($Skill -ceq "ppt-master") {
        return "hugohe3/ppt-master"
    }
    if ($Skill -cmatch '^(huggingface-tokenizers|sentencepiece|axolotl|llama-factory|peft-fine-tuning|unsloth|grpo-rl-training|openrlhf-training|simpo-training|fine-tuning-with-trl|verl-rl-training|deepspeed|pytorch-fsdp2|training-llms-megatron|ray-train|awq-quantization|gptq|gguf-quantization|optimizing-attention-flash|quantizing-models-bitsandbytes|serving-llms-vllm|sglang|tensorrt-llm|llama-cpp)$') {
        return "zechenzhangAGI/AI-research-SKILLs"
    }
    if ($Skill -cmatch '^(deepxiv-cli|deepxiv-baseline-table|deepxiv-trending-digest)$') {
        return "DeepXiv/deepxiv_sdk"
    }
    if ((Test-SkillInList $Skill $RESEARCHSTUDIO_SKILLS) -or
        (Test-SkillInList $Skill $RESEARCHSTUDIO_REEL_SKILLS)) {
        return "microsoft/ResearchStudio"
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
                $codexPath = Join-Path $CODEX_DIR "skills/$name"
                if ((Test-ManagedSkillName $name) -and $expected -and
                    -not $expected.StartsWith("local:") -and $source -ceq $expected -and
                    (Test-Path -LiteralPath (Join-Path $codexPath "SKILL.md") -PathType Leaf) -and
                    (Test-DirectoryTreeEqual (Join-Path $AGENTS_SKILLS_DIR $name) $codexPath)) {
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

function Get-NpxSkillLockFingerprint {
    param([string]$Skill, [string]$ExpectedSource)

    if (-not (Test-Path -LiteralPath $GLOBAL_SKILL_LOCK_FILE -PathType Leaf)) {
        return $null
    }
    try {
        $lock = Get-Content -LiteralPath $GLOBAL_SKILL_LOCK_FILE -Raw | ConvertFrom-Json
        $property = @($lock.skills.PSObject.Properties | Where-Object { $_.Name -ceq $Skill } | Select-Object -First 1)
        if ($property.Count -ne 1) { return $null }
        $entry = $property[0].Value
        if ($entry.source -cne $ExpectedSource -or
            $entry.skillFolderHash -isnot [string] -or
            $entry.skillFolderHash.Length -eq 0) {
            return $null
        }
        return (@(
            [string]$entry.source,
            [string]$entry.skillFolderHash,
            [string]$entry.installedAt,
            [string]$entry.updatedAt
        ) | ConvertTo-Json -Compress)
    } catch {
        return $null
    }
}

function Test-NpxSkillVerifiedThisRun {
    param([string]$Skill)
    return @($script:NpxVerifiedSkillNames | Where-Object { $_ -ceq $Skill }).Count -gt 0
}

function Test-InstalledSkillNames {
    param([string[]]$SkillNames)

    $missing = @()
    foreach ($skill in $SkillNames) {
        $codexSkill = Join-Path $CODEX_DIR "skills/$skill/SKILL.md"
        if (-not (Test-Path -LiteralPath $codexSkill -PathType Leaf)) {
            $missing += $skill
        }
    }

    if ($missing.Count -gt 0) {
        Write-Warn "npx skills returned success but did not install: $($missing -join ', ')"
        return $false
    }
    return $true
}

function Sync-NpxSkillToCodex {
    param([string]$Skill)

    $source = Join-Path $AGENTS_SKILLS_DIR $Skill
    $target = Join-Path $CODEX_DIR "skills/$Skill"
    $temporaryTarget = "$target.tmp.$PID"
    if (-not (Test-ManagedSkillName $Skill)) {
        return $false
    }
    $sourceAvailable = (Test-Path -LiteralPath $source -PathType Container) -and
        (Test-Path -LiteralPath (Join-Path $source "SKILL.md") -PathType Leaf)
    if (-not $sourceAvailable) { return $false }
    try {
        $sourceItem = Get-Item -LiteralPath $source -Force
        if (($sourceItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            return $false
        }
        New-Item -ItemType Directory -Path (Join-Path $CODEX_DIR "skills") -Force | Out-Null
        Remove-Item -LiteralPath $temporaryTarget -Recurse -Force -ErrorAction SilentlyContinue
        Copy-Item -LiteralPath $source -Destination $temporaryTarget -Recurse -Force
        if (-not (Test-Path -LiteralPath (Join-Path $temporaryTarget "SKILL.md") -PathType Leaf)) {
            Remove-Item -LiteralPath $temporaryTarget -Recurse -Force -ErrorAction SilentlyContinue
            return $false
        }
        if (Test-Path -LiteralPath $target) {
            Remove-Item -LiteralPath $target -Recurse -Force
        }
        Move-Item -LiteralPath $temporaryTarget -Destination $target -Force
        return (Test-Path -LiteralPath (Join-Path $target "SKILL.md") -PathType Leaf)
    } catch {
        Remove-Item -LiteralPath $temporaryTarget -Recurse -Force -ErrorAction SilentlyContinue
        Write-Warn "Could not copy npx skill $Skill into ${target}: $($_.Exception.Message)"
        return $false
    }
}

function Remove-ManagedStagingSkill {
    param([string]$Skill)

    if (-not (Test-ManagedSkillName $Skill)) {
        return $false
    }
    $staging = Join-Path $AGENTS_SKILLS_DIR $Skill
    if (-not (Test-Path -LiteralPath $staging)) {
        return $true
    }
    try {
        $item = Get-Item -LiteralPath $staging -Force
        if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            cmd /c rmdir "$staging" | Out-Null
            if ($LASTEXITCODE -ne 0) { throw "failed to remove staging reparse point" }
        } else {
            Remove-Item -LiteralPath $staging -Recurse -Force
        }
        return $true
    } catch {
        Write-Warn "Could not remove the legacy staging copy: ${staging}: $($_.Exception.Message)"
        return $false
    }
}

function Remove-MattPocockSkillLockEntries {
    param([string[]]$SkillNames)

    if (-not (Test-Path -LiteralPath $GLOBAL_SKILL_LOCK_FILE -PathType Leaf)) {
        return $true
    }
    try {
        $lock = Get-Content -LiteralPath $GLOBAL_SKILL_LOCK_FILE -Raw | ConvertFrom-Json
        foreach ($skill in $SkillNames) {
            $property = $lock.skills.PSObject.Properties[$skill]
            if ($property -and $property.Value.source -ceq "mattpocock/skills") {
                $lock.skills.PSObject.Properties.Remove($skill)
            }
        }
        $tempLock = "$GLOBAL_SKILL_LOCK_FILE.tmp.$PID"
        $encoding = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText(
            $tempLock,
            (($lock | ConvertTo-Json -Depth 20) + [Environment]::NewLine),
            $encoding
        )
        Move-Item -LiteralPath $tempLock -Destination $GLOBAL_SKILL_LOCK_FILE -Force
        return $true
    } catch {
        Remove-Item -LiteralPath "$GLOBAL_SKILL_LOCK_FILE.tmp.$PID" -Force -ErrorAction SilentlyContinue
        return $false
    }
}

function Install-NpxSkillNames {
    param([string]$Repo, [string[]]$SkillNames)
    $script:NpxVerifiedSkillNames = @()

    if ($DryRun) {
        Write-Info "Would install via npx skills: ${Repo} -> $($SkillNames -join ', ')"
        return $true
    }

    $launcherArgs = Get-SkillsNpxLauncherArgs
    if (-not $launcherArgs) {
        return $false
    }

    $npxArgs = @($launcherArgs) + @("add", $Repo, "--global", "--agent", "codex", "--copy", "--yes", "--full-depth")
    foreach ($skill in $SkillNames) {
        $npxArgs += @("--skill", $skill)
    }

    $localSource = Test-Path -LiteralPath $Repo -PathType Container
    $beforeFingerprints = @{}
    if (-not $localSource) {
        foreach ($skill in $SkillNames) {
            $beforeFingerprints[$skill] = Get-NpxSkillLockFingerprint -Skill $skill -ExpectedSource $Repo
        }
    }

    $oldDoNotTrack = $env:DO_NOT_TRACK
    $env:DO_NOT_TRACK = "1"
    try {
        & npx @npxArgs 2>&1 | ForEach-Object { Write-Host $_ }
        $exitCode = $LASTEXITCODE
        # Pinned installer-owned snapshots use a local temporary checkout. The
        # caller performs an exact tree comparison before retaining ownership.
        if ($localSource) {
            $syncFailed = $false
            if ($exitCode -eq 0) {
                foreach ($skill in $SkillNames) {
                    $sourceSkill = @(Get-ChildItem -LiteralPath (Join-Path $Repo "skills") `
                        -Recurse -Filter "SKILL.md" -File |
                        Where-Object { $_.Directory.Name -ceq $skill })[0]
                    $sourceSkillDir = if ($sourceSkill) { $sourceSkill.Directory.FullName } else { $null }
                    if (-not $sourceSkillDir -or
                        -not (Test-DirectoryTreeEqual $sourceSkillDir (Join-Path $AGENTS_SKILLS_DIR $skill)) -or
                        -not (Sync-NpxSkillToCodex $skill)) {
                        $syncFailed = $true
                    }
                }
            } else {
                $syncFailed = $true
            }
            if ($exitCode -eq 0 -and -not $syncFailed -and (Test-InstalledSkillNames $SkillNames)) {
                $script:NpxVerifiedSkillNames = @($SkillNames)
                Add-ManagedSkillOwnership $SkillNames
                foreach ($skill in $SkillNames) {
                    [void](Remove-ManagedStagingSkill $skill)
                }
                return $true
            }
            return $false
        }

        $missingNames = @()
        foreach ($skill in $SkillNames) {
            $afterFingerprint = Get-NpxSkillLockFingerprint -Skill $skill -ExpectedSource $Repo
            if ((Test-Path -LiteralPath (Join-Path $AGENTS_SKILLS_DIR "$skill/SKILL.md") -PathType Leaf) -and
                $null -ne $afterFingerprint -and
                $afterFingerprint -cne $beforeFingerprints[$skill] -and
                (Sync-NpxSkillToCodex $skill)) {
                $script:NpxVerifiedSkillNames += $skill
            } else {
                $missingNames += $skill
            }
        }
        if ($script:NpxVerifiedSkillNames.Count -gt 0) {
            Add-ManagedSkillOwnership $script:NpxVerifiedSkillNames
            foreach ($skill in $script:NpxVerifiedSkillNames) {
                [void](Remove-ManagedStagingSkill $skill)
            }
        }
        if ($missingNames.Count -gt 0) {
            if ($exitCode -eq 0) {
                Write-Warn "npx returned success, but this run did not freshly verify skill files/source ownership: $($missingNames -join ', ')"
            }
            return $false
        }
        if ($exitCode -ne 0) {
            Write-Warn "npx returned non-zero, but every requested skill was freshly verified from $Repo"
        }
        return $script:NpxVerifiedSkillNames.Count -eq $SkillNames.Count
    } finally {
        if ($null -eq $oldDoNotTrack) {
            Remove-Item Env:DO_NOT_TRACK -ErrorAction SilentlyContinue
        } else {
            $env:DO_NOT_TRACK = $oldDoNotTrack
        }
    }
}

function Install-PptMaster {
    Write-Info "Installing PPT Master skill (runtime dependencies deferred until first use)..."
    if ($DryRun) {
        Write-Info "Would install the hugohe3/ppt-master skill for Codex without Python packages or browsers"
        return
    }

    if (-not (Install-NpxSkillNames "hugohe3/ppt-master" @("ppt-master"))) {
        Skip-UnsupportedItem "ppt-master" "npx skills install failed or source ownership could not be verified"
        return
    }

    Write-Ok "PPT Master skill installed for Codex (minimal install; runtime dependencies deferred)"
}

function Install-ResearchStudio {
    Write-Info "Installing ResearchStudio Idea skills from a full official checkout (runtime dependencies deferred)..."
    if ($DryRun) {
        Write-Info "Would clone $RESEARCHSTUDIO_REPO_URL, copy the three allowlisted ResearchStudio-Idea skills, and apply Codex instruction/path adaptation without installing runtime dependencies"
        return
    }
    if (-not (Get-Command "git" -ErrorAction SilentlyContinue)) {
        Write-Warn "Skipping ResearchStudio Idea: git is unavailable. Install Git and retry."
        $script:SKIPPED_COMPONENTS += "ResearchStudio Idea (git unavailable)"
        return
    }

    $checkout = Join-Path ([System.IO.Path]::GetTempPath()) ("researchstudio-idea-" + [guid]::NewGuid().ToString("N"))
    try {
        & git clone --depth 1 $RESEARCHSTUDIO_REPO_URL $checkout 2>&1 | ForEach-Object { Write-Host $_ }
        if ($LASTEXITCODE -ne 0) {
            Write-Warn "Skipping ResearchStudio Idea: official repository checkout failed."
            $script:SKIPPED_COMPONENTS += "ResearchStudio Idea (official checkout failed)"
            return
        }

        foreach ($skill in $RESEARCHSTUDIO_SKILLS) {
            $sourceDir = Join-Path $checkout "ResearchStudio-Idea/skills/$skill"
            $skillFile = Join-Path $sourceDir "SKILL.md"
            if (-not (Test-Path -LiteralPath $skillFile -PathType Leaf)) {
                Write-Warn "Skipping ResearchStudio Idea: official checkout did not contain $skillFile"
                $script:SKIPPED_COMPONENTS += "ResearchStudio Idea (missing source skill: $skill)"
                return
            }
        }
        $unexpectedLink = Get-ChildItem -LiteralPath (Join-Path $checkout "ResearchStudio-Idea/skills") -Recurse -Force |
            Where-Object { ($_.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0 } |
            Select-Object -First 1
        if ($unexpectedLink) {
            Write-Warn "Skipping ResearchStudio Idea: official checkout contains symlinks/reparse points; refusing an unexpected source shape."
            $script:SKIPPED_COMPONENTS += "ResearchStudio Idea (unexpected source links)"
            return
        }

        New-Item -ItemType Directory -Path (Join-Path $CODEX_DIR "skills") -Force | Out-Null
        foreach ($skill in $RESEARCHSTUDIO_SKILLS) {
            $sourceDir = Join-Path $checkout "ResearchStudio-Idea/skills/$skill"
            $destination = Join-Path $CODEX_DIR "skills/$skill"
            Remove-Item -LiteralPath $destination -Recurse -Force -ErrorAction SilentlyContinue
            Copy-Item -LiteralPath $sourceDir -Destination $destination -Recurse -Force
        }
    } catch {
        Write-Warn "Skipping ResearchStudio Idea: failed to copy the allowlisted skills: $_"
        $script:SKIPPED_COMPONENTS += "ResearchStudio Idea (copy failed)"
        return
    } finally {
        Remove-Item -LiteralPath $checkout -Recurse -Force -ErrorAction SilentlyContinue
    }

    Add-ManagedSkillOwnership $RESEARCHSTUDIO_SKILLS
    if ((Convert-ResearchStudioIdeaForCodex) -and (Test-ResearchStudioIdeaAdapter)) {
        Write-Ok "ResearchStudio Idea skills installed for Codex (minimal install; runtime dependencies deferred)"
    } else {
        Write-Warn "ResearchStudio Idea was copied, but its Codex instruction/path adaptation could not be verified. Rerun this selection to refresh the skill files."
        $script:SKIPPED_COMPONENTS += "ResearchStudio Idea Codex adapter (verification failed)"
    }
}

function Install-ResearchStudioReel {
    Write-Info "Installing ResearchStudio Reel skills from a full official checkout (runtime dependencies deferred)..."
    if ($DryRun) {
        Write-Info "Would clone $RESEARCHSTUDIO_REPO_URL and copy only the five allowlisted Reel skills without Python packages, browsers, or native tools"
        return
    }
    if (-not (Get-Command "git" -ErrorAction SilentlyContinue)) {
        Write-Warn "Skipping ResearchStudio Reel: git is unavailable. Install Git and retry."
        $script:SKIPPED_COMPONENTS += "ResearchStudio Reel (git unavailable)"
        return
    }

    $checkout = Join-Path ([System.IO.Path]::GetTempPath()) ("researchstudio-reel-" + [guid]::NewGuid().ToString("N"))
    try {
        & git clone --depth 1 $RESEARCHSTUDIO_REPO_URL $checkout 2>&1 | ForEach-Object { Write-Host $_ }
        if ($LASTEXITCODE -ne 0) {
            Write-Warn "Skipping ResearchStudio Reel: official repository checkout failed."
            $script:SKIPPED_COMPONENTS += "ResearchStudio Reel (official checkout failed)"
            return
        }

        foreach ($skill in $RESEARCHSTUDIO_REEL_SKILLS) {
            $sourceDir = Join-Path $checkout "ResearchStudio-Reel/skills/$skill"
            $skillFile = Join-Path $sourceDir "SKILL.md"
            if (-not (Test-Path -LiteralPath $skillFile -PathType Leaf)) {
                Write-Warn "Skipping ResearchStudio Reel: official checkout did not contain $skillFile"
                $script:SKIPPED_COMPONENTS += "ResearchStudio Reel (missing source skill: $skill)"
                return
            }
        }
        $unexpectedLink = Get-ChildItem -LiteralPath (Join-Path $checkout "ResearchStudio-Reel/skills") -Recurse -Force |
            Where-Object { ($_.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0 } |
            Select-Object -First 1
        if ($unexpectedLink) {
            Write-Warn "Skipping ResearchStudio Reel: official checkout contains symlinks/reparse points; refusing an unexpected source shape."
            $script:SKIPPED_COMPONENTS += "ResearchStudio Reel (unexpected source links)"
            return
        }

        New-Item -ItemType Directory -Path (Join-Path $CODEX_DIR "skills") -Force | Out-Null
        foreach ($skill in $RESEARCHSTUDIO_REEL_SKILLS) {
            $sourceDir = Join-Path $checkout "ResearchStudio-Reel/skills/$skill"
            $destination = Join-Path $CODEX_DIR "skills/$skill"
            Remove-Item -LiteralPath $destination -Recurse -Force -ErrorAction SilentlyContinue
            Copy-Item -LiteralPath $sourceDir -Destination $destination -Recurse -Force
        }
    } catch {
        Write-Warn "Skipping ResearchStudio Reel: failed to copy the allowlisted skills: $_"
        $script:SKIPPED_COMPONENTS += "ResearchStudio Reel (copy failed)"
        return
    } finally {
        Remove-Item -LiteralPath $checkout -Recurse -Force -ErrorAction SilentlyContinue
    }

    Add-ManagedSkillOwnership $RESEARCHSTUDIO_REEL_SKILLS
    Write-Ok "ResearchStudio Reel skills installed for Codex (minimal install; runtime dependencies deferred)"
}

function Install-MattPocockSkillNames {
    param([string[]]$SkillNames)

    if (-not (Remove-LegacyMattPocockSkills)) {
        Remove-ManagedSkillOwnership $SkillNames
        return $false
    }

    if ($DryRun) {
        Write-Info "Would install Matt Pocock $($script:MATTPOCOCK_VERSION) from commit $($script:MATTPOCOCK_COMMIT): $($SkillNames -join ', ')"
        return $true
    }

    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("mattpocock-skills." + [guid]::NewGuid().ToString("N"))
    $archive = Join-Path $tempDir "source.tar.gz"

    try {
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        $archiveUrl = "https://github.com/mattpocock/skills/archive/$($script:MATTPOCOCK_COMMIT).tar.gz"
        Invoke-WebRequest -Uri $archiveUrl -OutFile $archive -UseBasicParsing
        tar -xzf $archive -C $tempDir
        if ($LASTEXITCODE -ne 0) {
            throw "tar extraction failed with exit code $LASTEXITCODE"
        }

        $sourceDir = Get-ChildItem -LiteralPath $tempDir -Directory | Select-Object -First 1
        if (-not $sourceDir) {
            throw "pinned archive did not contain a repository root"
        }

        foreach ($skill in $SkillNames) {
            $matches = @(Get-ChildItem -LiteralPath (Join-Path $sourceDir.FullName "skills") `
                -Recurse -Filter "SKILL.md" -File | Where-Object { $_.Directory.Name -ceq $skill })
            if ($matches.Count -eq 0) {
                throw "pinned archive is missing requested skill: $skill"
            }
        }

        if (-not (Install-NpxSkillNames $sourceDir.FullName $SkillNames)) {
            Remove-ManagedSkillOwnership $SkillNames
            return $false
        }

        foreach ($skill in $SkillNames) {
            $sourceSkill = @(Get-ChildItem -LiteralPath (Join-Path $sourceDir.FullName "skills") `
                -Recurse -Filter "SKILL.md" -File | Where-Object { $_.Directory.Name -ceq $skill })[0].Directory.FullName
            $targetSkill = Join-Path $CODEX_DIR "skills/$skill"
            if (-not (Test-DirectoryTreeEqual $sourceSkill $targetSkill)) {
                Write-Warn "Installed Matt Pocock skill does not match pinned snapshot: $skill"
                Remove-ManagedSkillOwnership $SkillNames
                return $false
            }
        }
        if (-not (Remove-MattPocockSkillLockEntries $SkillNames)) {
            Write-Warn "Could not retire remote Matt Pocock lock entries after pinned installation"
            Remove-ManagedSkillOwnership $SkillNames
            return $false
        }
        return $true
    } catch {
        Remove-ManagedSkillOwnership $SkillNames
        Write-Warn "Could not install Matt Pocock $($script:MATTPOCOCK_VERSION): $($_.Exception.Message)"
        return $false
    } finally {
        Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
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
    Add-Names $script:SelectSkillPptMaster @("ppt-master")
    Add-Names $script:SelectSkillPaperReading @("paper-reading")
    Add-Names $script:SelectSkillHumanizer @("humanizer")
    Add-Names $script:SelectSkillHumanizerZh @("humanizer-zh")
    Add-Names $script:SelectSkillHandoff @("handoff")
    Add-Names $script:SelectSkillAdversarialReview @("adversarial-review")
    Add-Names $script:SelectSkillUpdate @("update")
    Add-Names $script:SelectAiTokenization @("huggingface-tokenizers", "sentencepiece")
    Add-Names $script:SelectAiFineTuning @("axolotl", "llama-factory", "peft-fine-tuning", "unsloth")
    Add-Names $script:SelectAiPostTraining @("grpo-rl-training", "openrlhf-training", "simpo-training", "fine-tuning-with-trl", "verl-rl-training")
    Add-Names $script:SelectAiDistributedTraining @("deepspeed", "pytorch-fsdp2", "training-llms-megatron", "ray-train")
    Add-Names $script:SelectAiInferenceServing @("serving-llms-vllm", "sglang", "tensorrt-llm", "llama-cpp")
    Add-Names $script:SelectAiOptimization @("awq-quantization", "gptq", "gguf-quantization", "optimizing-attention-flash", "quantizing-models-bitsandbytes")
    Add-Names $script:SelectAiDeepXiv @("deepxiv-cli", "deepxiv-baseline-table", "deepxiv-trending-digest")
    Add-Names $script:SelectAiResearchStudio $RESEARCHSTUDIO_SKILLS
    Add-Names $script:SelectAiResearchStudioReel $RESEARCHSTUDIO_REEL_SKILLS

    return @($selected | Sort-Object)
}

function Remove-NpxSkillNames {
    param([string[]]$SkillNames)
    if ($SkillNames.Count -eq 0) { return $true }

    if ($DryRun) {
        Write-Info "Would remove via npx skills for Codex: $($SkillNames -join ', ')"
        return $true
    }

    $launcherArgs = Get-SkillsNpxLauncherArgs
    if (-not $launcherArgs) {
        Write-Warn "npx not found; shared/global Codex skill associations could not be removed: $($SkillNames -join ', ')"
        $script:SKIPPED_COMPONENTS += "unselected managed skills (npx unavailable): $($SkillNames -join ', ')"
        return $false
    }

    $npxArgs = @($launcherArgs) + @("remove") + $SkillNames + @("--global", "--agent", "codex", "--yes")
    $oldDoNotTrack = $env:DO_NOT_TRACK
    $env:DO_NOT_TRACK = "1"
    try {
        & npx @npxArgs 2>&1 | ForEach-Object { Write-Host $_ }
        if ($LASTEXITCODE -ne 0) {
            Write-Warn "npx skills could not remove these Codex skills: $($SkillNames -join ', ')"
            $script:SKIPPED_COMPONENTS += "unselected managed skills (npx removal failed): $($SkillNames -join ', ')"
            return $false
        }
        return $true
    } finally {
        if ($null -eq $oldDoNotTrack) {
            Remove-Item Env:DO_NOT_TRACK -ErrorAction SilentlyContinue
        } else {
            $env:DO_NOT_TRACK = $oldDoNotTrack
        }
    }
}

function Test-LockedSkillSource {
    param([string]$Skill, [string]$ExpectedSource)

    if (-not (Test-Path -LiteralPath $GLOBAL_SKILL_LOCK_FILE -PathType Leaf)) {
        return $false
    }
    try {
        $lock = Get-Content -LiteralPath $GLOBAL_SKILL_LOCK_FILE -Raw | ConvertFrom-Json
        $property = $lock.skills.PSObject.Properties[$Skill]
        return ($property -and $property.Value.source -ceq $ExpectedSource)
    } catch {
        return $false
    }
}

function Remove-LegacyMattPocockSkills {
    Initialize-ManagedSkillOwnership

    $removable = @()
    foreach ($skill in $MATTPOCOCK_LEGACY_SKILLS) {
        if ($script:OwnedManagedSkills.Contains($skill) -or
            (Test-LockedSkillSource $skill "mattpocock/skills")) {
            $removable += $skill
        }
    }
    if ($removable.Count -eq 0) { return $true }

    if ($DryRun) {
        Write-Info "Would remove retired Matt Pocock skills from all agent associations: $($removable -join ', ')"
        return $true
    }

    $launcherArgs = Get-SkillsNpxLauncherArgs
    if (-not $launcherArgs) {
        Write-Warn "npx is unavailable; cannot safely migrate retired Matt Pocock skills: $($removable -join ', ')"
        return $false
    }

    # Omitting --agent targets every detected agent. skills@1.5.16 currently
    # rejects the documented wildcard value (`--agent '*'`).
    $npxArgs = @($launcherArgs) + @("remove") + $removable + @("--global", "--yes")
    $oldDoNotTrack = $env:DO_NOT_TRACK
    $env:DO_NOT_TRACK = "1"
    try {
        & npx @npxArgs 2>&1 | ForEach-Object { Write-Host $_ }
        if ($LASTEXITCODE -ne 0) {
            Write-Warn "npx skills could not migrate retired Matt Pocock skills: $($removable -join ', ')"
            return $false
        }
    } finally {
        if ($null -eq $oldDoNotTrack) {
            Remove-Item Env:DO_NOT_TRACK -ErrorAction SilentlyContinue
        } else {
            $env:DO_NOT_TRACK = $oldDoNotTrack
        }
    }

    foreach ($skill in $removable) {
        Remove-Item -LiteralPath (Join-Path $AGENTS_SKILLS_DIR $skill) -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath (Join-Path $CODEX_DIR "skills/$skill") -Recurse -Force -ErrorAction SilentlyContinue
    }
    if (-not (Remove-MattPocockSkillLockEntries $removable)) {
        Write-Warn "Could not retire matching lock entries for retired Matt Pocock skills: $($removable -join ', ')"
        return $false
    }
    Remove-ManagedSkillOwnership $removable
    Write-Ok "Removed retired Matt Pocock skills: $($removable -join ', ')"
    return $true
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

    Remove-LegacySuperPowersLink
    if (Test-Path $SUPERPOWERS_DIR) {
        Remove-Item -Recurse -Force $SUPERPOWERS_DIR
        Write-Ok "Removed superpowers repository"
    }
}

function Sync-InteractiveSkills {
    $desired = @(Get-SelectedManagedSkills)
    $stale = @()
    $removedStale = @()

    Initialize-ManagedSkillOwnership
    if (-not (Remove-LegacyMattPocockSkills)) {
        Write-Warn "Retired Matt Pocock skills were preserved because migration cleanup failed"
    }

    foreach ($skill in @($script:OwnedManagedSkills)) {
        if (Test-SkillInList $skill $MATTPOCOCK_LEGACY_SKILLS) { continue }
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

        $npxStale = @()
        $directStale = @()
        $researchStudioRemoved = $false
        foreach ($skill in $stale) {
            $expectedSource = Get-ExpectedSkillSource $skill
            if ((Test-SkillInList $skill $RESEARCHSTUDIO_SKILLS) -or
                (Test-SkillInList $skill $RESEARCHSTUDIO_REEL_SKILLS)) {
                $researchStudioRemoved = $true
            }
            if (($expectedSource -and $expectedSource.StartsWith("local:")) -or
                $expectedSource -ceq "microsoft/ResearchStudio") {
                $directStale += $skill
            } else {
                $npxStale += $skill
            }
        }

        if ($npxStale.Count -gt 0) {
            $npxRemovalSucceeded = $false
            $npxRemovalSucceeded = [bool](Remove-NpxSkillNames $npxStale)
            if ($npxRemovalSucceeded -and -not $DryRun) {
                $stagingCleanupFailed = $false
                foreach ($skill in $npxStale) {
                    Remove-Item -LiteralPath (Join-Path $CODEX_DIR "skills/$skill") -Recurse -Force -ErrorAction SilentlyContinue
                    if (-not (Remove-ManagedStagingSkill $skill)) { $stagingCleanupFailed = $true }
                }
                if ($stagingCleanupFailed) { $npxRemovalSucceeded = $false }
            }
            if ($npxRemovalSucceeded) {
                $removedStale += $npxStale
            }
        }

        foreach ($skill in $directStale) {
            $codexPath = Join-Path $CODEX_DIR "skills/$skill"
            if ($DryRun) {
                if (Test-Path $codexPath) {
                    Write-Info "Would remove unselected managed skill: $codexPath"
                }
            } elseif (Test-Path $codexPath) {
                try {
                    Remove-Item -Recurse -Force $codexPath
                    if (Remove-ManagedStagingSkill $skill) {
                        Write-Ok "Removed unselected managed skill: $skill"
                        $removedStale += $skill
                    } else {
                        Write-Warn "Could not remove the managed staging copy: $(Join-Path $AGENTS_SKILLS_DIR $skill)"
                        $script:SKIPPED_COMPONENTS += "unselected managed staging removal failed: $skill"
                    }
                } catch {
                    Write-Warn "Could not remove unselected managed skill: $skill"
                    $script:SKIPPED_COMPONENTS += "unselected managed skill removal failed: $skill"
                }
            } else {
                $removedStale += $skill
            }
        }
        $researchStudioEnv = Join-Path $CODEX_DIR "skills/.env"
        if ($researchStudioRemoved -and (Test-Path $researchStudioEnv -PathType Leaf)) {
            Write-Warn "Preserving $researchStudioEnv because it may contain user-managed ResearchStudio credentials; remove it manually if no other skill uses it"
        }
    }

    if (-not $script:SelectSkillSuperpowers -and (Test-SuperpowersOwnershipRecorded)) {
        Remove-SuperpowersFallback
    }

    if ($removedStale.Count -gt 0 -and -not $DryRun) {
        Remove-ManagedSkillOwnership $removedStale
    }
}

function Install-SkillPathsFallback {
    param([string]$Repo, [string[]]$Paths)

    if (-not (Test-Path $INSTALLER)) {
        Write-Warn "skill-installer not found at $INSTALLER"
        $script:SKIPPED_COMPONENTS += "skill pack from $Repo (no npx and fallback installer not found)"
        return $false
    }

    $py = Resolve-PythonCommand
    if (-not $py) {
        Write-Warn "No usable Python 3 found. Install Python 3 or set PYTHON to a working interpreter."
        $script:SKIPPED_COMPONENTS += "skill pack from $Repo (Python 3 not found)"
        return $false
    }

    $exe = $py[0]
    $pyArgs = @()
    if ($py.Count -gt 1) {
        $pyArgs = $py[1..($py.Count - 1)]
    }
    $installedNames = @()
    $failed = $false
    foreach ($path in $Paths) {
        $skillName = Get-SkillNameFromPath $path
        Initialize-ManagedSkillOwnership
        $stagingWasOwned = $script:OwnedManagedSkills.Contains($skillName)
        & $exe @pyArgs $INSTALLER --repo $Repo --path $path --name $skillName 2>&1 |
            ForEach-Object { Write-Host $_ }
        $exitCode = $LASTEXITCODE
        $codexLocalSkill = Join-Path $CODEX_DIR "skills/$skillName/SKILL.md"
        if ($exitCode -eq 0 -and (Test-Path -LiteralPath $codexLocalSkill -PathType Leaf)) {
            $installedNames += $skillName
            if ($stagingWasOwned) {
                [void](Remove-ManagedStagingSkill $skillName)
            }
        } else {
            Write-Warn "Could not install $skillName from $Repo path $path"
            $failed = $true
        }
    }
    if ($installedNames.Count -gt 0) {
        Add-ManagedSkillOwnership $installedNames
    }
    if ($failed) {
        $script:SKIPPED_COMPONENTS += "skill pack from $Repo (fallback installer incomplete)"
        return $false
    }
    return $true
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

    $fallbackPaths = @()
    $verifiedNames = @()
    for ($index = 0; $index -lt $Paths.Count; $index++) {
        if (Test-NpxSkillVerifiedThisRun -Skill $names[$index]) {
            $verifiedNames += $names[$index]
        } else {
            $fallbackPaths += $Paths[$index]
        }
    }
    if ($verifiedNames.Count -gt 0) {
        Add-ManagedSkillOwnership $verifiedNames
    }
    if ($fallbackPaths.Count -eq 0) {
        Write-Ok "All requested skills have verified source provenance despite the npx non-zero result: $($names -join ', ') ($Repo)"
        return
    }

    Write-Warn "npx skills install left $($fallbackPaths.Count) source-unverified skill(s); trying the Python fallback for those paths from $Repo"
    $fallbackSucceeded = Install-SkillPathsFallback $Repo $fallbackPaths
    if ($fallbackSucceeded) {
        Write-Ok "Installed requested skills with the Python fallback: $Repo"
    }
}

function Reinstall-SkillPaths {
    param([string]$Repo, [string[]]$Paths)

    foreach ($path in $Paths) {
        $skill = Get-SkillNameFromPath $path
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

function Remove-LegacySuperPowersLink {
    $item = Get-Item -LiteralPath $LEGACY_SUPERPOWERS_LINK -Force -ErrorAction SilentlyContinue
    if (-not $item) { return }
    $isReparsePoint = ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0
    if ($isReparsePoint) {
        try {
            $legacyTarget = (Resolve-Path -LiteralPath $LEGACY_SUPERPOWERS_LINK -ErrorAction Stop).Path
            $managedTarget = (Resolve-Path -LiteralPath (Join-Path $SUPERPOWERS_DIR "skills") -ErrorAction Stop).Path
            if ($legacyTarget -ne $managedTarget) {
                Write-Warn "Preserving unrecognized legacy superpowers path: $LEGACY_SUPERPOWERS_LINK"
                return
            }
        } catch {
            Write-Warn "Could not verify legacy superpowers staging link: $LEGACY_SUPERPOWERS_LINK"
            return
        }
        cmd /c rmdir "$LEGACY_SUPERPOWERS_LINK" | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Ok "Removed legacy superpowers staging link"
        } else {
            Write-Warn "Could not remove legacy superpowers staging link: $LEGACY_SUPERPOWERS_LINK"
        }
    } else {
        Write-Warn "Preserving unrecognized legacy superpowers path: $LEGACY_SUPERPOWERS_LINK"
    }
}

function Skip-UnsupportedItem {
    param([string]$Item, [string]$Reason)
    Write-Warn "Could not install ${Item}: $Reason"
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
        Remove-LegacySuperPowersLink
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

    New-Item -ItemType Directory -Path (Join-Path $CODEX_DIR "skills") -Force | Out-Null

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
    Remove-LegacySuperPowersLink
}

function Install-LocalSkills {
    $skillsDir = Join-Path $script:SCRIPT_DIR "skills"
    if (-not (Test-Path $skillsDir)) { return }

    Initialize-ManagedSkillOwnership

    Get-ChildItem -Path $skillsDir -Directory |
        Where-Object { $_.Name -ne "adversarial-review" } |
        ForEach-Object {
        $skill = $_.Name
        $dest  = Join-Path $CODEX_DIR "skills/$skill"
        $stagingWasOwned = $script:OwnedManagedSkills.Contains($skill)
        if ($DryRun) {
            Write-Info "Would copy: skills/$skill/ -> $dest/"
        } else {
            New-Item -ItemType Directory -Path (Join-Path $CODEX_DIR "skills") -Force | Out-Null
            if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
            Copy-Item -Recurse $_.FullName $dest
            if ($stagingWasOwned) {
                [void](Remove-ManagedStagingSkill $skill)
            }
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
        if (-not (Install-MattPocockSkillNames @("code-review"))) {
            Skip-UnsupportedItem "code-review" "npx skills install failed; use Codex /review as the native fallback"
        }

        if (-not (Install-NpxSkillNames "forrestchang/andrej-karpathy-skills" @("karpathy-guidelines"))) {
            Skip-UnsupportedItem "andrej-karpathy-skills" "npx skills install failed"
        }

        Install-Superpowers

        if (Install-MattPocockSkillNames $MATTPOCOCK_SKILLS) {
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
        if ($script:PptMasterNonInteractiveRequested) {
            Install-PptMaster
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

        if ($script:ResearchStudioNonInteractiveRequested) {
            Install-ResearchStudio
        }
        if ($script:ResearchStudioReelNonInteractiveRequested) {
            Install-ResearchStudioReel
        }
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
                Initialize-ManagedSkillOwnership
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
                foreach ($skill in @($script:OwnedManagedSkills)) {
                    [void](Remove-ManagedStagingSkill $skill)
                }
                Remove-LegacySuperPowersLink
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

    if ($script:SKIPPED_COMPONENTS.Count -gt 0) {
        Write-Host ""
        Write-Warn "Install finished, but some components were skipped:"
        foreach ($comp in $script:SKIPPED_COMPONENTS) {
            Write-Warn "  - $comp"
        }
        Write-Warn "Resolve the issues above and re-run the installer to complete them."
        Write-Warn "The installed-version stamp was not updated."
    } else {
        Set-VersionStamp
        Write-Ok "All selected components installed."
    }

    Show-MattPocockQuickstart
    if ($script:SKIPPED_COMPONENTS.Count -gt 0) {
        Write-Warn "Done with incomplete components. Restart Codex after resolving and rerunning the installer."
        exit 1
    } else {
        Write-Ok "Done. Restart Codex to load new skills/config if needed."
    }
} finally {
    Remove-TempDir
}
