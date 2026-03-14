#Requires -Version 5.1
<#
.SYNOPSIS
    Awesome Claude Code Configuration Installer (Windows)
.DESCRIPTION
    https://github.com/Mizoreww/awesome-claude-code-config
.EXAMPLE
    .\install.ps1                  # Interactive selector
    .\install.ps1 -All             # Install everything (non-interactive)
    .\install.ps1 -Uninstall       # Uninstall everything
    .\install.ps1 -DryRun          # Preview changes
    # Remote install:
    irm https://raw.githubusercontent.com/Mizoreww/awesome-claude-code-config/main/install.ps1 | iex
#>

param(
    [switch]$All,
    [switch]$Uninstall,
    [switch]$Version,
    [switch]$DryRun,
    [switch]$Force,
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$CLAUDE_DIR = Join-Path $env:USERPROFILE ".claude"
$REPO_URL = "https://github.com/Mizoreww/awesome-claude-code-config"
$VERSION_STAMP_FILE = Join-Path $CLAUDE_DIR ".awesome-claude-code-config-version"

# --- Colors ----------------------------------------------------------------

function Write-Info  { param([string]$Msg) Write-Host "[INFO] " -ForegroundColor Blue -NoNewline; Write-Host $Msg }
function Write-Ok    { param([string]$Msg) Write-Host "[OK] " -ForegroundColor Green -NoNewline; Write-Host $Msg }
function Write-Warn  { param([string]$Msg) Write-Host "[WARN] " -ForegroundColor Yellow -NoNewline; Write-Host $Msg }
function Write-Err   { param([string]$Msg) Write-Host "[ERROR] " -ForegroundColor Red -NoNewline; Write-Host $Msg }

# --- Retry wrapper ---------------------------------------------------------

function Invoke-Retry {
    param(
        [int]$MaxAttempts,
        [int]$DelaySeconds,
        [string]$Description,
        [scriptblock]$Action
    )
    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        try {
            & $Action
            return $true
        } catch {
            if ($attempt -lt $MaxAttempts) {
                Write-Warn "$Description failed (attempt $attempt/$MaxAttempts), retrying in ${DelaySeconds}s..."
                Start-Sleep -Seconds $DelaySeconds
            } else {
                Write-Warn "$Description failed after $MaxAttempts attempts, skipping."
            }
        }
    }
    return $false
}

# --- Remote install detection ----------------------------------------------

$SCRIPT_DIR = ""
$REMOTE_MODE = $false
$InstallWarnings = 0

function Initialize-ScriptDir {
    $script:SCRIPT_DIR = $PSScriptRoot

    if ($script:SCRIPT_DIR -and (Test-Path (Join-Path $script:SCRIPT_DIR "CLAUDE.md"))) {
        $script:REMOTE_MODE = $false
        return
    }

    # Remote mode: download zip to temp dir
    $script:REMOTE_MODE = $true
    $tmpdir = Join-Path ([System.IO.Path]::GetTempPath()) "claude-config-$(Get-Random)"
    New-Item -ItemType Directory -Path $tmpdir -Force | Out-Null

    $ver = if ($env:VERSION) { $env:VERSION } else { "main" }
    $zipUrl = "$REPO_URL/archive/refs/heads/$ver.zip"
    if ($ver -match '^v\d') {
        $zipUrl = "$REPO_URL/archive/refs/tags/$ver.zip"
    }

    Write-Info "Remote mode: downloading $ver..."
    $zipPath = Join-Path $tmpdir "source.zip"

    $ok = Invoke-Retry -MaxAttempts 5 -DelaySeconds 3 -Description "Download source zip" -Action {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing
    }
    if (-not $ok) {
        Write-Err "Failed to download source after retries. Cannot continue in remote mode."
        exit 1
    }

    Expand-Archive -Path $zipPath -DestinationPath $tmpdir -Force
    $extracted = Get-ChildItem -Path $tmpdir -Directory | Where-Object { $_.Name -ne "source.zip" } | Select-Object -First 1
    $script:SCRIPT_DIR = $extracted.FullName
    Write-Ok "Source downloaded to temporary directory"
}

# --- Version management ----------------------------------------------------

function Get-SourceVersion {
    $vf = Join-Path $SCRIPT_DIR "VERSION"
    if (Test-Path $vf) { return (Get-Content $vf -Raw).Trim() }
    return "unknown"
}

function Get-InstalledVersion {
    if (Test-Path $VERSION_STAMP_FILE) { return (Get-Content $VERSION_STAMP_FILE -Raw).Trim() }
    return "not installed"
}

function Get-RemoteVersion {
    $url = "https://raw.githubusercontent.com/Mizoreww/awesome-claude-code-config/main/VERSION"
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $result = (Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 10).Content.Trim()
        if ($result) { return $result }
    } catch {}
    return "unavailable"
}

function Show-Version {
    $sv = Get-SourceVersion
    $iv = Get-InstalledVersion
    $rv = Get-RemoteVersion
    Write-Host "awesome-claude-code-config version info:"
    Write-Host "  Source:    $sv"
    Write-Host "  Installed: $iv"
    Write-Host "  Remote:    $rv"
    if ($iv -ne "not installed" -and $rv -ne "unavailable" -and $iv -ne $rv) {
        Write-Warn "Update available: $iv -> $rv"
    }
}

function Save-VersionStamp {
    $ver = Get-SourceVersion
    if ($ver -ne "unknown") {
        $ver | Set-Content -Path $VERSION_STAMP_FILE -NoNewline
    }
}

