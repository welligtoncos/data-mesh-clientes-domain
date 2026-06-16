#Requires -Version 5.1
<#
.SYNOPSIS
    Orquestrador de testes automatizados DM-001.

.DESCRIPTION
    Executa em sequencia:
      1. terraform fmt -check
      2. terraform validate
      3. terraform apply
      4. terraform plan idempotente
      5. Validacao AWS via AWS CLI (S3, Glue, IAM, Lake Formation)

.PARAMETER SkipAwsTests
    Pula validacao contra recursos reais na AWS.

.PARAMETER SkipAssumeRole
    Pula testes de assume-role na validacao AWS.

.PARAMETER SkipApply
    Pula terraform apply antes do plan idempotente.
#>
param(
    [switch]$SkipAwsTests,
    [switch]$SkipAssumeRole,
    [switch]$SkipApply
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RootDir       = Split-Path $PSScriptRoot -Parent
$TerraformDir  = Join-Path $RootDir "terraform\environments\dev"
$TerraformRoot = Join-Path $RootDir "terraform"

$script:Passed = 0
$script:Failed = 0

function Write-StepResult {
    param(
        [string]$Name,
        [bool]$Success,
        [string]$Detail = ""
    )

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

function Test-CommandExists {
    param([string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host " DM-001 Automated Validation Suite" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

if (-not (Test-CommandExists "terraform")) {
    Write-Error "terraform não encontrado no PATH."
    exit 1
}

# 1. terraform fmt -check
Push-Location $TerraformRoot
try {
    terraform fmt -check -recursive 2>&1 | Out-Null
    Write-StepResult -Name "terraform fmt -check" -Success ($LASTEXITCODE -eq 0) `
        -Detail $(if ($LASTEXITCODE -ne 0) { "Execute: terraform fmt -recursive" } else { "" })
}
catch {
    Write-StepResult -Name "terraform fmt -check" -Success $false -Detail $_.Exception.Message
}
Pop-Location

# 2. terraform init (se necessário)
Push-Location $TerraformDir
try {
    if (-not (Test-Path ".terraform")) {
        terraform init -input=false 2>&1 | Out-Null
        Write-StepResult -Name "terraform init" -Success ($LASTEXITCODE -eq 0)
    }
    else {
        Write-StepResult -Name "terraform init (já inicializado)" -Success $true
    }
}
catch {
    Write-StepResult -Name "terraform init" -Success $false -Detail $_.Exception.Message
}

# 3. terraform validate
try {
    terraform validate -no-color 2>&1 | Out-Null
    Write-StepResult -Name "terraform validate" -Success ($LASTEXITCODE -eq 0)
}
catch {
    Write-StepResult -Name "terraform validate" -Success $false -Detail $_.Exception.Message
}

# 4. terraform apply (garante estado sincronizado antes do plan)
if (-not $SkipApply) {
    try {
        terraform apply -auto-approve -input=false -no-color 2>&1 | Out-Null
        Write-StepResult -Name "terraform apply" -Success ($LASTEXITCODE -eq 0)
    }
    catch {
        Write-StepResult -Name "terraform apply" -Success $false -Detail $_.Exception.Message
    }
}
else {
    Write-Host "[SKIP] terraform apply (SkipApply)" -ForegroundColor Yellow
}

# 5. terraform plan idempotente (exit 0 = sem alteracoes)
try {
    terraform plan -detailed-exitcode -input=false -no-color 2>&1 | Out-Null
    $planExitCode = $LASTEXITCODE

    if ($planExitCode -eq 0) {
        Write-StepResult -Name "terraform plan idempotente (sem alteracoes)" -Success $true
    }
    elseif ($planExitCode -eq 2) {
        Write-StepResult -Name "terraform plan idempotente (sem alteracoes)" -Success $false -Detail "Plano contem alteracoes pendentes"
    }
    else {
        Write-StepResult -Name "terraform plan idempotente (sem alteracoes)" -Success $false -Detail "Erro ao executar terraform plan"
    }
}
catch {
    Write-StepResult -Name "terraform plan idempotente (sem alteracoes)" -Success $false -Detail $_.Exception.Message
}

Pop-Location

# 6. Validação AWS
if (-not $SkipAwsTests) {
    if (-not (Test-CommandExists "aws")) {
        Write-StepResult -Name "AWS CLI disponível" -Success $false -Detail "aws CLI não encontrado"
    }
    else {
        Write-StepResult -Name "AWS CLI disponível" -Success $true

        $awsScript = Join-Path $PSScriptRoot "Validate-DM001Aws.ps1"
        $awsArgs = @("-File", $awsScript)
        if ($SkipAssumeRole) { $awsArgs += "-SkipAssumeRole" }

        & powershell @awsArgs
        if ($LASTEXITCODE -eq 0) {
            Write-StepResult -Name "Validação AWS (S3, Glue, IAM, LF)" -Success $true
        }
        else {
            Write-StepResult -Name "Validação AWS (S3, Glue, IAM, LF)" -Success $false -Detail "Ver detalhes acima"
        }
    }
}
else {
    Write-Host "[SKIP] Validação AWS (SkipAwsTests)" -ForegroundColor Yellow
}

# Resumo final
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host " Resultado Final: $script:Passed passed, $script:Failed failed" -ForegroundColor $(if ($script:Failed -gt 0) { "Red" } else { "Green" })
Write-Host "========================================`n" -ForegroundColor Cyan

if ($script:Failed -gt 0) {
    exit 1
}

exit 0
