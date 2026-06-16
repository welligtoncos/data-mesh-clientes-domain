#Requires -Version 5.1
<#
.SYNOPSIS
    Orquestrador de testes automatizados DM-002 (ingestao customer).
#>
param(
    [switch]$SkipAwsTests,
    [switch]$SkipApply,
    [switch]$RunIngestion,
    [switch]$SkipAthena
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RootDir       = Split-Path $PSScriptRoot -Parent
$TerraformDir  = Join-Path $RootDir "terraform\environments\dev"
$TerraformRoot = Join-Path $RootDir "terraform"

$script:Passed = 0
$script:Failed = 0

function Write-StepResult {
    param([string]$Name, [bool]$Success, [string]$Detail = "")
    if ($Success) {
        $script:Passed++
        Write-Host "[PASS] $Name" -ForegroundColor Green
    }
    else {
        $script:Failed++
        $msg = "[FAIL] $Name"
        if ($Detail) { $msg += " - $Detail" }
        Write-Host $msg -ForegroundColor Red
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host " DM-002 Automated Validation Suite" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Push-Location $TerraformRoot
try {
    terraform fmt -check -recursive 2>&1 | Out-Null
    Write-StepResult -Name "terraform fmt -check" -Success ($LASTEXITCODE -eq 0)
}
catch {
    Write-StepResult -Name "terraform fmt -check" -Success $false -Detail $_.Exception.Message
}
Pop-Location

Push-Location $TerraformDir
try {
    if (-not (Test-Path ".terraform")) {
        terraform init -input=false 2>&1 | Out-Null
    }
    terraform validate -no-color 2>&1 | Out-Null
    Write-StepResult -Name "terraform validate" -Success ($LASTEXITCODE -eq 0)
}
catch {
    Write-StepResult -Name "terraform validate" -Success $false -Detail $_.Exception.Message
}

if (-not $SkipApply) {
    try {
        terraform apply -auto-approve -input=false -no-color 2>&1 | Out-Null
        Write-StepResult -Name "terraform apply" -Success ($LASTEXITCODE -eq 0)
    }
    catch {
        Write-StepResult -Name "terraform apply" -Success $false -Detail $_.Exception.Message
    }
}

try {
    terraform plan -detailed-exitcode -input=false -no-color 2>&1 | Out-Null
    $planOk = $LASTEXITCODE -eq 0
    Write-StepResult -Name "terraform plan idempotente" -Success $planOk `
        -Detail $(if (-not $planOk) { "Plano contem alteracoes" } else { "" })
}
catch {
    Write-StepResult -Name "terraform plan idempotente" -Success $false -Detail $_.Exception.Message
}
Pop-Location

if (-not $SkipAwsTests) {
    $awsArgs = @("-File", (Join-Path $PSScriptRoot "Validate-DM002Aws.ps1"))
    if ($RunIngestion) { $awsArgs += "-RunIngestion" }
    if ($SkipAthena) { $awsArgs += "-SkipAthena" }

    & powershell @awsArgs
    if ($LASTEXITCODE -eq 0) {
        Write-StepResult -Name "Validacao AWS DM-002" -Success $true
    }
    else {
        Write-StepResult -Name "Validacao AWS DM-002" -Success $false -Detail "Ver detalhes acima"
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host " Resultado Final: $script:Passed passed, $script:Failed failed" -ForegroundColor $(if ($script:Failed -gt 0) { "Red" } else { "Green" })
Write-Host "========================================`n" -ForegroundColor Cyan

if ($script:Failed -gt 0) { exit 1 }
exit 0