# --- Confirm prompt --------------------------------------------------------

function Confirm-Action {
    param([string]$Prompt = "Continue?")
    if ($Force) { return $true }
    $answer = Read-Host "$Prompt [y/N]"
    return ($answer -match '^[Yy]$')
}

# --- Plugin groups ---------------------------------------------------------

$PLUGINS_ESSENTIAL = @(
    "everything-claude-code@everything-claude-code"
    "superpowers@claude-plugins-official"
    "code-review@claude-plugins-official"
    "context7@claude-plugins-official"
    "commit-commands@claude-plugins-official"
    "document-skills@anthropic-agent-skills"
    "playwright@claude-plugins-official"
    "feature-dev@claude-plugins-official"
    "code-simplifier@claude-plugins-official"
    "ralph-loop@claude-plugins-official"
    "frontend-design@claude-plugins-official"
    "example-skills@anthropic-agent-skills"
    "github@claude-plugins-official"
)

$PLUGINS_CLAUDE_MEM = @(
    "claude-mem@thedotmack"
)

$PLUGINS_AI_RESEARCH = @(
    "tokenization@ai-research-skills"
    "fine-tuning@ai-research-skills"
    "post-training@ai-research-skills"
    "inference-serving@ai-research-skills"
    "distributed-training@ai-research-skills"
    "optimization@ai-research-skills"
)

$PLUGINS_HEALTH = @(
    "health@claude-health"
)

$MARKETPLACE_LIST = @(
    @{ Name = "anthropic-agent-skills"; Repo = "anthropics/skills" }
    @{ Name = "everything-claude-code"; Repo = "affaan-m/everything-claude-code" }
    @{ Name = "ai-research-skills"; Repo = "zechenzhangAGI/AI-research-SKILLs" }
    @{ Name = "claude-plugins-official"; Repo = "anthropics/claude-plugins-official" }
    @{ Name = "thedotmack"; Repo = "thedotmack/claude-mem" }
    @{ Name = "claude-health"; Repo = "tw93/claude-health" }
)

# --- Interactive menu ------------------------------------------------------

