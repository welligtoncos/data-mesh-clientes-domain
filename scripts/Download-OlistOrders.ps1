#Requires -Version 5.1
param(
    [string]$OutputPath = (Join-Path $PSScriptRoot "..\data\raw\orders.csv"),
    [string]$SourceUrl = "https://raw.githubusercontent.com/olist/work-at-olist-data/master/datasets/olist_orders_dataset.csv"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$outputDir = Split-Path $OutputPath -Parent
if (-not (Test-Path $outputDir)) { New-Item -ItemType Directory -Path $outputDir -Force | Out-Null }

Write-Host "Downloading Olist orders dataset..."
Invoke-WebRequest -Uri $SourceUrl -OutFile $OutputPath -UseBasicParsing
Write-Host "Saved to: $OutputPath"
