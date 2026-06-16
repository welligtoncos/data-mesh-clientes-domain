#Requires -Version 5.1
param([switch]$SkipApply, [switch]$SkipAthena)
$testScript = Join-Path $PSScriptRoot "..\..\..\tests\Run-DM005Tests.ps1"
if (-not (Test-Path $testScript)) { Write-Error "Nao encontrado: $testScript"; exit 1 }
$a = @("-File", $testScript)
if ($SkipApply) { $a += "-SkipApply" }
if ($SkipAthena) { $a += "-SkipAthena" }
& powershell @a; exit $LASTEXITCODE
