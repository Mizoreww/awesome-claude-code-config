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
    "Test-SkillInList",
    "Test-ManagedSkillName",
    "Get-ExpectedSkillSource",
    "Test-DirectoryTreeEqual",
    "Test-SuperpowersFallbackOwned",
    "Test-SuperpowersOwnershipRecorded",
    "Save-ManagedSkillOwnership",
    "Initialize-ManagedSkillOwnership",
    "Add-ManagedSkillOwnership",
    "Remove-ManagedSkillOwnership",
    "Confirm-EmptySkillRemoval",
    "Get-SelectedManagedSkills",
    "Get-NodeMajorVersion",
    "Get-SkillsNpxLauncherArgs",
    "Remove-NpxSkillNames",
    "Remove-SuperpowersFallback",
    "Sync-InteractiveSkills",
    "Show-MattPocockQuickstart"
)) {
    $functionText = Get-FunctionText -Path $installerPath -Name $name
    Assert-True ($null -ne $functionText) "install.ps1 should define $name"
    Invoke-Expression $functionText
}

function Write-Info { param($Message) }
function Write-Ok { param($Message) }
function Write-Warn { param($Message) }

$MANAGED_SKILLS = @("humanizer", "humanizer-zh", "handoff", "pua", "brainstorming", "frontend-slides", "ppt-master")
$SUPERPOWERS_SKILLS = @("brainstorming")
$MATTPOCOCK_SKILLS = @("ask-matt")
$PUA_SKILLS = @("pua", "pua-en", "pua-ja")
$LOCAL_MANAGED_SKILLS = @("humanizer", "humanizer-zh", "handoff")
$LEGACY_CLEANUP_SKILLS = @()
$OWNERSHIP_SKILLS = @($MANAGED_SKILLS)
$script:SKIPPED_COMPONENTS = @()
$script:SKILLS_MIN_NODE_MAJOR = 20
$script:SKILLS_NODE_FALLBACK_VERSION = "24"
$script:SkillsNodeFallbackNotified = $false
$script:SCRIPT_DIR = $repoRoot
$script:MattPocockQuickstartReady = $true
$DryRun = $false

$quickstart = @(Show-MattPocockQuickstart) -join "`n"
Assert-True ($quickstart -like "*Matt Pocock skills quickstart (30-second setup)*") "quickstart heading should be present"
Assert-True ($quickstart -like "*/skills*") "quickstart should explain /skills"
Assert-True ($quickstart -like "*press @*") "quickstart should explain the @ shortcut"
Assert-True ($quickstart -like "*setup-matt-pocock-skills*") "quickstart should name the setup skill"
Assert-True ($quickstart -like "*not individual root slash commands*") "quickstart should explain root slash behavior"

$DryRun = $true
Assert-True (@(Show-MattPocockQuickstart).Count -eq 0) "dry-run should not display the installed quickstart"
$DryRun = $false

$script:SelectSkillSuperpowers = $false
$script:SelectSkillDocumentSkills = $false
$script:SelectSkillExampleSkills = $false
$script:SelectSkillFrontendDesign = $false
$script:SelectSkillKarpathy = $false
$script:SelectSkillMattPocock = $false
$script:SelectSkillCodeReview = $false
$script:SelectSkillPUA = $false
$script:SelectSkillFrontendSlides = $false
$script:SelectSkillPptMaster = $false
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
$script:SelectAiResearchStudio = $false
$script:SelectAiResearchStudioReel = $false
$RESEARCHSTUDIO_SKILLS = @("idea_spark", "paper_search", "scoop_check")
$RESEARCHSTUDIO_REEL_SKILLS = @("paper2assets", "paper2poster", "paper2video", "paper2blog", "paper2reel")

$selected = @(Get-SelectedManagedSkills)
Assert-True ($selected -contains "humanizer") "selected local skill should be desired"
Assert-True (-not ($selected -contains "humanizer-zh")) "unselected local skill should be stale"

$script:SelectSkillHumanizer = $false
$script:SelectSkillHandoff = $true
$selected = @(Get-SelectedManagedSkills)
Assert-True ($selected -contains "handoff") "an explicitly selected handoff source should be retained"
$script:SelectSkillHandoff = $false

