#Requires -Version 5.1
param([switch]$SkipApply, [switch]$SkipHttp)
$testScript = Join-Path $PSScriptRoot "..\..\..\tests\Run-DM006Tests.ps1"
if (-not (Test-Path $testScript)) { Write-Error "Nao encontrado: $testScript"; exit 1 }
$a = @("-File", $testScript)
if ($SkipApply) { $a += "-SkipApply" }
if ($SkipHttp) { $a += "-SkipHttp" }
& powershell @a; exit $LASTEXITCODE
