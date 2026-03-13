#Requires -Version 5.1
# Lightweight check that README.md and README.zh-CN.md stay structurally in sync.

$ErrorActionPreference = "Stop"

$DIR = Split-Path -Parent $PSScriptRoot
$EN  = Join-Path $DIR "README.md"
$ZH  = Join-Path $DIR "README.zh-CN.md"

$ok = $true

function Compare-Count {
    param([string]$Label, [int]$EnCount, [int]$ZhCount)
    if ($EnCount -ne $ZhCount) {
        Write-Host "MISMATCH ${Label}: EN=$EnCount ZH=$ZhCount"
        $script:ok = $false
    } else {
        Write-Host "OK       ${Label}: $EnCount"
    }
}

$enLines = Get-Content $EN
$zhLines = Get-Content $ZH
$enRaw   = Get-Content $EN -Raw
$zhRaw   = Get-Content $ZH -Raw

# Headings: lines starting with #
$enHeadings = ($enLines | Where-Object { $_ -match '^#' }).Count
$zhHeadings = ($zhLines | Where-Object { $_ -match '^#' }).Count
Compare-Count "Headings" $enHeadings $zhHeadings

# Code blocks: lines starting with ```
$enCodeBlocks = ($enLines | Where-Object { $_ -match '^```' }).Count
$zhCodeBlocks = ($zhLines | Where-Object { $_ -match '^```' }).Count
Compare-Count "Code blocks" $enCodeBlocks $zhCodeBlocks

# Table rows: lines starting with |
$enTableRows = ($enLines | Where-Object { $_ -match '^\|' }).Count
$zhTableRows = ($zhLines | Where-Object { $_ -match '^\|' }).Count
Compare-Count "Table rows" $enTableRows $zhTableRows

# Links: [text](url) pattern
$enLinks = ([regex]::Matches($enRaw, '\[.*?\]\(.*?\)')).Count
$zhLinks = ([regex]::Matches($zhRaw, '\[.*?\]\(.*?\)')).Count
Compare-Count "Links" $enLinks $zhLinks

if ($ok) {
    Write-Host "All checks passed."
    exit 0
} else {
    Write-Host "Structural differences found."
    exit 1
}
