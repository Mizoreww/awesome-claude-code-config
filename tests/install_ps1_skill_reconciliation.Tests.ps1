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
    "Get-GlobalSkillLockFile",
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
    "Get-NpxSkillLockFingerprint",
    "Test-NpxSkillVerifiedThisRun",
    "Test-InstalledSkillNames",
    "Remove-MattPocockSkillLockEntries",
    "Install-NpxSkillNames",
    "Install-MattPocockSkillNames",
    "Get-SelectedManagedSkills",
    "Get-NodeMajorVersion",
    "Get-SkillsNpxLauncherArgs",
    "Remove-NpxSkillNames",
    "Test-LockedSkillSource",
    "Remove-LegacyMattPocockSkills",
    "Remove-SuperpowersFallback",
    "Sync-InteractiveSkills",
    "Show-MattPocockQuickstart"
)) {
    $functionText = Get-FunctionText -Path $installerPath -Name $name
    Assert-True ($null -ne $functionText) "install.ps1 should define $name"
    Invoke-Expression $functionText
}
$realRemoveMattPocockSkillLockEntries =
    (Get-Item Function:\Remove-MattPocockSkillLockEntries).ScriptBlock

$lockPathFixture = Join-Path ([System.IO.Path]::GetTempPath()) "codex-lock-path-fixture"
$xdgLockPath = Get-GlobalSkillLockFile `
    -HomePath (Join-Path $lockPathFixture "home") `
    -XdgStateHome (Join-Path $lockPathFixture "state")
Assert-True `
    ($xdgLockPath -ceq (Join-Path $lockPathFixture "state/skills/.skill-lock.json")) `
    "global skill lock path should honor XDG_STATE_HOME"
$homeLockPath = Get-GlobalSkillLockFile `
    -HomePath (Join-Path $lockPathFixture "home") `
    -XdgStateHome ""
Assert-True `
    ($homeLockPath -ceq (Join-Path $lockPathFixture "home/.agents/.skill-lock.json")) `
    "global skill lock path should fall back to HOME"

function Write-Info { param($Message) }
function Write-Ok { param($Message) }
function Write-Warn { param($Message) }

$MANAGED_SKILLS = @(
    "humanizer", "humanizer-zh", "handoff", "pua", "brainstorming", "frontend-slides", "ppt-master",
    "ask-matt", "diagnosing-bugs", "grill-with-docs", "triage", "implement",
    "improve-codebase-architecture", "setup-matt-pocock-skills", "tdd",
    "to-spec", "to-tickets", "wayfinder", "prototype", "domain-modeling",
    "codebase-design", "grill-me", "grilling", "research", "teach", "writing-great-skills"
)
$SUPERPOWERS_SKILLS = @("brainstorming")
$MATTPOCOCK_SKILLS = @(
    "ask-matt", "diagnosing-bugs", "grill-with-docs", "triage", "implement",
    "improve-codebase-architecture", "setup-matt-pocock-skills", "tdd",
    "to-spec", "to-tickets", "wayfinder", "prototype", "domain-modeling",
    "codebase-design", "grill-me", "grilling", "research", "teach", "writing-great-skills"
)
$MATTPOCOCK_LEGACY_SKILLS = @("to-issues", "to-prd", "decision-mapping", "review")
$PUA_SKILLS = @("pua", "pua-en", "pua-ja")
$LOCAL_MANAGED_SKILLS = @("humanizer", "humanizer-zh", "handoff")
$LEGACY_CLEANUP_SKILLS = @()
$OWNERSHIP_SKILLS = @($MANAGED_SKILLS) + @($MATTPOCOCK_LEGACY_SKILLS)
$script:SKIPPED_COMPONENTS = @()
$script:SKILLS_MIN_NODE_MAJOR = 20
$script:SKILLS_NODE_FALLBACK_VERSION = "24"
$script:SkillsNodeFallbackNotified = $false
$script:SCRIPT_DIR = $repoRoot
$script:MattPocockQuickstartReady = $true
$script:MATTPOCOCK_VERSION = "v1.1.0"
$script:MATTPOCOCK_COMMIT = "d574778f94cf620fcc8ce741584093bc650a61d3"
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