$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("codex-skill-reconciliation-test-" + [guid]::NewGuid().ToString("N"))
$CODEX_DIR = Join-Path $tempDir ".codex"
$AGENTS_SKILLS_DIR = Join-Path $tempDir ".agents/skills"
$SUPERPOWERS_DIR = Join-Path $CODEX_DIR "superpowers"
$SUPERPOWERS_LINK = Join-Path $AGENTS_SKILLS_DIR "superpowers"
$MANAGED_SKILLS_STATE_FILE = Join-Path $CODEX_DIR ".awesome-claude-code-config-managed-skills"
$GLOBAL_SKILL_LOCK_FILE = Join-Path $tempDir ".agents/.skill-lock.json"
$script:ManagedSkillOwnershipLoaded = $false
$script:OwnedManagedSkills = New-Object 'System.Collections.Generic.HashSet[string]'
$Force = $true
$oldPath = $env:PATH
$script:NpxCalls = @()

function npx {
    $script:NpxCalls += ,@($args)
    $global:LASTEXITCODE = 0
}

try {
    New-Item -ItemType Directory -Path (Join-Path $CODEX_DIR "skills/pua") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $CODEX_DIR "skills/handoff") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $CODEX_DIR "skills/private-skill") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $AGENTS_SKILLS_DIR "pua") -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $CODEX_DIR "skills/pua/SKILL.md") -Value "managed"
    Set-Content -LiteralPath (Join-Path $AGENTS_SKILLS_DIR "pua/SKILL.md") -Value "managed"
    [System.IO.File]::WriteAllLines($MANAGED_SKILLS_STATE_FILE, @("pua"))

    $DryRun = $true
    Sync-InteractiveSkills
    Assert-True (Test-Path (Join-Path $CODEX_DIR "skills/pua")) "dry-run should preserve a stale managed skill"
    Assert-True (Test-Path (Join-Path $CODEX_DIR "skills/private-skill")) "dry-run should preserve an unmanaged skill"

    $DryRun = $false
    Sync-InteractiveSkills
    Assert-True (-not (Test-Path (Join-Path $CODEX_DIR "skills/pua"))) "reconciliation should remove a stale managed skill"
    Assert-True (Test-Path (Join-Path $CODEX_DIR "skills/handoff")) "a same-name skill without installer ownership should be preserved"
    Assert-True (Test-Path (Join-Path $CODEX_DIR "skills/private-skill")) "reconciliation should preserve an unmanaged skill"
    Assert-True (Test-Path (Join-Path $AGENTS_SKILLS_DIR "pua")) "reconciliation should preserve shared agent skills"
    Assert-True ($script:NpxCalls.Count -eq 1) "reconciliation should invoke npx once"
    Assert-True ($script:NpxCalls[0] -contains "--global") "npx removal should be global"
    Assert-True ($script:NpxCalls[0] -contains "codex") "npx removal should be Codex-scoped"

    # Legacy lock provenance alone is insufficient: the Codex copy must match
    # the canonical copy before ownership is adopted.
    Remove-Item -Force $MANAGED_SKILLS_STATE_FILE -ErrorAction SilentlyContinue
    $script:ManagedSkillOwnershipLoaded = $false
    $script:OwnedManagedSkills = New-Object 'System.Collections.Generic.HashSet[string]'
    $canonical = Join-Path $AGENTS_SKILLS_DIR "frontend-slides"
    $codexCopy = Join-Path $CODEX_DIR "skills/frontend-slides"
    New-Item -ItemType Directory -Path $canonical, $codexCopy -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $canonical "SKILL.md") -Value "upstream"
    Set-Content -LiteralPath (Join-Path $codexCopy "SKILL.md") -Value "custom"
    New-Item -ItemType Directory -Path (Split-Path $GLOBAL_SKILL_LOCK_FILE -Parent) -Force | Out-Null
    Set-Content -LiteralPath $GLOBAL_SKILL_LOCK_FILE -Value '{"version":3,"skills":{"frontend-slides":{"source":"zarazhangrui/frontend-slides"}}}'
    Initialize-ManagedSkillOwnership
    Assert-True (-not $script:OwnedManagedSkills.Contains("frontend-slides")) "mismatched same-name copy should not be adopted"

    Remove-Item -Force $MANAGED_SKILLS_STATE_FILE -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force $codexCopy
    Copy-Item -Recurse $canonical $codexCopy
    $script:ManagedSkillOwnershipLoaded = $false
    $script:OwnedManagedSkills = New-Object 'System.Collections.Generic.HashSet[string]'
    Initialize-ManagedSkillOwnership
    Assert-True ($script:OwnedManagedSkills.Contains("frontend-slides")) "matching lock/canonical copy should be adopted"
} finally {
    $env:PATH = $oldPath
    Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue
}

Write-Host "install.ps1 skill reconciliation tests passed"
