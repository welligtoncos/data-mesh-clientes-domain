#Requires -Version 5.1
param(
    [string]$TerraformDir = (Join-Path $PSScriptRoot "..\terraform\environments\dev"),
    [switch]$SkipAthena
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:Passed = 0; $script:Failed = 0

function Write-TestResult {
    param([string]$Name, [bool]$Success, [string]$Detail = "")
    if ($Success) { $script:Passed++; Write-Host "[PASS] $Name" -ForegroundColor Green }
    else { $script:Failed++; $m = "[FAIL] $Name"; if ($Detail) { $m += " - $Detail" }; Write-Host $m -ForegroundColor Red }
}

function Invoke-AwsJson { param([string[]]$Arguments)
    $o = & aws @Arguments --output json 2>&1
    if ($LASTEXITCODE -ne 0) { throw ($o | Out-String).Trim() }
    if ([string]::IsNullOrWhiteSpace($o)) { return $null }
    return $o | ConvertFrom-Json
}

function Get-TerraformOutput { param([string]$Name)
    Push-Location $TerraformDir
    try { return (terraform output -raw $Name).Trim() }
    finally { Pop-Location }
}

function Invoke-LfListPermissions { param([hashtable]$Resource)
    $temp = [System.IO.Path]::ChangeExtension([System.IO.Path]::GetTempFileName(), ".json")
    try {
        [System.IO.File]::WriteAllText($temp, ($Resource | ConvertTo-Json -Compress -Depth 5), [System.Text.UTF8Encoding]::new($false))
        $uri = "file://$($temp -replace '\\','/')"
        return Invoke-AwsJson @("lakeformation", "list-permissions", "--resource", $uri)
    }
    finally { Remove-Item $temp -Force -ErrorAction SilentlyContinue }
}

function Get-PermissionList {
    param($Value)
    if ($null -eq $Value) { return @() }
    if ($Value -is [string]) { return @($Value) }
    return @($Value)
}

function Test-LfPrincipalHasGrant {
    param([string]$PrincipalArn, [hashtable]$Resource)
    $lf = Invoke-LfListPermissions -Resource $Resource
    foreach ($p in @($lf.PrincipalResourcePermissions)) {
        if ($p.Principal.DataLakePrincipalIdentifier -eq $PrincipalArn) { return $true }
    }
    return $false
}

function Test-LfPrincipalHasPermission {
    param([string]$PrincipalArn, [hashtable]$Resource, [string[]]$Required)
    $lf = Invoke-LfListPermissions -Resource $Resource
    foreach ($p in @($lf.PrincipalResourcePermissions)) {
        if ($p.Principal.DataLakePrincipalIdentifier -eq $PrincipalArn) {
            $perms = Get-PermissionList $p.Permissions
            $matched = @($Required | Where-Object { $perms -contains $_ })
            return $matched.Count -eq $Required.Count
        }
    }
    return $false
}

function Test-LfPrincipalLacksPermission {
    param([string]$PrincipalArn, [hashtable]$Resource, [string[]]$Denied)
    $lf = Invoke-LfListPermissions -Resource $Resource
    foreach ($p in @($lf.PrincipalResourcePermissions)) {
        if ($p.Principal.DataLakePrincipalIdentifier -eq $PrincipalArn) {
            $perms = Get-PermissionList $p.Permissions
            foreach ($d in $Denied) { if ($perms -contains $d) { return $false } }
            return $true
        }
    }
    return $true
}

Write-Host "`n=== DM-005 AWS Governance Tests ===" -ForegroundColor Cyan

$env:AWS_DEFAULT_REGION = Get-TerraformOutput "aws_region"
$bucket = Get-TerraformOutput "bucket_name"
$db = Get-TerraformOutput "glue_database_name"
$adminArn = Get-TerraformOutput "clientes_admin_role_arn"
$marketingArn = Get-TerraformOutput "marketing_consumer_role_arn"
$analyticsArn = Get-TerraformOutput "analytics_consumer_role_arn"
$datascienceArn = Get-TerraformOutput "datascience_consumer_role_arn"
$legacyConsumerArn = Get-TerraformOutput "iam_data_product_consumer_role_arn"
$product1 = Get-TerraformOutput "clientes_por_estado_v1_table_name"
$product2 = Get-TerraformOutput "clientes_ativos_v1_table_name"
$wg = Get-TerraformOutput "athena_workgroup_name"
$govUri = Get-TerraformOutput "governance_policy_s3_uri"

$tableRes1 = @{ Table = @{ DatabaseName = $db; Name = $product1 } }
$tableRes2 = @{ Table = @{ DatabaseName = $db; Name = $product2 } }
$dbRes = @{ Database = @{ Name = $db } }

# 1 Lake Formation configurado
try {
    Invoke-AwsJson @("lakeformation", "describe-resource", "--resource-arn", "arn:aws:s3:::$bucket") | Out-Null
    Write-TestResult "1. Lake Formation configurado (bucket registrado)" $true
} catch { Write-TestResult "1. Lake Formation configurado" $false -Detail $_.Exception.Message }

# 2 Administradores registrados
try {
    $ok = Test-LfPrincipalHasPermission -PrincipalArn $adminArn -Resource $dbRes -Required @("ALL")
    Write-TestResult "2. Administrador registrado no Lake Formation" $ok
} catch { Write-TestResult "2. Administrador registrado" $false -Detail $_.Exception.Message }

# 3 Admin acesso total nos produtos
try {
    $ok = (Test-LfPrincipalHasPermission -PrincipalArn $adminArn -Resource $tableRes1 -Required @("ALL")) -and
          (Test-LfPrincipalHasPermission -PrincipalArn $adminArn -Resource $tableRes2 -Required @("ALL"))
    Write-TestResult "3. clientes_admin possui ALL nos Data Products" $ok
} catch { Write-TestResult "3. clientes_admin acesso total" $false -Detail $_.Exception.Message }

# 4 marketing somente leitura
try {
    $ok = (Test-LfPrincipalHasGrant -PrincipalArn $marketingArn -Resource $tableRes1) -and
          (Test-LfPrincipalLacksPermission -PrincipalArn $marketingArn -Resource $tableRes1 -Denied @("ALTER", "DROP", "INSERT", "DELETE"))
    Write-TestResult "4. marketing_consumer somente leitura" $ok
} catch { Write-TestResult "4. marketing_consumer leitura" $false -Detail $_.Exception.Message }

# 5 analytics somente leitura
try {
    $ok = (Test-LfPrincipalHasGrant -PrincipalArn $analyticsArn -Resource $tableRes2) -and
          (Test-LfPrincipalLacksPermission -PrincipalArn $analyticsArn -Resource $tableRes2 -Denied @("ALTER", "DROP"))
    Write-TestResult "5. analytics_consumer somente leitura" $ok
} catch { Write-TestResult "5. analytics_consumer leitura" $false -Detail $_.Exception.Message }

# 6 consumidores nao alteram produtos
try {
    $ok = (Test-LfPrincipalLacksPermission -PrincipalArn $marketingArn -Resource $tableRes1 -Denied @("ALTER", "DROP", "INSERT", "DELETE")) -and
          (Test-LfPrincipalLacksPermission -PrincipalArn $analyticsArn -Resource $tableRes1 -Denied @("ALTER", "DROP"))
    Write-TestResult "6. Consumidores nao podem alterar Data Products" $ok
} catch { Write-TestResult "6. Bloqueio de alteracao" $false -Detail $_.Exception.Message }

# 7 Athena consulta (via role deploy - evidencia de catalogo)
if (-not $SkipAthena) {
    try {
        $e = Invoke-AwsJson @("athena", "start-query-execution", "--query-string", "SELECT COUNT(*) FROM $db.$product1", "--work-group", $wg)
        do { Start-Sleep 2; $r = Invoke-AwsJson @("athena", "get-query-execution", "--query-execution-id", $e.QueryExecutionId); $st = $r.QueryExecution.Status.State } while ($st -in @("QUEUED", "RUNNING"))
        Write-TestResult "7. Athena consulta Data Product publicado" ($st -eq "SUCCEEDED")
    } catch { Write-TestResult "7. Athena consulta" $false -Detail $_.Exception.Message }
}

# 8 Glue Catalog + LF permissoes marketing em ambos produtos autorizados
try {
    $t1 = Invoke-AwsJson @("glue", "get-table", "--database-name", $db, "--name", $product1)
    $ok = ($t1.Table.Name -eq $product1) -and
          (Test-LfPrincipalHasGrant -PrincipalArn $marketingArn -Resource $tableRes1) -and
          (Test-LfPrincipalHasGrant -PrincipalArn $marketingArn -Resource $tableRes2)
    Write-TestResult "8. Glue Catalog e LF coerentes para marketing" $ok
} catch { Write-TestResult "8. Glue Catalog / LF" $false -Detail $_.Exception.Message }

# 9 datascience sem acesso a clientes_ativos_v1
try {
    $lf = Invoke-LfListPermissions -Resource $tableRes2
    $has = $false
    foreach ($p in @($lf.PrincipalResourcePermissions)) {
        if ($p.Principal.DataLakePrincipalIdentifier -eq $datascienceArn) { $has = $true }
    }
    Write-TestResult "9. Acesso nao autorizado bloqueado (datascience sem clientes_ativos_v1)" (-not $has)
} catch { Write-TestResult "9. Bloqueio acesso nao autorizado" $false -Detail $_.Exception.Message }

# 10 permissoes via Terraform (catalogo de politicas)
try {
    $key = $govUri -replace "^s3://$bucket/", ""
    $obj = Invoke-AwsJson @("s3api", "head-object", "--bucket", $bucket, "--key", $key)
    Write-TestResult "10. Politicas federadas publicadas (Terraform)" ($null -ne $obj)
} catch { Write-TestResult "10. Politicas Terraform" $false -Detail $_.Exception.Message }

# 11 legacy consumer sem grants LF nos produtos
try {
    $lf = Invoke-LfListPermissions -Resource $tableRes1
    $legacy = $false
    foreach ($p in @($lf.PrincipalResourcePermissions)) {
        if ($p.Principal.DataLakePrincipalIdentifier -eq $legacyConsumerArn) { $legacy = $true }
    }
    Write-TestResult "11. Consumidor legado sem acesso federado indevido" (-not $legacy)
} catch { Write-TestResult "11. Isolamento consumidor legado" $false -Detail $_.Exception.Message }

# 12 ownership - apenas admin tem ALL
try {
    $ok = (Test-LfPrincipalHasPermission -PrincipalArn $adminArn -Resource $tableRes2 -Required @("ALL")) -and
          (Test-LfPrincipalLacksPermission -PrincipalArn $marketingArn -Resource $tableRes2 -Denied @("ALL", "DROP"))
    Write-TestResult "12. Ownership do dominio Clientes respeitado" $ok
} catch { Write-TestResult "12. Ownership" $false -Detail $_.Exception.Message }

Write-Host "`n=== Resumo DM-005 === Passed: $script:Passed | Failed: $script:Failed"
if ($script:Failed -gt 0) { exit 1 }