function Show-InteractiveMenu {
    # Item format: label, description, default_on, id
    $items = @(
        @{ Label = "CLAUDE.md";            Desc = "Global instructions template";                   Default = $true;  Id = "claude-md" }
        @{ Label = "settings.json";        Desc = "Smart-merged Claude Code settings";              Default = $true;  Id = "settings" }
        @{ Label = "Common rules";         Desc = "Coding style, git, security, testing";           Default = $true;  Id = "rules-common" }
        @{ Label = "Hooks";                Desc = "StatusLine display hook";                        Default = $true;  Id = "hooks" }
        @{ Label = "Lessons template";     Desc = "Cross-session learning framework";               Default = $true;  Id = "lessons" }
        @{ Label = "Custom skills";        Desc = "adversarial-review, paper-reading, humanizer";   Default = $true;  Id = "skills" }
        @{ Label = "Python rules";         Desc = "PEP 8, pytest, type hints, bandit";              Default = $false; Id = "rules-python" }
        @{ Label = "TypeScript rules";     Desc = "Zod, Playwright, immutability";                  Default = $false; Id = "rules-ts" }
        @{ Label = "Go rules";             Desc = "gofmt, table-driven tests, gosec";               Default = $false; Id = "rules-go" }
        @{ Label = "Plugins (13)";         Desc = "superpowers, code-review, playwright, ...";      Default = $true;  Id = "plugins-essential" }
        @{ Label = "claude-mem";           Desc = "Cross-session memory (~3k tokens/session)";      Default = $false; Id = "plugins-claude-mem" }
        @{ Label = "AI Research plugins";  Desc = "fine-tuning, inference, optimization, ...";      Default = $false; Id = "plugins-ai-research" }
        @{ Label = "claude-health";        Desc = "Health check & wellness dashboard";               Default = $false; Id = "plugins-health" }
        @{ Label = "Lark MCP server";      Desc = "Feishu/Lark integration";                        Default = $false; Id = "mcp" }
    )

    $groups = @(
        @{ Start = 0;  End = 5;  Label = "Core" }
        @{ Start = 6;  End = 8;  Label = "Language Rules  (only install what your projects need)" }
        @{ Start = 9;  End = 12; Label = "Plugins" }
        @{ Start = 13; End = 13; Label = "MCP Servers" }
    )

    $n = $items.Count
    $selected = @()
    for ($i = 0; $i -lt $n; $i++) {
        $selected += $items[$i].Default
    }

    $cursor = 0
    $submitIndex = $n  # Submit button is at index $n

    # Save cursor visibility
    $savedCursorVisible = [Console]::CursorVisible
    [Console]::CursorVisible = $false

    try {
        while ($true) {
            # Draw menu
            [Console]::Clear()
            Write-Host ""
            Write-Host "  =========================================" -ForegroundColor White
            Write-Host "  Awesome Claude Code Config Installer" -ForegroundColor White
            Write-Host "  $(Get-SourceVersion)" -ForegroundColor White
            Write-Host "  =========================================" -ForegroundColor White
            Write-Host ""
            Write-Host "  " -NoNewline; Write-Host "Up/Down move  Enter select  a=all n=none d=defaults q=quit" -ForegroundColor DarkGray
            Write-Host ""

            foreach ($group in $groups) {
                Write-Host "  $($group.Label)" -ForegroundColor Cyan

                for ($j = $group.Start; $j -le $group.End; $j++) {
                    $item = $items[$j]
                    $isCursor = ($j -eq $cursor)

                    # Indicator
                    if ($isCursor) {
                        Write-Host "  " -NoNewline
                        Write-Host "> " -ForegroundColor Green -NoNewline
                    } else {
                        Write-Host "    " -NoNewline
                    }

                    # Checkbox
                    Write-Host "[" -NoNewline
                    if ($selected[$j]) {
                        Write-Host "x" -ForegroundColor Green -NoNewline
                    } else {
                        Write-Host " " -NoNewline
                    }
                    Write-Host "] " -NoNewline

                    # Label + description
                    $label = $item.Label.PadRight(24)
                    if ($isCursor) {
                        Write-Host $label -ForegroundColor White -NoNewline
                    } else {
                        Write-Host $label -NoNewline
                    }
                    Write-Host " $($item.Desc)" -ForegroundColor DarkGray
                }
                Write-Host ""
            }

            # Submit button
            if ($cursor -eq $submitIndex) {
                Write-Host "  " -NoNewline
                Write-Host "> " -ForegroundColor Green -NoNewline
                Write-Host "[ Submit ]" -ForegroundColor Green
            } else {
                Write-Host "     " -NoNewline
                Write-Host "[ Submit ]" -ForegroundColor DarkGray
            }
            Write-Host ""

            # Read key
            $key = [Console]::ReadKey($true)

            switch ($key.Key) {
                ([ConsoleKey]::UpArrow) {
                    if ($cursor -gt 0) { $cursor-- }
                }
                ([ConsoleKey]::DownArrow) {
                    if ($cursor -lt $submitIndex) { $cursor++ }
                }
                ([ConsoleKey]::Enter) {
                    if ($cursor -eq $submitIndex) {
                        break  # Submit
                    } else {
                        $selected[$cursor] = -not $selected[$cursor]
                    }
                }
                ([ConsoleKey]::Spacebar) {
                    if ($cursor -eq $submitIndex) {
                        break  # Submit
                    } else {
                        $selected[$cursor] = -not $selected[$cursor]
                    }
                }
                default {
                    switch ($key.KeyChar) {
                        'a' { for ($i = 0; $i -lt $n; $i++) { $selected[$i] = $true } }
                        'A' { for ($i = 0; $i -lt $n; $i++) { $selected[$i] = $true } }
                        'n' { for ($i = 0; $i -lt $n; $i++) { $selected[$i] = $false } }
                        'N' { for ($i = 0; $i -lt $n; $i++) { $selected[$i] = $false } }
                        'd' { for ($i = 0; $i -lt $n; $i++) { $selected[$i] = $items[$i].Default } }
                        'D' { for ($i = 0; $i -lt $n; $i++) { $selected[$i] = $items[$i].Default } }
                        'q' {
                            [Console]::CursorVisible = $savedCursorVisible
                            Write-Host ""
                            Write-Info "Cancelled."
                            exit 0
                        }
                        'Q' {
                            [Console]::CursorVisible = $savedCursorVisible
                            Write-Host ""
                            Write-Info "Cancelled."
                            exit 0
                        }
                        'j' { if ($cursor -lt $submitIndex) { $cursor++ } }
                        'J' { if ($cursor -lt $submitIndex) { $cursor++ } }
                        'k' { if ($cursor -gt 0) { $cursor-- } }
                        'K' { if ($cursor -gt 0) { $cursor-- } }
                    }
                }
            }

            # Check if we should break (Enter/Space on Submit)
            if ($cursor -eq $submitIndex -and ($key.Key -eq [ConsoleKey]::Enter -or $key.Key -eq [ConsoleKey]::Spacebar)) {
                break
            }
        }
    } finally {
        [Console]::CursorVisible = $savedCursorVisible
    }

    # Map selections to return value
    $result = @{
        ClaudeMd       = $false
        Settings       = $false
        Rules          = $false
        RuleLangs      = @()
        RuleLangsExplicit = $true
        Hooks          = $false
        Lessons        = $false
        Skills         = $false
        Plugins        = $false
        PluginGroups   = @()
        Mcp            = $false
    }

    for ($i = 0; $i -lt $n; $i++) {
        if (-not $selected[$i]) { continue }

        switch ($items[$i].Id) {
            "claude-md"        { $result.ClaudeMd = $true }
            "settings"         { $result.Settings = $true }
            "rules-common"     { $result.Rules = $true }
            "hooks"            { $result.Hooks = $true }
            "lessons"          { $result.Lessons = $true }
            "skills"           { $result.Skills = $true }
            "rules-python"     { $result.Rules = $true; $result.RuleLangs += "python" }
            "rules-ts"         { $result.Rules = $true; $result.RuleLangs += "typescript" }
            "rules-go"         { $result.Rules = $true; $result.RuleLangs += "golang" }
            "plugins-essential"   { $result.Plugins = $true; $result.PluginGroups += "essential" }
            "plugins-claude-mem"  { $result.Plugins = $true; $result.PluginGroups += "claude-mem" }
            "plugins-ai-research" { $result.Plugins = $true; $result.PluginGroups += "ai-research" }
            "plugins-health"      { $result.Plugins = $true; $result.PluginGroups += "health" }
            "mcp"              { $result.Mcp = $true }
        }
    }

    return $result
}

# --- Install functions -----------------------------------------------------

