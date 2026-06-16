#Requires -Version 5.1
param([switch]$SkipApply, [switch]$RunPublish, [switch]$SkipAthena)
$testScript = Join-Path $PSScriptRoot "..\..\..\tests\Run-DM004Tests.ps1"
if (-not (Test-Path $testScript)) { Write-Error "Nao encontrado: $testScript"; exit 1 }
$a = @("-File", $testScript)
if ($SkipApply) { $a += "-SkipApply" }
if ($RunPublish) { $a += "-RunPublish" }
if ($SkipAthena) { $a += "-SkipAthena" }
& powershell @a; exit $LASTEXITCODE
