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

foreach ($name in @("Get-NodeMajorVersion", "Add-PlaywrightMcpServer")) {
    $functionText = Get-FunctionText -Path $installerPath -Name $name
    Assert-True ($null -ne $functionText) "install.ps1 should define $name"
    Invoke-Expression $functionText
}

$script:PLAYWRIGHT_MCP_VERSION = "0.0.78"
$script:PLAYWRIGHT_MIN_NODE_MAJOR = 20
$script:PLAYWRIGHT_NODE_FALLBACK_VERSION = "24"
$script:MCP_FAILED_SERVERS = @()
$script:NodeVersion = "v18.19.1"
$script:NpxExitCode = 0
$script:NpxReturnsInitialize = $true
$script:NpxArguments = @()
$script:NpxRequest = ""
$script:RegisteredName = $null
$script:RegisteredArguments = @()
$script:Warnings = @()
$DryRun = $false

function Write-Warn {
    param($Message)
    $script:Warnings += $Message
}

function node {
    $global:LASTEXITCODE = 0
    return $script:NodeVersion
}

function npx {
    $script:NpxArguments = @($args)
    $script:NpxRequest = @($input) -join "`n"
    $global:LASTEXITCODE = $script:NpxExitCode
    if ($script:NpxExitCode -eq 0 -and
        $script:NpxReturnsInitialize -and
        $script:NpxRequest -like '*"method":"initialize"*') {
        return '{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":"2025-06-18","capabilities":{"tools":{}},"serverInfo":{"name":"Playwright","version":"test"}}}'
    }
}

function Add-McpServer {
    param([string]$Name, [string[]]$Arguments)
    $script:RegisteredName = $Name
    $script:RegisteredArguments = @($Arguments)
}

function Reset-Case {
    $script:MCP_FAILED_SERVERS = @()
    $script:NpxArguments = @()
    $script:NpxRequest = ""
    $script:RegisteredName = $null
    $script:RegisteredArguments = @()
    $script:Warnings = @()
    $script:NpxExitCode = 0
    $script:NpxReturnsInitialize = $true
}

Reset-Case
$script:NodeVersion = "v18.19.1"
Add-PlaywrightMcpServer
Assert-True ($script:NpxRequest -like '*"method":"initialize"*') "Node 18 probe should send initialize"
Assert-True ($script:NpxArguments -contains "--package=node@24") "Node 18 should use the isolated Node 24 runtime"
Assert-True ($script:NpxArguments -contains "--package=@playwright/mcp@0.0.78") "Node 18 should pin Playwright MCP"
Assert-True ($script:RegisteredName -eq "playwright") "successful Node 18 initialize should register Playwright"
Assert-True ($script:RegisteredArguments -contains "--package=node@24") "registered Node 18 command should preserve the fallback runtime"

Reset-Case
$script:NodeVersion = "v24.12.0"
Add-PlaywrightMcpServer
Assert-True ($script:NpxRequest -like '*"method":"initialize"*') "Node 24 probe should send initialize"
Assert-True (-not ($script:NpxArguments -contains "--package=node@24")) "Node 24 should use the direct launcher"
Assert-True ($script:NpxArguments -contains "@playwright/mcp@0.0.78") "Node 24 should pin Playwright MCP"
Assert-True ($script:RegisteredName -eq "playwright") "successful Node 24 initialize should register Playwright"

Reset-Case
$script:NodeVersion = "v24.12.0"
$script:NpxReturnsInitialize = $false
Add-PlaywrightMcpServer
Assert-True ($null -eq $script:RegisteredName) "missing initialize response must not register Playwright"
Assert-True ($script:MCP_FAILED_SERVERS -contains "playwright") "missing initialize response should record failure"
Assert-True ($script:Warnings -contains "Playwright MCP initialize check failed; not registering a broken server") "missing initialize response should warn"

Reset-Case
$script:NodeVersion = "v24.12.0"
$script:NpxExitCode = 1
Add-PlaywrightMcpServer
Assert-True ($null -eq $script:RegisteredName) "non-zero launcher exit must not register Playwright"
Assert-True ($script:MCP_FAILED_SERVERS -contains "playwright") "non-zero launcher exit should record failure"

Write-Host "install.ps1 Playwright MCP tests passed"
