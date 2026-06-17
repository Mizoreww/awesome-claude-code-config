#Requires -Version 5.1
<#
.SYNOPSIS
  Awesome Claude Code Config - Cursor Installer (Windows)
  https://github.com/Mizoreww/awesome-claude-code-config (branch: cursor)

.DESCRIPTION
  PowerShell port of install-cursor.sh. Installs this repo's Cursor
  configuration into %USERPROFILE%\.cursor (override with $env:CURSOR_HOME or
  -Prefix). Non-destructive: backs up config files before overwriting, merges
  JSON natively (no jq needed), and never overwrites an existing lessons.md.

.PARAMETER Prefix
  Install into this directory instead of ~\.cursor (handy for testing).

.PARAMETER DryRun
  Print what would happen; change nothing.

.PARAMETER Uninstall
  Remove this config and restore the pre-install state (from the recorded
  snapshot/manifest). Falls back to best-effort removal if none is found.

.PARAMETER PurgeLessons
  With -Uninstall: also delete a lessons.md that the installer seeded
  (default: your corrections are kept).

.PARAMETER Force
  Skip the uninstall confirmation prompt.

.PARAMETER Help
  Show usage.

.EXAMPLE
  .\install-cursor.ps1
  .\install-cursor.ps1 -Prefix C:\tmp\cursor-test
  .\install-cursor.ps1 -DryRun
  .\install-cursor.ps1 -Uninstall
  .\install-cursor.ps1 -Uninstall -PurgeLessons -Force
#>
[CmdletBinding()]
param(
    [string]$Prefix,
    [switch]$DryRun,
    [switch]$Uninstall,
    [switch]$PurgeLessons,
    [switch]$Force,
    [switch]$Help
)

$ErrorActionPreference = "Stop"

if ($Help) {
    Get-Help $PSCommandPath -Detailed
    exit 0
}

# --- Paths / state ------------------------------------------------------
$SCRIPT_DIR = if ($PSScriptRoot) { $PSScriptRoot } elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path } else { "" }

if ($Prefix) {
    $CURSOR_HOME = $Prefix
} elseif ($env:CURSOR_HOME) {
    $CURSOR_HOME = $env:CURSOR_HOME
} else {
    $CURSOR_HOME = Join-Path $env:USERPROFILE ".cursor"
}
$TS = Get-Date -Format "yyyyMMddHHmmss"
$REMOTE_MODE = $false

# Derived state paths + the set of single files we overwrite/merge (snapshotted
# on first install so -Uninstall can restore the exact previous content).
$SNAPSHOT_DIR       = Join-Path $CURSOR_HOME ".awesome-claude-code-config.backup"
$MANIFEST_FILE      = Join-Path $CURSOR_HOME ".awesome-claude-code-config.manifest"
$VERSION_STAMP_FILE = Join-Path $CURSOR_HOME ".awesome-claude-code-config-version"
$MANAGED_FILES = @(
    "AGENTS.md", "mcp.json", "hooks.json", "cli-config.json",
    "statusline.sh", "hooks/load-lessons.sh", "hooks/statusline.sh"
)
$script:ManifestLines = @()