$script:SelectSkillMattPocock = $true
$selected = @(Get-SelectedManagedSkills)
foreach ($skill in @("to-spec", "to-tickets", "wayfinder")) {
    Assert-True ($selected -contains $skill) "Matt Pocock selection is missing v1.1 skill: $skill"
}
foreach ($skill in $MATTPOCOCK_LEGACY_SKILLS) {
    Assert-True (-not ($selected -contains $skill)) "Matt Pocock selection still exposes retired skill: $skill"
}
$script:SelectSkillMattPocock = $false

$selected = @(Get-SelectedManagedSkills)
Assert-True ($selected -contains "humanizer") "selected local skill should be desired"
Assert-True (-not ($selected -contains "humanizer-zh")) "unselected local skill should be stale"

$script:SelectSkillHumanizer = $false
$script:SelectSkillHandoff = $true
$selected = @(Get-SelectedManagedSkills)
Assert-True ($selected -contains "handoff") "an explicitly selected handoff source should be retained"
$script:SelectSkillHandoff = $false

$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("codex-skill-reconciliation-test-" + [guid]::NewGuid().ToString("N"))
$oldXdgStateHome = $env:XDG_STATE_HOME
$env:XDG_STATE_HOME = Join-Path $tempDir "xdg-state"
$CODEX_DIR = Join-Path $tempDir ".codex"
$AGENTS_SKILLS_DIR = Join-Path $tempDir ".agents/skills"
$SUPERPOWERS_DIR = Join-Path $CODEX_DIR "superpowers"
$SUPERPOWERS_LINK = Join-Path $AGENTS_SKILLS_DIR "superpowers"
$MANAGED_SKILLS_STATE_FILE = Join-Path $CODEX_DIR ".awesome-claude-code-config-managed-skills"
$GLOBAL_SKILL_LOCK_FILE = Get-GlobalSkillLockFile `
    -HomePath $HOME `
    -XdgStateHome $env:XDG_STATE_HOME
$script:ManagedSkillOwnershipLoaded = $false
$script:OwnedManagedSkills = New-Object 'System.Collections.Generic.HashSet[string]'
$Force = $true
$oldPath = $env:PATH
$script:NpxCalls = @()