function Install-ClaudeMd {
    Write-Info "Installing CLAUDE.md..."
    if ($DryRun) {
        Write-Info "Would copy: CLAUDE.md -> $CLAUDE_DIR\CLAUDE.md"
    } else {
        Copy-Item (Join-Path $SCRIPT_DIR "CLAUDE.md") (Join-Path $CLAUDE_DIR "CLAUDE.md") -Force
        Write-Ok "CLAUDE.md installed"
    }
}

function Install-Settings {
    Write-Info "Installing settings.json..."
    $target = Join-Path $CLAUDE_DIR "settings.json"
    $source = Join-Path $SCRIPT_DIR "settings.json"

    if (-not (Test-Path $target)) {
        if ($DryRun) {
            Write-Info "Would copy: settings.json -> $target"
        } else {
            Copy-Item $source $target -Force
            Write-Ok "settings.json installed (new)"
        }
        return
    }

    # Smart merge using PowerShell JSON
    if ($DryRun) {
        Write-Info "Would smart-merge settings.json"
        Write-Info "  - env: incoming as defaults, existing overrides"
        Write-Info "  - permissions.allow: union of arrays"
        Write-Info "  - enabledPlugins: merged, existing keys take priority"
        Write-Info "  - hooks.SessionStart: deduplicated by matcher"
        Write-Info "  - statusLine: incoming takes priority"
        return
    }

    try {
        # Relax strict mode for dynamic JSON property access
        Set-StrictMode -Off

        $existing = Get-Content $target -Raw | ConvertFrom-Json
        $incoming = Get-Content $source -Raw | ConvertFrom-Json

        # Helper: convert PSCustomObject to ordered hashtable
        $toHt = {
            param($obj)
            if ($null -eq $obj) { return [ordered]@{} }
            if ($obj -is [System.Collections.IDictionary]) { return $obj }
            $ht = [ordered]@{}
            $obj.PSObject.Properties | ForEach-Object { $ht[$_.Name] = $_.Value }
            return $ht
        }

        # Helper: merge two objects as hashtables (second wins on conflict)
        $mergeHt = {
            param($base, $over)
            $result = [ordered]@{}
            $b = & $toHt $base
            $o = & $toHt $over
            foreach ($key in $b.Keys) { $result[$key] = $b[$key] }
            foreach ($key in $o.Keys) { $result[$key] = $o[$key] }
            return $result
        }

        # env: incoming as defaults, existing overrides
        $mergedEnv = & $mergeHt $incoming.env $existing.env

        # permissions.allow: union
        $baseAllow = if ($incoming.permissions -and $incoming.permissions.allow) { @($incoming.permissions.allow) } else { @() }
        $overAllow = if ($existing.permissions -and $existing.permissions.allow) { @($existing.permissions.allow) } else { @() }
        $mergedAllow = @($baseAllow + $overAllow | Select-Object -Unique)

        # enabledPlugins: merge, existing wins
        $mergedPlugins = & $mergeHt $incoming.enabledPlugins $existing.enabledPlugins

        # hooks.SessionStart: deduplicate by matcher (last wins)
        $sessionHooks = [ordered]@{}
        if ($incoming.hooks -and $incoming.hooks.SessionStart) {
            foreach ($h in @($incoming.hooks.SessionStart)) { if ($h.matcher) { $sessionHooks[$h.matcher] = $h } }
        }
        if ($existing.hooks -and $existing.hooks.SessionStart) {
            foreach ($h in @($existing.hooks.SessionStart)) { if ($h.matcher) { $sessionHooks[$h.matcher] = $h } }
        }
        $mergedSessionHooks = @($sessionHooks.Values)

        # Build merged result as hashtable (avoids PSCustomObject assignment issues)
        $merged = & $mergeHt $incoming $existing

        # Override with merged fields
        $merged["env"] = [PSCustomObject]$mergedEnv
        $merged["enabledPlugins"] = [PSCustomObject]$mergedPlugins
        $merged["statusLine"] = $incoming.statusLine
        $mergedPerms = & $mergeHt $incoming.permissions $existing.permissions
        $mergedPerms["allow"] = $mergedAllow
        $merged["permissions"] = [PSCustomObject]$mergedPerms
        $mergedHooks = & $mergeHt $incoming.hooks $existing.hooks
        $mergedHooks["SessionStart"] = $mergedSessionHooks
        $merged["hooks"] = [PSCustomObject]$mergedHooks

        [PSCustomObject]$merged | ConvertTo-Json -Depth 10 | Set-Content $target -Encoding UTF8

        Set-StrictMode -Version Latest
        Write-Ok "settings.json smart-merged"
    } catch {
        Set-StrictMode -Version Latest
        Write-Err "Merge failed: $_"
        Write-Warn "Please merge manually: $source -> $target"
        $script:InstallWarnings++
    }
}

