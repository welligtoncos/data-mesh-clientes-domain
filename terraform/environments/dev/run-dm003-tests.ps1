#Requires -Version 5.1
<#
.SYNOPSIS
    Executa os testes DM-003 a partir do diretorio do environment dev.
#>
param(
    [switch]$SkipApply,
    [switch]$SkipAwsTests,
    [switch]$RunPublish,
    [switch]$SkipAthena
)

$testScript = Join-Path $PSScriptRoot "..\..\..\tests\Run-DM003Tests.ps1"

if (-not (Test-Path $testScript)) {
    Write-Error "Script de testes nao encontrado: $testScript"
    exit 1
}

$args = @("-File", $testScript)
if ($SkipApply) { $args += "-SkipApply" }
if ($SkipAwsTests) { $args += "-SkipAwsTests" }
if ($RunPublish) { $args += "-RunPublish" }
if ($SkipAthena) { $args += "-SkipAthena" }

& powershell @args
exit $LASTEXITCODE
