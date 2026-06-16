#Requires -Version 5.1
param(
    [switch]$SkipApply,
    [switch]$SkipAwsTests,
    [switch]$RunPublish,
    [switch]$SkipAthena
)

$RootDir = Split-Path $PSScriptRoot -Parent
$TerraformDir = Join-Path $RootDir "terraform\environments\dev"
$TerraformRoot = Join-Path $RootDir "terraform"
$script:Passed = 0; $script:Failed = 0

function Write-StepResult {
    param([string]$Name, [bool]$Success, [string]$Detail = "")
    if ($Success) { $script:Passed++; Write-Host "[PASS] $Name" -ForegroundColor Green }
    else { $script:Failed++; $m = "[FAIL] $Name"; if ($Detail) { $m += " - $Detail" }; Write-Host $m -ForegroundColor Red }
}

Write-Host "`n=== DM-003 Automated Validation Suite ===`n" -ForegroundColor Cyan

Push-Location $TerraformRoot
terraform fmt -check -recursive 2>&1 | Out-Null
Write-StepResult -Name "terraform fmt -check" -Success ($LASTEXITCODE -eq 0)
Pop-Location

Push-Location $TerraformDir
terraform init -input=false 2>&1 | Out-Null
terraform validate -no-color 2>&1 | Out-Null
Write-StepResult -Name "terraform validate" -Success ($LASTEXITCODE -eq 0)

if (-not $SkipApply) {
    terraform apply -auto-approve -input=false -no-color 2>&1 | Out-Null
    Write-StepResult -Name "terraform apply" -Success ($LASTEXITCODE -eq 0)
}

terraform plan -detailed-exitcode -input=false -no-color 2>&1 | Out-Null
Write-StepResult -Name "terraform plan idempotente" -Success ($LASTEXITCODE -eq 0)
Pop-Location

if (-not $SkipAwsTests) {
    $args = @("-File", (Join-Path $PSScriptRoot "Validate-DM003Aws.ps1"))
    if ($RunPublish) { $args += "-RunPublish" }
    if ($SkipAthena) { $args += "-SkipAthena" }
    & powershell @args
    Write-StepResult -Name "Validacao AWS DM-003" -Success ($LASTEXITCODE -eq 0)
}

Write-Host "`nResultado: $script:Passed passed, $script:Failed failed" -ForegroundColor Cyan
if ($script:Failed -gt 0) { exit 1 }
