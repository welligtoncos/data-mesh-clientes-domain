#Requires -Version 5.1
param([switch]$SkipApply, [switch]$SkipAwsTests, [switch]$SkipAthena)
$Root = Split-Path $PSScriptRoot -Parent
$TfDir = Join-Path $Root "terraform\environments\dev"
$script:Passed=0; $script:Failed=0
function Step($n,$ok,$d="") { if($ok){$script:Passed++;Write-Host "[PASS] $n" -F Green}else{$script:Failed++;Write-Host "[FAIL] $n$(if($d){" - $d"})" -F Red}}
Write-Host "`n=== DM-005 Automated Validation Suite ===`n" -F Cyan
Push-Location (Join-Path $Root "terraform"); terraform fmt -recursive 2>$null; Step "terraform fmt -check" ($LASTEXITCODE -eq 0); Pop-Location
Push-Location $TfDir; terraform init -input=false 2>$null; terraform validate 2>$null; Step "terraform validate" ($LASTEXITCODE -eq 0)
if (-not $SkipApply) { terraform apply -auto-approve -input=false 2>$null; Step "terraform apply" ($LASTEXITCODE -eq 0) }
terraform plan -detailed-exitcode -input=false 2>$null; Step "terraform plan idempotente" ($LASTEXITCODE -eq 0); Pop-Location
if (-not $SkipAwsTests) {
    $a = @("-File",(Join-Path $PSScriptRoot "Validate-DM005Aws.ps1"))
    if ($SkipAthena) { $a += "-SkipAthena" }
    & powershell @a; Step "Validacao AWS DM-005" ($LASTEXITCODE -eq 0)
}
Write-Host "`nResultado: $($script:Passed) passed, $($script:Failed) failed" -F Cyan
if ($script:Failed -gt 0) { exit 1 }