function Rel-Dst        { param($rel) Join-Path $CURSOR_HOME ($rel -replace '/', '\') }
function Snap-Path      { param($rel) Join-Path $SNAPSHOT_DIR ($rel -replace '/', '\') }
function MF-Add         { param($l) $script:ManifestLines += $l }
function Source-Version {
    $vf = Join-Path $SCRIPT_DIR "VERSION"
    if (Test-Path $vf) { return ((Get-Content -Raw $vf).Trim()) } else { return "unknown" }
}
function Source-PathFor {
    param($rel)
    switch ($rel) {
        "statusline.sh"         { return (Join-Path $SCRIPT_DIR "hooks\statusline.sh") }
        "hooks/load-lessons.sh" { return (Join-Path $SCRIPT_DIR "hooks\load-lessons.sh") }
        "hooks/statusline.sh"   { return (Join-Path $SCRIPT_DIR "hooks\statusline.sh") }
        default                 { return (Join-Path $SCRIPT_DIR ($rel -replace '/', '\')) }
    }
}
function Files-Equal {
    param($a, $b)
    try { return ((Get-FileHash -Algorithm MD5 $a).Hash -eq (Get-FileHash -Algorithm MD5 $b).Hash) }
    catch { return $false }
}

# Repo coordinates — used only in remote mode (download to a temp dir).
$REPO_OWNER  = if ($env:REPO_OWNER)  { $env:REPO_OWNER }  else { "Mizoreww" }
$REPO_NAME   = if ($env:REPO_NAME)   { $env:REPO_NAME }   else { "awesome-claude-code-config" }
$REPO_BRANCH = if ($env:REPO_BRANCH) { $env:REPO_BRANCH } else { "cursor" }
if ($REPO_OWNER  -notmatch '^[A-Za-z0-9._-]+$')  { Write-Host "Invalid REPO_OWNER: $REPO_OWNER"   -ForegroundColor Red; exit 1 }
if ($REPO_NAME   -notmatch '^[A-Za-z0-9._-]+$')  { Write-Host "Invalid REPO_NAME: $REPO_NAME"     -ForegroundColor Red; exit 1 }
if ($REPO_BRANCH -notmatch '^[A-Za-z0-9._/-]+$') { Write-Host "Invalid REPO_BRANCH: $REPO_BRANCH" -ForegroundColor Red; exit 1 }
$REPO_URL = "https://github.com/$REPO_OWNER/$REPO_NAME"

function Write-Info { param($m) Write-Host "[INFO] $m" -ForegroundColor Blue }
function Write-Ok   { param($m) Write-Host "[OK] $m"   -ForegroundColor Green }
function Write-Warn { param($m) Write-Host "[WARN] $m" -ForegroundColor Yellow }
function Write-Err  { param($m) Write-Host "[ERROR] $m" -ForegroundColor Red }
function Rel        { param($p) $p -replace [regex]::Escape("$SCRIPT_DIR\"), "" }

# --- Safe filesystem helpers (honor -DryRun) ----------------------------
function Ensure-Dir {
    param($Dir)
    if ($DryRun) { if (-not (Test-Path $Dir)) { Write-Info "would create dir: $Dir" }; return }
    if (-not (Test-Path $Dir)) { New-Item -ItemType Directory -Force -Path $Dir | Out-Null }
}

function Backup-IfExists {
    param($Target)
    if (-not (Test-Path $Target)) { return }
    $backup = "$Target.bak.$TS"
    if ($DryRun) { Write-Warn "would back up: $Target -> $(Split-Path -Leaf $backup)"; return }
    Copy-Item -Path $Target -Destination $backup -Force
    Write-Warn "backed up: $(Split-Path -Leaf $Target) -> $(Split-Path -Leaf $backup)"
}

# Copy-FileSafe SRC DST -- backs up DST if present, then copies.
function Copy-FileSafe {
    param($Src, $Dst)
    if (-not (Test-Path $Src)) { Write-Warn "source missing, skipping: $(Rel $Src)"; return }
    Backup-IfExists $Dst
    if ($DryRun) { Write-Info "would copy: $(Rel $Src) -> $Dst"; return }
    Ensure-Dir (Split-Path -Parent $Dst)
    Copy-Item -Path $Src -Destination $Dst -Force
    Write-Ok "installed: $Dst"
}

# Read JSON file into an ordered hashtable-friendly PSCustomObject (or $null).
function Read-Json {
    param($Path)
    try { return (Get-Content -Raw -Path $Path | ConvertFrom-Json) }
    catch { Write-Warn "could not parse JSON: $Path"; return $null }
}

# Merge incoming.mcpServers into existing (existing servers win on conflict).
function Merge-Mcp {
    param($Src, $Dst)
    if (-not (Test-Path $Src)) { Write-Warn "source missing, skipping: $(Rel $Src)"; return }
    if (-not (Test-Path $Dst)) { Copy-FileSafe $Src $Dst; return }
    if ($DryRun) { Backup-IfExists $Dst; Write-Info "would merge mcp.json (mcpServers): $(Rel $Src) -> $Dst"; return }

    $incoming = Read-Json $Src
    $existing = Read-Json $Dst
    if ($null -eq $incoming -or $null -eq $existing) {
        Write-Warn "mcp.json: cannot parse both files; leaving existing untouched. Merge manually from $(Rel $Src)."
        return
    }
    Backup-IfExists $Dst

    $servers = [ordered]@{}
    if ($incoming.mcpServers) { foreach ($p in $incoming.mcpServers.PSObject.Properties) { $servers[$p.Name] = $p.Value } }
    if ($existing.mcpServers) { foreach ($p in $existing.mcpServers.PSObject.Properties) { $servers[$p.Name] = $p.Value } }

    $existing | Add-Member -NotePropertyName mcpServers -NotePropertyValue ([pscustomobject]$servers) -Force
    ($existing | ConvertTo-Json -Depth 20) | Set-Content -Path $Dst -Encoding UTF8
    Write-Ok "merged mcp.json (existing servers preserved) -> $Dst"
}

# Merge our statusLine into existing cli-config.json (our statusLine wins).
function Merge-StatusLine {
    param($Src, $Dst)
    if (-not (Test-Path $Src)) { Write-Warn "source missing, skipping: $(Rel $Src)"; return }
    if (-not (Test-Path $Dst)) { Copy-FileSafe $Src $Dst; return }
    if ($DryRun) { Backup-IfExists $Dst; Write-Info "would merge cli-config.json (statusLine): $(Rel $Src) -> $Dst"; return }

    $incoming = Read-Json $Src
    $existing = Read-Json $Dst
    if ($null -eq $incoming -or $null -eq $existing) {
        Write-Warn "cli-config.json: cannot parse both files; leaving existing untouched. Merge manually from $(Rel $Src)."
        return
    }
    Backup-IfExists $Dst
    $existing | Add-Member -NotePropertyName statusLine -NotePropertyValue $incoming.statusLine -Force
    ($existing | ConvertTo-Json -Depth 20) | Set-Content -Path $Dst -Encoding UTF8
    Write-Ok "merged cli-config.json (statusLine) -> $Dst"
}

# Merge our hook entries into an existing hooks.json (keep the user's hooks;
# dedupe identical entries) instead of overwriting the whole file.
function Merge-Hooks {
    param($Src, $Dst)
    if (-not (Test-Path $Src)) { Write-Warn "source missing, skipping: $(Rel $Src)"; return }
    if (-not (Test-Path $Dst)) { Copy-FileSafe $Src $Dst; return }
    if ($DryRun) { Backup-IfExists $Dst; Write-Info "would merge hooks.json (hooks): $(Rel $Src) -> $Dst"; return }

    $incoming = Read-Json $Src
    $existing = Read-Json $Dst
    if ($null -eq $incoming -or $null -eq $existing) {
        Write-Warn "hooks.json: cannot parse both files; leaving existing untouched. Merge manually from $(Rel $Src)."
        return
    }
    Backup-IfExists $Dst

    $events = [ordered]@{}
    foreach ($obj in @($existing.hooks, $incoming.hooks)) {
        if ($null -eq $obj) { continue }
        foreach ($p in $obj.PSObject.Properties) {
            if (-not $events.Contains($p.Name)) { $events[$p.Name] = @() }
            foreach ($entry in @($p.Value)) {
                $json = ($entry | ConvertTo-Json -Depth 20 -Compress)
                $dup = $false
                foreach ($e in $events[$p.Name]) { if (($e | ConvertTo-Json -Depth 20 -Compress) -eq $json) { $dup = $true; break } }
                if (-not $dup) { $events[$p.Name] += $entry }
            }
        }
    }
    $existing | Add-Member -NotePropertyName hooks -NotePropertyValue ([pscustomobject]$events) -Force
    ($existing | ConvertTo-Json -Depth 20) | Set-Content -Path $Dst -Encoding UTF8
    Write-Ok "merged hooks.json (existing hooks preserved) -> $Dst"
}

# Point statusLine.command at the actual install dir (handles -Prefix / CURSOR_HOME).
function Set-StatusLineCommand {
    $dst = Join-Path $CURSOR_HOME "cli-config.json"
    $cmd = Join-Path $CURSOR_HOME "statusline.sh"
    if (-not (Test-Path $dst)) { return }
    if ($DryRun) { Write-Info "would set statusLine.command -> $cmd"; return }
    $cfg = Read-Json $dst
    if ($null -eq $cfg -or $null -eq $cfg.statusLine) { return }
    $cfg.statusLine.command = $cmd
    ($cfg | ConvertTo-Json -Depth 20) | Set-Content -Path $dst -Encoding UTF8
    Write-Ok "statusLine.command -> $cmd"
}

# --- Remote-mode source resolution --------------------------------------
# Run from a clone: AGENTS.md sits next to this script. Run remotely (no clone):
# download the branch zip into a temp dir and install from there.
function Initialize-ScriptDir {
    if ($script:SCRIPT_DIR -and (Test-Path (Join-Path $script:SCRIPT_DIR "AGENTS.md"))) {
        $script:REMOTE_MODE = $false
        return
    }
    $script:REMOTE_MODE = $true
    $tmpdir = Join-Path ([System.IO.Path]::GetTempPath()) "cursor-config-$(Get-Random)"
    New-Item -ItemType Directory -Path $tmpdir -Force | Out-Null
    $zipUrl = "$REPO_URL/archive/refs/heads/$REPO_BRANCH.zip"
    if ($REPO_BRANCH -match '^v\d') { $zipUrl = "$REPO_URL/archive/refs/tags/$REPO_BRANCH.zip" }
    Write-Info "Remote mode: downloading $REPO_OWNER/$REPO_NAME@$REPO_BRANCH..."
    $zipPath = Join-Path $tmpdir "source.zip"
    $ok = $false
    for ($i = 1; $i -le 3 -and -not $ok; $i++) {
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing
            $ok = $true
        } catch {
            if ($i -lt 3) { Write-Warn "download failed (attempt $i/3), retrying..."; Start-Sleep -Seconds 3 }
        }
    }
    if (-not $ok) { Write-Err "Failed to download source after retries. Cannot continue in remote mode."; exit 1 }
    Expand-Archive -Path $zipPath -DestinationPath $tmpdir -Force
    $extracted = Get-ChildItem -Path $tmpdir -Directory | Where-Object { $_.Name -ne "source.zip" } | Select-Object -First 1
    $script:SCRIPT_DIR = $extracted.FullName
    Write-Ok "Source downloaded to a temporary directory"
}

# Record the installed version so the `update` skill can compare against remote.
function Stamp-Version {
    $ver = Source-Version
    if ($ver -eq "unknown") { Write-Warn "no VERSION file in source - skipping version stamp"; return }
    if ($DryRun) { Write-Info "would write version stamp: $ver -> $VERSION_STAMP_FILE"; return }
    Set-Content -Path $VERSION_STAMP_FILE -Value $ver -Encoding UTF8
    Write-Ok "version stamped: $ver"
}

# On the FIRST install, copy any pre-existing managed file into the snapshot dir
# verbatim so -Uninstall can restore the true pre-install state on re-runs too.
function Snapshot-Originals {
    if (Test-Path $SNAPSHOT_DIR) { Write-Info "snapshot exists - keeping the original pre-install backup"; return }
    if ($DryRun) {
        foreach ($rel in $MANAGED_FILES) { if (Test-Path (Rel-Dst $rel)) { Write-Warn "would snapshot original: $rel" } }
        Write-Info "would create snapshot dir: $SNAPSHOT_DIR"; return
    }
    New-Item -ItemType Directory -Force -Path $SNAPSHOT_DIR | Out-Null
    foreach ($rel in $MANAGED_FILES) {
        $dst = Rel-Dst $rel
        if (Test-Path $dst) {
            $snap = Snap-Path $rel
            Ensure-Dir (Split-Path -Parent $snap)
            Copy-Item -Path $dst -Destination $snap -Force
            Write-Warn "snapshotted original $rel (for a clean uninstall)"
        }
    }
}

# Line-based manifest used by -Uninstall. file: lines derived from snapshot
# presence so they stay correct across updates.
function Write-Manifest {
    if ($DryRun) { Write-Info "would write manifest -> $MANIFEST_FILE"; return }
    $lines = @(
        "# awesome-claude-code-config (Cursor) install manifest",
        "# Used by 'install-cursor.ps1 -Uninstall'. Do not edit by hand.",
        "version=$(Source-Version)",
        "installed_at=$(Get-Date -Format o)",
        "cursor_home=$CURSOR_HOME"
    )
    foreach ($rel in $MANAGED_FILES) {
        if (Test-Path (Snap-Path $rel)) { $lines += "file:$rel`:preexisted" } else { $lines += "file:$rel`:created" }
    }
    $lines += $script:ManifestLines
    Set-Content -Path $MANIFEST_FILE -Value $lines -Encoding UTF8
    Write-Ok "manifest written -> $MANIFEST_FILE"
}

# --- Install steps ------------------------------------------------------
function Install-Agents { Copy-FileSafe (Join-Path $SCRIPT_DIR "AGENTS.md") (Join-Path $CURSOR_HOME "AGENTS.md") }

function Install-Rules {
    $srcroot = Join-Path $SCRIPT_DIR ".cursor\rules"
    if (-not (Test-Path $srcroot)) { Write-Warn "no .cursor/rules/ in source - skipping rules"; return }
    Ensure-Dir (Join-Path $CURSOR_HOME "rules")
    $count = 0
    foreach ($f in Get-ChildItem -Path $srcroot -Filter *.mdc -File) {
        if ($DryRun) { Write-Info "would install rule: $($f.Name)" }
        else { Copy-Item -Path $f.FullName -Destination (Join-Path $CURSOR_HOME "rules\$($f.Name)") -Force }
        MF-Add "rule:$($f.Name)"
        $count++
    }
    if (-not $DryRun) { Write-Ok "rules installed ($count files) -> $(Join-Path $CURSOR_HOME 'rules')" }
}

function Install-Skills {
    $srcroot = Join-Path $SCRIPT_DIR "skills"
    if (-not (Test-Path $srcroot)) { Write-Warn "no skills/ in source - skipping skills"; return }
    Ensure-Dir (Join-Path $CURSOR_HOME "skills")
    foreach ($d in Get-ChildItem -Path $srcroot -Directory) {
        $dst = Join-Path $CURSOR_HOME "skills\$($d.Name)"
        MF-Add "skill:$($d.Name)"
        if ($DryRun) { Write-Info "would install skill: $($d.Name) -> $dst"; continue }
        if (Test-Path $dst) { Remove-Item -Recurse -Force $dst }
        Copy-Item -Path $d.FullName -Destination $dst -Recurse -Force
        Write-Ok "skill: $($d.Name)"
    }
}

function Install-Mcp { Merge-Mcp (Join-Path $SCRIPT_DIR "mcp.json") (Join-Path $CURSOR_HOME "mcp.json") }

function Install-Hooks {
    Merge-Hooks (Join-Path $SCRIPT_DIR "hooks.json") (Join-Path $CURSOR_HOME "hooks.json")
    $srcroot = Join-Path $SCRIPT_DIR "hooks"
    if (-not (Test-Path $srcroot)) { return }
    Ensure-Dir (Join-Path $CURSOR_HOME "hooks")
    foreach ($f in Get-ChildItem -Path $srcroot -File) {
        MF-Add "hook:$($f.Name)"
        if ($DryRun) { Write-Info "would install hook script: $($f.Name)"; continue }
        Copy-Item -Path $f.FullName -Destination (Join-Path $CURSOR_HOME "hooks\$($f.Name)") -Force
    }
    if (-not $DryRun) { Write-Ok "hook scripts installed -> $(Join-Path $CURSOR_HOME 'hooks')" }
}

function Install-StatusLine { Copy-FileSafe (Join-Path $SCRIPT_DIR "hooks\statusline.sh") (Join-Path $CURSOR_HOME "statusline.sh") }

function Install-CliConfig {
    Merge-StatusLine (Join-Path $SCRIPT_DIR "cli-config.json") (Join-Path $CURSOR_HOME "cli-config.json")
    Set-StatusLineCommand
}

function Install-Lessons {
    $dst = Join-Path $CURSOR_HOME "lessons.md"
    if (Test-Path $dst) {
        Write-Info "lessons.md exists - preserving your corrections (never overwritten)"
        MF-Add "lessons:preexisted"
        return
    }
    Copy-FileSafe (Join-Path $SCRIPT_DIR "lessons.md") $dst
    MF-Add "lessons:seeded"
    if (-not $DryRun -and (Test-Path $SNAPSHOT_DIR)) {
        Set-Content -Path (Join-Path $SNAPSHOT_DIR ".lessons-seeded") -Value "" -Encoding UTF8
    }
}

# --- Uninstall ----------------------------------------------------------
function Confirm-Uninstall {
    if ($Force -or $DryRun) { return }
    $ans = Read-Host "Proceed with uninstall? [y/N]"
    if ($ans -notmatch '^(y|yes)$') { Write-Info "Cancelled."; exit 0 }
}

function Restore-OrDelete {
    param($rel)
    $dst = Rel-Dst $rel
    $snap = Snap-Path $rel
    if (Test-Path $snap) {
        if ($DryRun) { Write-Info "would restore original: $rel"; return }
        Ensure-Dir (Split-Path -Parent $dst)
        Copy-Item -Path $snap -Destination $dst -Force
        Write-Ok "restored original: $rel"
    } elseif (Test-Path $dst) {
        if ($DryRun) { Write-Info "would remove: $rel (installer-created)"; return }
        Remove-Item -Force $dst
        Write-Ok "removed: $rel"
    }
}

function Degraded-RemoveIfOurs {
    param($rel)
    $dst = Rel-Dst $rel
    if (-not (Test-Path $dst)) { return }
    $src = Source-PathFor $rel
    if ((Test-Path $src) -and (Files-Equal $src $dst)) {
        if ($DryRun) { Write-Info "would remove (matches shipped): $rel"; return }
        Remove-Item -Force $dst; Write-Ok "removed (unmodified): $rel"
    } else {
        Write-Warn "kept $rel - modified, merged, or pre-existing (remove manually if unwanted)"
    }
}

function Object-Empty { param($o) return (($o.PSObject.Properties | Measure-Object).Count -eq 0) }

function Degraded-CleanJson {
    param($rel, [scriptblock]$Mutate)
    $dst = Rel-Dst $rel
    if (-not (Test-Path $dst)) { return }
    if ($DryRun) { Write-Info "would surgically clean $rel"; return }
    $o = Read-Json $dst
    if ($null -eq $o) { Write-Warn "kept $rel - could not parse JSON"; return }
    & $Mutate $o
    if ((Object-Empty $o) -or (($o.PSObject.Properties.Name -eq "version") -and (($o.PSObject.Properties | Measure-Object).Count -eq 1))) {
        Remove-Item -Force $dst; Write-Ok "removed (now empty): $rel"
    } else {
        ($o | ConvertTo-Json -Depth 20) | Set-Content -Path $dst -Encoding UTF8
        Write-Ok "cleaned our entries from: $rel"
    }
}

function Run-Uninstall {
    $mode = "normal"
    if (-not (Test-Path $MANIFEST_FILE) -or -not (Test-Path $SNAPSHOT_DIR)) { $mode = "degraded" }

    Write-Host "  target: $CURSOR_HOME"
    if ($mode -eq "degraded") {
        Write-Warn "No install manifest/snapshot found under $CURSOR_HOME."
        Write-Warn "This config was likely installed with an older installer that did not record one."
        Write-Warn "Falling back to best-effort removal: only files identical to the shipped"
        Write-Warn "versions are removed; anything you modified or that pre-existed is LEFT IN PLACE."
        if (-not (Test-Path $VERSION_STAMP_FILE) -and -not (Test-Path (Join-Path $CURSOR_HOME "rules")) -and -not (Test-Path (Join-Path $CURSOR_HOME "skills"))) {
            Write-Err "Nothing here looks installed by this config. Aborting."; exit 1
        }
    }
    if ($DryRun) { Write-Warn "DRY RUN - nothing will be removed" }
    Write-Host ""
    Confirm-Uninstall

    if ($mode -eq "normal") {
        foreach ($rel in $MANAGED_FILES) { Restore-OrDelete $rel }
        foreach ($line in (Get-Content -Path $MANIFEST_FILE)) {
            if ($line -like "rule:*") {
                $name = $line.Substring(5)
                if ($DryRun) { Write-Info "would remove rule: $name" } else { Remove-Item -Force (Join-Path $CURSOR_HOME "rules\$name") -ErrorAction SilentlyContinue }
            } elseif ($line -like "skill:*") {
                $name = $line.Substring(6)
                if ($DryRun) { Write-Info "would remove skill: $name" } else { Remove-Item -Recurse -Force (Join-Path $CURSOR_HOME "skills\$name") -ErrorAction SilentlyContinue }
            }
        }
        if (-not $DryRun) { Write-Ok "removed installed rules and skills" }
    } else {
        Degraded-RemoveIfOurs "AGENTS.md"
        Degraded-RemoveIfOurs "statusline.sh"
        Degraded-RemoveIfOurs "hooks/load-lessons.sh"
        Degraded-RemoveIfOurs "hooks/statusline.sh"
        Degraded-CleanJson "mcp.json" {
            param($o)
            if ($o.mcpServers) {
                foreach ($k in @("context7", "playwright")) { if ($o.mcpServers.PSObject.Properties.Name -contains $k) { $o.mcpServers.PSObject.Properties.Remove($k) } }
                if (Object-Empty $o.mcpServers) { $o.PSObject.Properties.Remove("mcpServers") }
            }
        }
        Degraded-CleanJson "hooks.json" {
            param($o)
            if ($o.hooks -and $o.hooks.sessionStart) {
                $kept = @($o.hooks.sessionStart | Where-Object { $_.command -ne "./hooks/load-lessons.sh" })
                if ($kept.Count -eq 0) { $o.hooks.PSObject.Properties.Remove("sessionStart") }
                else { $o.hooks.sessionStart = $kept }
                if (Object-Empty $o.hooks) { $o.PSObject.Properties.Remove("hooks") }
            }
        }
        Degraded-CleanJson "cli-config.json" { param($o) if ($o.statusLine) { $o.PSObject.Properties.Remove("statusLine") } }
        if (Test-Path (Join-Path $SCRIPT_DIR ".cursor\rules")) {
            foreach ($f in Get-ChildItem -Path (Join-Path $SCRIPT_DIR ".cursor\rules") -Filter *.mdc -File) {
                $t = Join-Path $CURSOR_HOME "rules\$($f.Name)"
                if ((Test-Path $t) -and (Files-Equal $f.FullName $t)) {
                    if ($DryRun) { Write-Info "would remove rule: $($f.Name)" } else { Remove-Item -Force $t }
                }
            }
        }
        if (Test-Path (Join-Path $SCRIPT_DIR "skills")) {
            foreach ($d in Get-ChildItem -Path (Join-Path $SCRIPT_DIR "skills") -Directory) {
                $t = Join-Path $CURSOR_HOME "skills\$($d.Name)"
                if (Test-Path $t) {
                    $diff = $null
                    try { $diff = Compare-Object (Get-ChildItem -Recurse $d.FullName | Get-FileHash) (Get-ChildItem -Recurse $t | Get-FileHash) -Property Hash } catch { $diff = "err" }
                    if (-not $diff) { if ($DryRun) { Write-Info "would remove skill: $($d.Name)" } else { Remove-Item -Recurse -Force $t } }
                    else { Write-Warn "kept skill $($d.Name) - modified or pre-existing" }
                }
            }
        }
    }

    # lessons.md - kept unless seeded by us and -PurgeLessons.
    if ((Test-Path (Join-Path $SNAPSHOT_DIR ".lessons-seeded")) -and $PurgeLessons) {
        if ($DryRun) { Write-Info "would remove seeded lessons.md" } else { Remove-Item -Force (Join-Path $CURSOR_HOME "lessons.md") -ErrorAction SilentlyContinue; Write-Ok "removed seeded lessons.md" }
    } elseif (Test-Path (Join-Path $CURSOR_HOME "lessons.md")) {
        Write-Info "kept lessons.md (your corrections; use -PurgeLessons to drop a seeded one)"
    }

    if (-not $DryRun) {
        Remove-Item -Force $VERSION_STAMP_FILE -ErrorAction SilentlyContinue
        Remove-Item -Force $MANIFEST_FILE -ErrorAction SilentlyContinue
        Remove-Item -Recurse -Force $SNAPSHOT_DIR -ErrorAction SilentlyContinue
        foreach ($d in @("rules", "hooks", "skills", "bin")) {
            $p = Join-Path $CURSOR_HOME $d
            if ((Test-Path $p) -and -not (Get-ChildItem -Force $p)) { Remove-Item -Force $p -ErrorAction SilentlyContinue }
        }
    }

    Write-Host ""
    if ($DryRun) { Write-Ok "Dry run complete - nothing was changed." }
    else { Write-Ok "Uninstalled. Restart Cursor (or reload the window) to apply." }
    Write-Host ""
}

# --- Main ---------------------------------------------------------------
Write-Host ""
Write-Host "=== Awesome Claude Code Config - Cursor Installer ===" -ForegroundColor White

if ($Uninstall) {
    # Only fetch the repo source if we need it for degraded-mode comparison.
    if (-not (Test-Path $MANIFEST_FILE) -or -not (Test-Path $SNAPSHOT_DIR)) { Initialize-ScriptDir }
    Run-Uninstall
    exit 0
}

Initialize-ScriptDir

Write-Host "  source: $SCRIPT_DIR"
Write-Host "  target: $CURSOR_HOME"
if ($DryRun) { Write-Warn "DRY RUN - no changes will be made" }
Write-Host ""

if (-not (Test-Path (Join-Path $SCRIPT_DIR "AGENTS.md"))) {
    Write-Err "Source is missing AGENTS.md - cannot continue."
    exit 1
}

Ensure-Dir $CURSOR_HOME
Snapshot-Originals
Install-Agents
Install-Rules
Install-Skills
Install-Mcp
Install-Hooks
Install-StatusLine
Install-CliConfig
Install-Lessons
Write-Manifest
Stamp-Version

Write-Host ""
if ($DryRun) { Write-Ok "Dry run complete - nothing was changed." }
else { Write-Ok "Cursor configuration installed to $CURSOR_HOME" }
Write-Host ""
Write-Info "Next steps:"
Write-Host "  1. Restart Cursor (or reload the window) so it picks up the new config."
Write-Host "  2. Enable MCP servers from Cursor Settings if prompted."
Write-Host "  3. The status line script (statusline.sh) needs a bash runtime (e.g. Git Bash) on Windows."
Write-Host ""
Write-Info "To undo later: .\install-cursor.ps1 -Uninstall  (restores the pre-install state)"
Write-Host ""