function Install-Rules {
    param(
        [string[]]$Langs = @(),
        [bool]$LangsExplicit = $false
    )

    Write-Info "Installing rules..."
    $rulesDir = Join-Path $CLAUDE_DIR "rules"
    New-Item -ItemType Directory -Path $rulesDir -Force | Out-Null

    # Always install common rules
    $commonSrc = Join-Path $SCRIPT_DIR "rules\common"
    $commonDst = Join-Path $rulesDir "common"
    if ($DryRun) {
        Write-Info "Would copy: rules\common\ -> $commonDst"
    } else {
        if (Test-Path $commonDst) { Remove-Item $commonDst -Recurse -Force }
        Copy-Item $commonSrc $commonDst -Recurse -Force
        Write-Ok "Common rules installed"
    }

    # Determine languages
    $installLangs = @()
    if ($Langs.Count -gt 0) {
        $installLangs = $Langs
    } elseif (-not $LangsExplicit) {
        # Auto-detect: install all available languages (--all mode)
        Get-ChildItem (Join-Path $SCRIPT_DIR "rules") -Directory | ForEach-Object {
            if ($_.Name -ne "common") { $installLangs += $_.Name }
        }
    }
    # If LangsExplicit=true and Langs is empty, skip language rules

    foreach ($lang in $installLangs) {
        $langSrc = Join-Path $SCRIPT_DIR "rules\$lang"
        if (Test-Path $langSrc) {
            $langDst = Join-Path $rulesDir $lang
            if ($DryRun) {
                Write-Info "Would copy: rules\$lang\ -> $langDst"
            } else {
                if (Test-Path $langDst) { Remove-Item $langDst -Recurse -Force }
                Copy-Item $langSrc $langDst -Recurse -Force
                Write-Ok "$lang rules installed"
            }
        } else {
            Write-Err "Language rules not found: $lang"
        }
    }

    # Clean up known language rule dirs that were NOT selected (from previous installs)
    # Only removes languages this installer knows about; preserves user-created dirs
    if ($LangsExplicit) {
        $knownLangs = @("python", "typescript", "golang")
        foreach ($known in $knownLangs) {
            if ($installLangs -notcontains $known) {
                $langDir = Join-Path $rulesDir $known
                if (Test-Path $langDir) {
                    if ($DryRun) {
                        Write-Info "Would remove unselected: $langDir"
                    } else {
                        Remove-Item $langDir -Recurse -Force
                        Write-Ok "Removed unselected rules: $known"
                    }
                }
            }
        }
    }

    $readmeSrc = Join-Path $SCRIPT_DIR "rules\README.md"
    if (Test-Path $readmeSrc) {
        if ($DryRun) {
            Write-Info "Would copy: rules\README.md -> $rulesDir\README.md"
        } else {
            Copy-Item $readmeSrc (Join-Path $rulesDir "README.md") -Force
        }
    }
}

function Install-Skills {
    Write-Info "Installing custom skills..."
    $skillsDir = Join-Path $CLAUDE_DIR "skills"
    New-Item -ItemType Directory -Path $skillsDir -Force | Out-Null

    Get-ChildItem (Join-Path $SCRIPT_DIR "skills") -Directory | ForEach-Object {
        $skill = $_.Name
        $dst = Join-Path $skillsDir $skill
        if ($DryRun) {
            Write-Info "Would copy: skills\$skill\ -> $dst"
        } else {
            if (Test-Path $dst) { Remove-Item $dst -Recurse -Force }
            Copy-Item $_.FullName $dst -Recurse -Force
            Write-Ok "Skill installed: $skill"
        }
    }
}

function Install-Lessons {
    Write-Info "Installing lessons.md template..."
    $target = Join-Path $CLAUDE_DIR "lessons.md"
    if (Test-Path $target) {
        Write-Warn "lessons.md already exists -- skipping"
    } else {
        if ($DryRun) {
            Write-Info "Would copy: lessons.md -> $target"
        } else {
            Copy-Item (Join-Path $SCRIPT_DIR "lessons.md") $target -Force
            Write-Ok "lessons.md template installed to $target"
        }
    }
}

function Install-Hooks {
    Write-Info "Installing hooks..."
    $hooksDir = Join-Path $CLAUDE_DIR "hooks"
    New-Item -ItemType Directory -Path $hooksDir -Force | Out-Null

    Get-ChildItem (Join-Path $SCRIPT_DIR "hooks") -File | ForEach-Object {
        $fname = $_.Name
        $dst = Join-Path $hooksDir $fname
        if ($DryRun) {
            Write-Info "Would copy: hooks\$fname -> $dst"
        } else {
            Copy-Item $_.FullName $dst -Force
            Write-Ok "Hook installed: $fname"
        }
    }

    # Ensure jq is available (required by statusline.sh)
    Install-Jq

    # Install Nerd Font for statusline icons
    Install-NerdFont

    # Check bash availability (required by statusline and SessionStart hooks)
    if (-not (Get-Command bash -ErrorAction SilentlyContinue)) {
        Write-Warn "bash not found in PATH. Statusline and SessionStart hooks require bash."
        Write-Warn "  Install Git for Windows (includes Git Bash): https://git-scm.com/download/win"
        Write-Warn "  Or install WSL: wsl --install"
        $script:InstallWarnings++
    }
}

function Install-Jq {
    if (Get-Command jq -ErrorAction SilentlyContinue) {
        Write-Ok "jq already available in PATH"
        return
    }

    $binDir = Join-Path $CLAUDE_DIR "bin"
    $jqPath = Join-Path $binDir "jq.exe"
    if (Test-Path $jqPath) {
        Write-Ok "jq already installed at $jqPath"
        return
    }

    if ($DryRun) {
        Write-Info "Would download jq.exe -> $jqPath"
        return
    }

    Write-Info "Downloading jq (required by statusline)..."
    New-Item -ItemType Directory -Path $binDir -Force | Out-Null

    $arch = if ([Environment]::Is64BitOperatingSystem) { "amd64" } else { "i386" }
    $jqUrl = "https://github.com/jqlang/jq/releases/latest/download/jq-windows-$arch.exe"

    $ok = Invoke-Retry -MaxAttempts 3 -DelaySeconds 2 -Description "Download jq" -Action {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $jqUrl -OutFile $jqPath -UseBasicParsing
    }
    if ($ok) {
        Write-Ok "jq installed to $jqPath"
    } else {
        Write-Warn "Could not download jq. Install it manually: https://jqlang.github.io/jq/download/"
        Write-Warn "Or run: winget install jqlang.jq"
    }
}

