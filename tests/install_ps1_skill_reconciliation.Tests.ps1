#Requires -Version 5.1
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$installerPath = Join-Path $repoRoot "install.ps1"

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )
    if (-not $Condition) {
        throw $Message
    }
}

function Get-FunctionText {
    param(
        [string]$Path,
        [string]$Name
    )

    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile(
        $Path,
        [ref]$tokens,
        [ref]$errors
    )
    if ($errors.Count -gt 0) {
        throw "Failed to parse ${Path}: $($errors[0].Message)"
    }

    $functionAst = $ast.Find({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
            $node.Name -eq $Name
    }, $true)

    if (-not $functionAst) {
        return $null
    }

    return $functionAst.Extent.Text
}

foreach ($name in @(
    "Get-SelectedManagedSkills",
    "Remove-NpxSkillNames",
    "Remove-SuperpowersFallback",
    "Sync-InteractiveSkills"
)) {
    $functionText = Get-FunctionText -Path $installerPath -Name $name
    Assert-True ($null -ne $functionText) "install.ps1 should define $name"
    Invoke-Expression $functionText
}

function Write-Info { param($Message) }
function Write-Ok { param($Message) }
function Write-Warn { param($Message) }

$MANAGED_SKILLS = @("humanizer", "humanizer-zh", "handoff", "pua")
$SUPERPOWERS_SKILLS = @("brainstorming")
$MATTPOCOCK_SKILLS = @("ask-matt")
$PUA_SKILLS = @("pua", "pua-en", "pua-ja")
$script:SKIPPED_COMPONENTS = @()

$script:SelectSkillSuperpowers = $false
$script:SelectSkillDocumentSkills = $false
$script:SelectSkillExampleSkills = $false
$script:SelectSkillFrontendDesign = $false
$script:SelectSkillKarpathy = $false
$script:SelectSkillMattPocock = $false
$script:SelectSkillCodeReview = $false
$script:SelectSkillPUA = $false
$script:SelectSkillFrontendSlides = $false
$script:SelectSkillPaperReading = $false
$script:SelectSkillHumanizer = $true
$script:SelectSkillHumanizerZh = $false
$script:SelectSkillHandoff = $false
$script:SelectSkillAdversarialReview = $false
$script:SelectSkillUpdate = $false
$script:SelectAiTokenization = $false
$script:SelectAiFineTuning = $false
$script:SelectAiPostTraining = $false
$script:SelectAiDistributedTraining = $false
$script:SelectAiInferenceServing = $false
$script:SelectAiOptimization = $false
$script:SelectAiDeepXiv = $false

$selected = @(Get-SelectedManagedSkills)
Assert-True ($selected -contains "humanizer") "selected local skill should be desired"
Assert-True (-not ($selected -contains "humanizer-zh")) "unselected local skill should be stale"

$script:SelectSkillHumanizer = $false
$script:SelectSkillHandoff = $true
$selected = @(Get-SelectedManagedSkills)
Assert-True ($selected -contains "handoff") "an explicitly selected handoff source should be retained"
$script:SelectSkillHandoff = $false

$tempDir = Join-Path $env:TEMP ("codex-skill-reconciliation-test-" + [guid]::NewGuid().ToString("N"))
$CODEX_DIR = Join-Path $tempDir ".codex"
$AGENTS_SKILLS_DIR = Join-Path $tempDir ".agents/skills"
$SUPERPOWERS_DIR = Join-Path $CODEX_DIR "superpowers"
$SUPERPOWERS_LINK = Join-Path $AGENTS_SKILLS_DIR "superpowers"
$oldPath = $env:PATH

try {
    New-Item -ItemType Directory -Path (Join-Path $CODEX_DIR "skills/pua") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $CODEX_DIR "skills/private-skill") -Force | Out-Null

    $DryRun = $true
    Sync-InteractiveSkills
    Assert-True (Test-Path (Join-Path $CODEX_DIR "skills/pua")) "dry-run should preserve a stale managed skill"
    Assert-True (Test-Path (Join-Path $CODEX_DIR "skills/private-skill")) "dry-run should preserve an unmanaged skill"

    $DryRun = $false
    $env:PATH = $tempDir
    Sync-InteractiveSkills
    Assert-True (-not (Test-Path (Join-Path $CODEX_DIR "skills/pua"))) "reconciliation should remove a stale managed skill"
    Assert-True (Test-Path (Join-Path $CODEX_DIR "skills/private-skill")) "reconciliation should preserve an unmanaged skill"
} finally {
    $env:PATH = $oldPath
    Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue
}

Write-Host "install.ps1 skill reconciliation tests passed"