function npx {
    $script:NpxCalls += ,@($args)
    $isAdd = $args -contains "add"
    $isRemove = $args -contains "remove"
    if ($isAdd) {
        for ($i = 0; $i -lt $args.Count - 1; $i++) {
            if ($args[$i] -ceq "--skill") {
                $skill = $args[$i + 1]
                if ($skill -cne $script:NpxSkipSkill) {
                    $skillDir = Join-Path $AGENTS_SKILLS_DIR $skill
                    New-Item -ItemType Directory -Path $skillDir -Force | Out-Null
                    Set-Content -LiteralPath (Join-Path $skillDir "SKILL.md") -Value "name: $skill"
                }
            }
        }
    }
    if ($isRemove -and $args -contains "*") {
        # skills@1.5.16 rejects the documented wildcard agent. The production
        # installer must omit --agent to target every agent.
        $global:LASTEXITCODE = 1
        return
    }
    $removeAllAgents = $isRemove -and -not ($args -contains "--agent")
    if ($isRemove) {
        $removeIndex = [Array]::IndexOf($args, "remove")
        for ($i = $removeIndex + 1; $i -lt $args.Count; $i++) {
            if ($args[$i].StartsWith("--")) { break }
            if ($removeAllAgents) {
                Remove-Item -LiteralPath (Join-Path $AGENTS_SKILLS_DIR $args[$i]) `
                    -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
    $global:LASTEXITCODE = 0
}

$script:DownloadUris = @()
function Invoke-WebRequest {
    param(
        [string]$Uri,
        [string]$OutFile,
        [switch]$UseBasicParsing
    )
    $script:DownloadUris += $Uri
    Set-Content -LiteralPath $OutFile -Value "fixture"
}

function tar {
    $destinationIndex = [Array]::IndexOf($args, "-C")
    if ($destinationIndex -lt 0) {
        $global:LASTEXITCODE = 1
        return
    }
    $destination = $args[$destinationIndex + 1]
    Copy-Item -LiteralPath $script:PinnedFixtureRoot -Destination $destination -Recurse
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

    # A successful npx exit must not hide a missing requested skill.
    Remove-Item -Force $MANAGED_SKILLS_STATE_FILE -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath (Join-Path $AGENTS_SKILLS_DIR "to-spec") -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath (Join-Path $AGENTS_SKILLS_DIR "to-tickets") -Recurse -Force -ErrorAction SilentlyContinue
    $script:ManagedSkillOwnershipLoaded = $false
    $script:OwnedManagedSkills = New-Object 'System.Collections.Generic.HashSet[string]'
    $script:NpxSkipSkill = "to-tickets"
    $partialResult = Install-NpxSkillNames "mattpocock/skills" @("to-spec", "to-tickets")
    Assert-True (-not $partialResult) "partial npx install should not report success"
    Assert-True (-not $script:OwnedManagedSkills.Contains("to-spec")) "partial install should not record ownership"
    Assert-True (-not $script:OwnedManagedSkills.Contains("to-tickets")) "missing skill should not record ownership"
    $script:NpxSkipSkill = $null

    # Retired Matt Pocock names are removed from the canonical shared path and
    # from ownership using all-agent cleanup.
    [System.IO.File]::WriteAllLines($MANAGED_SKILLS_STATE_FILE, @("to-prd", "to-issues"))
    $script:ManagedSkillOwnershipLoaded = $false
    $script:OwnedManagedSkills = New-Object 'System.Collections.Generic.HashSet[string]'
    foreach ($skill in @("to-prd", "to-issues")) {
        $skillDir = Join-Path $AGENTS_SKILLS_DIR $skill
        New-Item -ItemType Directory -Path $skillDir -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $skillDir "SKILL.md") -Value "legacy"
    }
    Set-Content -LiteralPath $GLOBAL_SKILL_LOCK_FILE -Value '{"version":3,"skills":{"to-prd":{"source":"mattpocock/skills"},"to-issues":{"source":"mattpocock/skills"},"custom-skill":{"source":"user/custom-skills"}}}'
    $legacyResult = Remove-LegacyMattPocockSkills
    Assert-True $legacyResult "legacy Matt Pocock cleanup should succeed"
    Assert-True (-not (Test-Path (Join-Path $AGENTS_SKILLS_DIR "to-prd"))) "to-prd should be removed"
    Assert-True (-not (Test-Path (Join-Path $AGENTS_SKILLS_DIR "to-issues"))) "to-issues should be removed"
    Assert-True (-not $script:OwnedManagedSkills.Contains("to-prd")) "to-prd ownership should be removed"
    Assert-True (-not $script:OwnedManagedSkills.Contains("to-issues")) "to-issues ownership should be removed"
    $lastNpxCall = $script:NpxCalls[-1]
    Assert-True (-not ($lastNpxCall -contains "*")) "legacy cleanup should not pass the CLI's invalid wildcard agent"
    Assert-True (-not ($lastNpxCall -contains "--agent")) "legacy cleanup should use default all-agent removal"
    $lockAfterLegacyCleanup = Get-Content -LiteralPath $GLOBAL_SKILL_LOCK_FILE -Raw | ConvertFrom-Json
    Assert-True (-not $lockAfterLegacyCleanup.skills.PSObject.Properties["to-prd"]) "to-prd lock should be retired"
    Assert-True (-not $lockAfterLegacyCleanup.skills.PSObject.Properties["to-issues"]) "to-issues lock should be retired"
    Assert-True ($lockAfterLegacyCleanup.skills.PSObject.Properties["custom-skill"].Value.source -ceq "user/custom-skills") "legacy cleanup should preserve unrelated locks"

    # Execute the pinned snapshot path itself: stale content must fail and
    # clear previous ownership; a matching snapshot must use the immutable
    # commit, install through a local source, and retire only matching locks.
    $script:PinnedFixtureRoot = Join-Path $tempDir "pinned-fixture/skills-test"
    foreach ($skill in @("ask-matt", "to-spec")) {
        $skillDir = Join-Path $script:PinnedFixtureRoot "skills/engineering/$skill"
        New-Item -ItemType Directory -Path $skillDir -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $skillDir "SKILL.md") -Value "name: $skill"
    }

    [System.IO.File]::WriteAllLines($MANAGED_SKILLS_STATE_FILE, @("ask-matt", "to-spec"))
    $script:ManagedSkillOwnershipLoaded = $false
    $script:OwnedManagedSkills = New-Object 'System.Collections.Generic.HashSet[string]'
    $staleSkill = Join-Path $AGENTS_SKILLS_DIR "to-spec"
    New-Item -ItemType Directory -Path $staleSkill -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $staleSkill "SKILL.md") -Value "stale"
    $script:NpxSkipSkill = "to-spec"
    $staleResult = Install-MattPocockSkillNames @("ask-matt", "to-spec")
    Assert-True (-not $staleResult) "stale Matt Pocock content should fail pinned installation"
    Assert-True (-not $script:OwnedManagedSkills.Contains("ask-matt")) "failed pinned install retained ask-matt ownership"
    Assert-True (-not $script:OwnedManagedSkills.Contains("to-spec")) "failed pinned install retained to-spec ownership"

    $script:NpxSkipSkill = $null
    Remove-Item -LiteralPath (Join-Path $AGENTS_SKILLS_DIR "ask-matt") -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath (Join-Path $AGENTS_SKILLS_DIR "to-spec") -Recurse -Force -ErrorAction SilentlyContinue
    Set-Content -LiteralPath $GLOBAL_SKILL_LOCK_FILE -Value '{"version":3,"skills":{"ask-matt":{"source":"mattpocock/skills"},"to-spec":{"source":"mattpocock/skills"},"custom-skill":{"source":"user/custom-skills"}}}'
    $script:NpxCalls = @()
    $pinnedResult = Install-MattPocockSkillNames @("ask-matt", "to-spec")
    Assert-True $pinnedResult "matching pinned Matt Pocock snapshot should install"
    Assert-True ($script:DownloadUris[-1] -like "*$($script:MATTPOCOCK_COMMIT)*") "archive URL should pin the release commit"
    $pinnedNpxCall = $script:NpxCalls[-1]
    Assert-True (-not ($pinnedNpxCall -contains "mattpocock/skills")) "pinned install should not pass mutable remote source to npx"
    Assert-True (@($pinnedNpxCall | Where-Object { $_ -like "*mattpocock-skills.*" }).Count -gt 0) "pinned install should use a local snapshot path"
    $lockAfterPinnedInstall = Get-Content -LiteralPath $GLOBAL_SKILL_LOCK_FILE -Raw | ConvertFrom-Json
    Assert-True (-not $lockAfterPinnedInstall.skills.PSObject.Properties["ask-matt"]) "ask-matt remote lock should be retired"
    Assert-True (-not $lockAfterPinnedInstall.skills.PSObject.Properties["to-spec"]) "to-spec remote lock should be retired"
    Assert-True ($lockAfterPinnedInstall.skills.PSObject.Properties["custom-skill"].Value.source -ceq "user/custom-skills") "unrelated lock should be preserved"

    # An exception after npx has recorded ownership must still fail closed and
    # clear every requested ownership record.
    Remove-ManagedSkillOwnership @("ask-matt", "to-spec")
    Remove-Item -LiteralPath (Join-Path $AGENTS_SKILLS_DIR "ask-matt") -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath (Join-Path $AGENTS_SKILLS_DIR "to-spec") -Recurse -Force -ErrorAction SilentlyContinue
    function Remove-MattPocockSkillLockEntries {
        param([string[]]$SkillNames)
        throw "injected lock cleanup failure"
    }
    try {
        $exceptionResult = Install-MattPocockSkillNames @("ask-matt", "to-spec")
        Assert-True (-not $exceptionResult) "lock cleanup exception should fail pinned installation"
        Assert-True (-not $script:OwnedManagedSkills.Contains("ask-matt")) "exception retained ask-matt ownership"
        Assert-True (-not $script:OwnedManagedSkills.Contains("to-spec")) "exception retained to-spec ownership"
    } finally {
        Set-Item -Path Function:\Remove-MattPocockSkillLockEntries `
            -Value $realRemoveMattPocockSkillLockEntries
    }

    $customReview = Join-Path $AGENTS_SKILLS_DIR "review"
    New-Item -ItemType Directory -Path $customReview -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $customReview "SKILL.md") -Value "custom"
    Set-Content -LiteralPath $GLOBAL_SKILL_LOCK_FILE -Value '{"version":3,"skills":{"review":{"source":"user/custom-skills"}}}'
    $customLegacyResult = Remove-LegacyMattPocockSkills
    Assert-True $customLegacyResult "custom legacy-name provenance check should succeed"
    Assert-True (Test-Path $customReview) "custom same-name skill should be preserved"
} finally {
    $env:PATH = $oldPath
    if ($null -eq $oldXdgStateHome) {
        Remove-Item Env:XDG_STATE_HOME -ErrorAction SilentlyContinue
    } else {
        $env:XDG_STATE_HOME = $oldXdgStateHome
    }
    Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue
}

Write-Host "install.ps1 skill reconciliation tests passed"