function Install-NerdFont {
    # Check if already installed
    $fontDir = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Fonts"
    if ((Test-Path $fontDir) -and (Get-ChildItem $fontDir -Filter "*JetBrainsMono*Nerd*" -ErrorAction SilentlyContinue)) {
        return
    }

    if ($DryRun) {
        Write-Info "Would download and install JetBrainsMono Nerd Font"
        return
    }

    Write-Info "Installing JetBrainsMono Nerd Font for statusline icons..."

    $tmpZip = Join-Path ([System.IO.Path]::GetTempPath()) "JetBrainsMono-NerdFont.zip"
    $url = "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"

    $ok = Invoke-Retry -MaxAttempts 3 -DelaySeconds 2 -Description "Download Nerd Font" -Action {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $url -OutFile $tmpZip -UseBasicParsing -TimeoutSec 120
    }
    if (-not $ok) {
        Write-Warn "Could not download Nerd Font - statusline will use text fallback"
        return
    }

    try {
        $tmpExtract = Join-Path ([System.IO.Path]::GetTempPath()) "NerdFont-$(Get-Random)"
        Expand-Archive -Path $tmpZip -DestinationPath $tmpExtract -Force

        # Install to user fonts directory
        if (-not (Test-Path $fontDir)) {
            New-Item -ItemType Directory -Path $fontDir -Force | Out-Null
        }

        $regPath = "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
        Get-ChildItem $tmpExtract -Filter "*.ttf" | ForEach-Object {
            $dst = Join-Path $fontDir $_.Name
            Copy-Item $_.FullName $dst -Force
            # Register font in user registry
            $fontName = [System.IO.Path]::GetFileNameWithoutExtension($_.Name) + " (TrueType)"
            New-ItemProperty -Path $regPath -Name $fontName -Value $dst -PropertyType String -Force | Out-Null
        }

        Remove-Item $tmpExtract -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item $tmpZip -Force -ErrorAction SilentlyContinue

        Write-Ok "JetBrainsMono Nerd Font installed"
        Write-Warn "Set your terminal font to 'JetBrainsMono Nerd Font' for best icon display"
    } catch {
        Write-Warn "Could not install Nerd Font: $_"
        Remove-Item $tmpZip -Force -ErrorAction SilentlyContinue
    }
}

function Install-Mcp {
    Write-Info "Installing MCP servers..."
    $claudeCmd = Get-Command claude -ErrorAction SilentlyContinue
    if (-not $claudeCmd) {
        Write-Err "Claude Code CLI not found. Install it first: https://claude.com/claude-code"
        return
    }

    if ($DryRun) {
        Write-Info "Would add MCP server: lark-mcp (stdio)"
    } else {
        $ok = Invoke-Retry -MaxAttempts 5 -DelaySeconds 3 -Description "Add MCP server lark-mcp" -Action {
            & claude mcp add --scope user --transport stdio lark-mcp -- npx -y "@larksuiteoapi/lark-mcp" mcp -a YOUR_APP_ID -s YOUR_APP_SECRET 2>$null
        }
        if ($ok) { Write-Ok "MCP server added: lark-mcp" }
        else { Write-Warn "MCP server lark-mcp may already exist or could not be added, skipping" }
        Write-Warn "Replace YOUR_APP_ID and YOUR_APP_SECRET with your Feishu credentials"
    }
}

function Install-Plugins {
    param(
        [string[]]$Groups = @("essential")
    )

    $claudeCmd = Get-Command claude -ErrorAction SilentlyContinue
    if (-not $claudeCmd) {
        Write-Err "Claude Code CLI not found. Install it first: https://claude.com/claude-code"
        return
    }

    # Collect plugins from all selected groups
    $plugins = @()
    foreach ($group in $Groups) {
        switch ($group) {
            "essential" { $plugins += $PLUGINS_ESSENTIAL }
            "claude-mem" { $plugins += $PLUGINS_CLAUDE_MEM }
            "ai-research" { $plugins += $PLUGINS_AI_RESEARCH }
            "health" { $plugins += $PLUGINS_HEALTH }
            "all" { $plugins += $PLUGINS_ESSENTIAL + $PLUGINS_CLAUDE_MEM + $PLUGINS_AI_RESEARCH + $PLUGINS_HEALTH }
        }
    }

    # Deduplicate
    $plugins = $plugins | Select-Object -Unique

    $groupNames = $Groups -join ","
    Write-Info "Installing plugins (groups: $groupNames)..."

    # Collect needed marketplaces
    $neededMarketplaces = @{}
    foreach ($entry in $plugins) {
        $marketplace = ($entry -split '@')[-1]
        $neededMarketplaces[$marketplace] = $true
    }

    # Step 1: Add required marketplaces
    Write-Info "Adding marketplaces..."
    foreach ($mp in $MARKETPLACE_LIST) {
        if (-not $neededMarketplaces.ContainsKey($mp.Name)) { continue }

        # Skip if already installed
        $mpDir = Join-Path $env:USERPROFILE ".claude\plugins\marketplaces\$($mp.Name)"
        if (Test-Path $mpDir) {
            Write-Ok "Marketplace already exists: $($mp.Name)"
            continue
        }

        if ($DryRun) {
            Write-Info "Would add marketplace: $($mp.Name) (github.com/$($mp.Repo))"
        } else {
            $ok = Invoke-Retry -MaxAttempts 5 -DelaySeconds 3 -Description "Add marketplace $($mp.Name)" -Action {
                & claude plugin marketplace add "https://github.com/$($mp.Repo)" 2>$null
            }
            if ($ok) { Write-Ok "Marketplace added: $($mp.Name)" }
            else { Write-Warn "Marketplace $($mp.Name) may already exist or could not be added" }
        }
    }

    # Step 2: Install plugins
    Write-Info "Installing $($plugins.Count) plugins..."
    foreach ($entry in $plugins) {
        $parts = $entry -split '@'
        $pluginName = $parts[0]
        if ($DryRun) {
            Write-Info "Would install plugin: $pluginName from $($parts[1])"
        } else {
            $ok = Invoke-Retry -MaxAttempts 5 -DelaySeconds 3 -Description "Install plugin $pluginName" -Action {
                & claude plugin install "$entry" 2>$null
            }
            if ($ok) { Write-Ok "Plugin installed: $pluginName" }
            else { Write-Warn "Plugin $pluginName could not be installed, skipping"; $script:InstallWarnings++ }
        }
    }
}

