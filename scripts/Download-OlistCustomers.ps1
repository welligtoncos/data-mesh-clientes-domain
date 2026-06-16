#Requires -Version 5.1
<#
.SYNOPSIS
    Baixa o dataset Olist customers para ingestao DM-002.
#>
param(
    [string]$OutputPath = (Join-Path $PSScriptRoot "..\data\raw\customers.csv"),
    [string]$SourceUrl = "https://raw.githubusercontent.com/olist/work-at-olist-data/master/datasets/olist_customers_dataset.csv"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$outputDir = Split-Path $OutputPath -Parent
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

Write-Host "Downloading Olist customers dataset..."
Invoke-WebRequest -Uri $SourceUrl -OutFile $OutputPath -UseBasicParsing

$lineCount = (Get-Content $OutputPath | Measure-Object -Line).Lines - 1
Write-Host "Saved to: $OutputPath"
Write-Host "Records (excluding header): $lineCount"
