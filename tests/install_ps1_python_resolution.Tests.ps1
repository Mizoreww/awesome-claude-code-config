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

$testPythonText = Get-FunctionText -Path $installerPath -Name "Test-PythonCommand"
$resolvePythonText = Get-FunctionText -Path $installerPath -Name "Resolve-PythonCommand"
Assert-True ($null -ne $testPythonText) "install.ps1 should define Test-PythonCommand"
Assert-True ($null -ne $resolvePythonText) "install.ps1 should define Resolve-PythonCommand"
Invoke-Expression $testPythonText
Invoke-Expression $resolvePythonText

$tempDir = Join-Path $env:TEMP ("codex-python-resolution-test-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
$oldPath = $env:PATH
try {
    @"
@echo off
exit /b 9009
"@ | Set-Content -Path (Join-Path $tempDir "python3.cmd") -Encoding ASCII

    @"
@echo off
if "%1"=="-c" exit /b 0
echo Python 3.12.0
exit /b 0
"@ | Set-Content -Path (Join-Path $tempDir "python.cmd") -Encoding ASCII

    $env:PATH = "$tempDir;$oldPath"
    $resolved = Resolve-PythonCommand

    Assert-True ($null -ne $resolved) "Resolve-PythonCommand should find a working fallback Python"
    Assert-True ($resolved.Count -ge 1) "Resolve-PythonCommand should return command tokens"
    Assert-True ((Split-Path -Leaf $resolved[0]) -eq "python.cmd") "Resolve-PythonCommand should skip a non-working python3 command and use python"
} finally {
    $env:PATH = $oldPath
    Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue
}

$badPythonDir = Join-Path $env:TEMP ("codex-bad-python-test-" + [guid]::NewGuid().ToString("N"))
$goodPythonDir = Join-Path $env:TEMP ("codex-good-python-test-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $badPythonDir -Force | Out-Null
New-Item -ItemType Directory -Path $goodPythonDir -Force | Out-Null
try {
    @"
@echo off
exit /b 9009
"@ | Set-Content -Path (Join-Path $badPythonDir "python.cmd") -Encoding ASCII

    @"
@echo off
if "%1"=="-c" exit /b 0
echo Python 3.12.0
exit /b 0
"@ | Set-Content -Path (Join-Path $goodPythonDir "python.cmd") -Encoding ASCII

    $env:PATH = "$badPythonDir;$goodPythonDir;$oldPath"
    $resolved = Resolve-PythonCommand

    Assert-True ($null -ne $resolved) "Resolve-PythonCommand should scan past a bad python command"
    Assert-True ($resolved[0] -eq (Join-Path $goodPythonDir "python.cmd")) "Resolve-PythonCommand should use a later working python command when an earlier one fails"
} finally {
    $env:PATH = $oldPath
    Remove-Item -Recurse -Force $badPythonDir -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force $goodPythonDir -ErrorAction SilentlyContinue
}

$badPyLauncherDir = Join-Path $env:TEMP ("codex-bad-py-launcher-test-" + [guid]::NewGuid().ToString("N"))
$goodPyLauncherDir = Join-Path $env:TEMP ("codex-good-py-launcher-test-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $badPyLauncherDir -Force | Out-Null
New-Item -ItemType Directory -Path $goodPyLauncherDir -Force | Out-Null
try {
    @"
@echo off
exit /b 9009
"@ | Set-Content -Path (Join-Path $badPyLauncherDir "py.cmd") -Encoding ASCII

    @"
@echo off
if "%1"=="-3" shift
if "%1"=="-c" exit /b 0
echo Python 3.12.0
exit /b 0
"@ | Set-Content -Path (Join-Path $goodPyLauncherDir "py.cmd") -Encoding ASCII

    $env:PATH = "$badPyLauncherDir;$goodPyLauncherDir;$oldPath"
    $resolved = Resolve-PythonCommand

    Assert-True ($null -ne $resolved) "Resolve-PythonCommand should scan past a bad py launcher"
    Assert-True ($resolved[0] -eq (Join-Path $goodPyLauncherDir "py.cmd")) "Resolve-PythonCommand should use a later working py launcher when an earlier one fails"
    Assert-True ($resolved.Count -eq 2 -and $resolved[1] -eq "-3") "Resolve-PythonCommand should preserve py launcher -3 argument"
} finally {
    $env:PATH = $oldPath
    Remove-Item -Recurse -Force $badPyLauncherDir -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force $goodPyLauncherDir -ErrorAction SilentlyContinue
}

Write-Host "install.ps1 Python resolution tests passed"