# --- Uninstall -------------------------------------------------------------

function Invoke-Uninstall {
    Write-Host ""
    Write-Warn "The following will be removed:"
    Write-Host "  - $CLAUDE_DIR\CLAUDE.md"
    Write-Host "  - $CLAUDE_DIR\settings.json (backed up first)"
    Write-Host "  - $CLAUDE_DIR\rules\"
    Write-Host "  - $CLAUDE_DIR\skills\ (installer-managed only)"
    Write-Host "  - $CLAUDE_DIR\lessons.md"
    Write-Host "  - $CLAUDE_DIR\hooks\ (installer-managed only)"
    Write-Host "  - Installed plugins (requires claude CLI)"
    Write-Host "  - MCP server: lark-mcp (requires claude CLI)"
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
        exit 0
    }

    $p = Join-Path $CLAUDE_DIR "CLAUDE.md"
    if (Test-Path $p) { Remove-Item $p -Force; Write-Ok "Removed CLAUDE.md" }

    $p = Join-Path $CLAUDE_DIR "settings.json"
    if (Test-Path $p) {
        Copy-Item $p (Join-Path $CLAUDE_DIR "settings.json.bak") -Force
        Write-Ok "Backed up settings.json -> settings.json.bak"
        Remove-Item $p -Force; Write-Ok "Removed settings.json"
    }

    $p = Join-Path $CLAUDE_DIR "rules"
    if (Test-Path $p) { Remove-Item $p -Recurse -Force; Write-Ok "Removed rules/" }

    # Only remove skills that ship with this repo
    $skillsSrc = Join-Path $SCRIPT_DIR "skills"
    if (Test-Path $skillsSrc) {
        Get-ChildItem $skillsSrc -Directory | ForEach-Object {
            $sp = Join-Path $CLAUDE_DIR "skills\$($_.Name)"
            if (Test-Path $sp) { Remove-Item $sp -Recurse -Force; Write-Ok "Removed skill: $($_.Name)" }
        }
    } else {
        $p = Join-Path $CLAUDE_DIR "skills"
        if (Test-Path $p) { Remove-Item $p -Recurse -Force; Write-Ok "Removed skills/" }
    }

    $p = Join-Path $CLAUDE_DIR "lessons.md"
    if (Test-Path $p) { Remove-Item $p -Force; Write-Ok "Removed lessons.md" }

    # Only remove hooks that ship with this repo
    $hooksSrc = Join-Path $SCRIPT_DIR "hooks"
    if (Test-Path $hooksSrc) {
        Get-ChildItem $hooksSrc -File | ForEach-Object {
            $hp = Join-Path $CLAUDE_DIR "hooks\$($_.Name)"
            if (Test-Path $hp) { Remove-Item $hp -Force; Write-Ok "Removed hook: $($_.Name)" }
        }
    } else {
        $p = Join-Path $CLAUDE_DIR "hooks"
        if (Test-Path $p) { Remove-Item $p -Recurse -Force; Write-Ok "Removed hooks/" }
    }

    $claudeCmd = Get-Command claude -ErrorAction SilentlyContinue
    if ($claudeCmd) {
        $allPlugins = $PLUGINS_ESSENTIAL + $PLUGINS_CLAUDE_MEM + $PLUGINS_AI_RESEARCH + $PLUGINS_HEALTH
        foreach ($entry in $allPlugins) {
            $pluginName = ($entry -split '@')[0]
            & claude plugin uninstall $entry 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Ok "Uninstalled plugin: $pluginName"
            } else {
                Write-Warn "Could not uninstall: $pluginName"
            }
        }
        & claude mcp remove lark-mcp 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Ok "Removed MCP server: lark-mcp"
        } else {
            Write-Warn "Could not remove lark-mcp"
        }
    } else {
        Write-Warn "Claude CLI not found - cannot uninstall plugins or MCP servers"
    }

    if (Test-Path $VERSION_STAMP_FILE) { Remove-Item $VERSION_STAMP_FILE -Force }
    Write-Host ""
    Write-Ok "Uninstall complete."
}

# --- Help ------------------------------------------------------------------

function Show-Help {
    Write-Host @"

Usage: .\install.ps1 [OPTIONS]

Install Claude Code configuration files.

Running without options launches an interactive component selector.
Works with both local and remote installs (irm | iex).

Options:
    -All                Install everything (non-interactive)
    -Uninstall          Remove all installed files
    -Version            Show version info
    -DryRun             Show what would be installed without doing it
    -Force              Skip confirmation prompts
    -Help               Show this help

Examples:
    .\install.ps1                  # Interactive selector
    .\install.ps1 -All             # Install everything
    .\install.ps1 -Uninstall       # Uninstall everything
    .\install.ps1 -DryRun -All     # Preview full install
    irm $REPO_URL/raw/main/install.ps1 | iex  # Remote install (interactive selector)

"@
}

# --- Main ------------------------------------------------------------------

function Main {
    Initialize-ScriptDir

    if ($Help) { Show-Help; return }
    if ($Version) { Show-Version; return }
    if ($Uninstall) {
        Write-Host ""
        Write-Host "========================================="
        Write-Host "  Claude Code Config - Uninstaller"
        Write-Host "========================================="
        Invoke-Uninstall
        return
    }

    # Determine mode
    $doClaudeMd = $false
    $doSettings = $false
    $doRules = $false
    $doSkills = $false
    $doLessons = $false
    $doHooks = $false
    $doPlugins = $false
    $doMcp = $false
    $ruleLangs = @()
    $ruleLangsExplicit = $false
    $pluginGroups = @()

    if ($All) {
        # Explicit -All: install everything including MCP
        $doClaudeMd = $true
        $doSettings = $true
        $doRules = $true
        $doSkills = $true
        $doLessons = $true
        $doHooks = $true
        $doPlugins = $true
        $doMcp = $true
        $pluginGroups = @("all")
    } elseif ([Environment]::UserInteractive -and $Host.Name -eq "ConsoleHost") {
        # Interactive mode: show menu (with fallback if console APIs fail)
        $menuResult = $null
        try {
            $menuResult = Show-InteractiveMenu
        } catch {
            Write-Warn "Interactive menu unavailable: $_"
            Write-Info "Falling back to default install (essential plugins, no MCP)"
        }
        if ($null -ne $menuResult) {
            $doClaudeMd = $menuResult.ClaudeMd
            $doSettings = $menuResult.Settings
            $doRules = $menuResult.Rules
            $doSkills = $menuResult.Skills
            $doLessons = $menuResult.Lessons
            $doHooks = $menuResult.Hooks
            $doPlugins = $menuResult.Plugins
            $doMcp = $menuResult.Mcp
            $ruleLangs = $menuResult.RuleLangs
            $ruleLangsExplicit = $menuResult.RuleLangsExplicit
            $pluginGroups = $menuResult.PluginGroups
        } else {
            # Fallback when interactive menu failed
            $doClaudeMd = $true
            $doSettings = $true
            $doRules = $true
            $doSkills = $true
            $doLessons = $true
            $doHooks = $true
            $doPlugins = $true
            $pluginGroups = @("essential")
        }
    } else {
        # Non-interactive fallback: essential plugins, no MCP
        $doClaudeMd = $true
        $doSettings = $true
        $doRules = $true
        $doSkills = $true
        $doLessons = $true
        $doHooks = $true
        $doPlugins = $true
        $pluginGroups = @("essential")
    }

    # Check if anything was selected
    if (-not $doClaudeMd -and -not $doSettings -and -not $doRules -and
        -not $doSkills -and -not $doLessons -and -not $doHooks -and
        -not $doPlugins -and -not $doMcp) {
        Write-Warn "Nothing selected to install."
        return
    }

    $sourceVer = Get-SourceVersion
    Write-Host ""
    Write-Host "========================================="
    Write-Host "  Awesome Claude Code Config Installer"
    Write-Host "  $sourceVer"
    Write-Host "========================================="
    Write-Host ""

    if ($DryRun) {
        Write-Warn "DRY RUN MODE -- no changes will be made"
        Write-Host ""
    }

    $installedVer = Get-InstalledVersion
    if ($installedVer -ne "not installed") {
        Write-Info "Upgrading from $installedVer -> $sourceVer"
    }

    if (-not (Test-Path $CLAUDE_DIR)) {
        New-Item -ItemType Directory -Path $CLAUDE_DIR -Force | Out-Null
    }

    if ($doClaudeMd) { Install-ClaudeMd }
    if ($doSettings) { Install-Settings }
    if ($doRules) { Install-Rules -Langs $ruleLangs -LangsExplicit $ruleLangsExplicit }
    if ($doSkills) { Install-Skills }
    if ($doLessons) { Install-Lessons }
    if ($doHooks) { Install-Hooks }
    if ($doMcp) { Install-Mcp }
    if ($doPlugins) { Install-Plugins -Groups $pluginGroups }

    if (-not $DryRun) {
        if ($InstallWarnings -eq 0) {
            Save-VersionStamp
        } else {
            Write-Warn "Skipping version stamp due to $InstallWarnings warning(s)"
        }
    }

    Write-Host ""
    if ($InstallWarnings -gt 0) {
        Write-Warn "Installation completed with $InstallWarnings warning(s) - review messages above"
    } else {
        Write-Ok "Installation complete! ($sourceVer)"
    }
    Write-Host ""
    Write-Info "Next steps:"
    Write-Host "  1. Restart Claude Code for changes to take effect"
    Write-Host "  2. Customize CLAUDE.md for your specific projects"
    if ($doMcp) {
        Write-Host "  3. Replace YOUR_APP_ID/YOUR_APP_SECRET in Lark MCP config"
    }
    Write-Host ""
}

Main
