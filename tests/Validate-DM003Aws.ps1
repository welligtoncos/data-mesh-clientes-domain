#Requires -Version 5.1
<#
.SYNOPSIS
    Validacao automatizada DM-003 - Data Product clientes_por_estado_v1.
#>
param(
    [string]$TerraformDir = (Join-Path $PSScriptRoot "..\terraform\environments\dev"),
    [switch]$RunPublish,
    [switch]$SkipAthena
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ExpectedColumns = @("customer_state", "total_clientes", "data_referencia")
$RequiredTags = @("project", "domain", "managed_by", "environment")

$script:Passed = 0
$script:Failed = 0

function Write-TestResult {
    param([string]$Name, [bool]$Success, [string]$Detail = "")
    if ($Success) { $script:Passed++; Write-Host "[PASS] $Name" -ForegroundColor Green }
    else { $script:Failed++; $msg = "[FAIL] $Name"; if ($Detail) { $msg += " - $Detail" }; Write-Host $msg -ForegroundColor Red }
}

function Invoke-AwsJson {
    param([string[]]$Arguments)
    $output = & aws @Arguments --output json 2>&1
    if ($LASTEXITCODE -ne 0) { throw ($output | Out-String).Trim() }
    if ([string]::IsNullOrWhiteSpace($output)) { return $null }
    return $output | ConvertFrom-Json
}

function Get-TerraformOutput {
    param([string]$Name)
    Push-Location $TerraformDir
    try {
        $value = terraform output -raw $Name 2>&1
        if ($LASTEXITCODE -ne 0) { throw ($value | Out-String).Trim() }
        return $value.Trim()
    }
    finally { Pop-Location }
}

function Wait-GlueJob {
    param([string]$JobName, [string]$RunId)
    do {
        Start-Sleep -Seconds 15
        $status = Invoke-AwsJson -Arguments @("glue", "get-job-run", "--job-name", $JobName, "--run-id", $RunId)
        $state = $status.JobRun.JobRunState
        Write-Host "  Job state: $state"
    } while ($state -in @("RUNNING", "STARTING", "STOPPING"))
    return $state
}

function Invoke-AwsLakeFormationListPermissions {
    param([hashtable]$Resource)
    $tempFile = [System.IO.Path]::ChangeExtension([System.IO.Path]::GetTempFileName(), ".json")
    try {
        $json = $Resource | ConvertTo-Json -Compress -Depth 5
        [System.IO.File]::WriteAllText($tempFile, $json, [System.Text.UTF8Encoding]::new($false))
        $fileUri = "file://$($tempFile -replace '\\', '/')"
        return Invoke-AwsJson -Arguments @("lakeformation", "list-permissions", "--resource", $fileUri)
    }
    finally { Remove-Item $tempFile -Force -ErrorAction SilentlyContinue }
}

Write-Host "`n=== DM-003 AWS Integration Tests ===" -ForegroundColor Cyan

$bucketName      = Get-TerraformOutput "bucket_name"
$glueDatabase    = Get-TerraformOutput "glue_database_name"
$productTable    = Get-TerraformOutput "clientes_por_estado_v1_table_name"
$productS3Uri    = Get-TerraformOutput "clientes_por_estado_v1_s3_uri"
$metadataS3Uri   = Get-TerraformOutput "clientes_por_estado_v1_metadata_s3_uri"
$publishJobName  = Get-TerraformOutput "clientes_por_estado_v1_glue_job_name"
$athenaWorkgroup = Get-TerraformOutput "athena_workgroup_name"
$consumerRoleArn = Get-TerraformOutput "marketing_consumer_role_arn"
$scheduleCron    = Get-TerraformOutput "clientes_por_estado_v1_schedule_cron"
$awsRegion       = Get-TerraformOutput "aws_region"
$accountId       = Get-TerraformOutput "account_id"

$env:AWS_DEFAULT_REGION = $awsRegion
$productPrefix = $productS3Uri -replace "^s3://$bucketName/", ""

# 1. Data Product criado (prefixo S3)
try {
    $objects = Invoke-AwsJson -Arguments @("s3api", "list-objects-v2", "--bucket", $bucketName, "--prefix", $productPrefix, "--max-items", "5")
    $hasObjects = $null -ne $objects.Contents -and @($objects.Contents).Count -gt 0
    Write-TestResult -Name "1. Data Product criado no S3" -Success $hasObjects
}
catch {
    Write-TestResult -Name "1. Data Product criado no S3" -Success $false -Detail $_.Exception.Message
}

# Publicar se necessario (tabela vazia ou sem dados Parquet)
$productReady = $false
try {
    $objects = Invoke-AwsJson -Arguments @("s3api", "list-objects-v2", "--bucket", $bucketName, "--prefix", $productPrefix, "--max-items", "10")
    $hasParquet = @($objects.Contents | Where-Object { $_.Key -like "*.parquet" -or $_.Key -match "customer_state=" }).Count -gt 0
    $productReady = $hasParquet
}
catch { $productReady = $false }

if (-not $productReady -and $RunPublish) {
    Write-Host "Executando publicacao do Data Product..." -ForegroundColor Yellow
    $run = Invoke-AwsJson -Arguments @("glue", "start-job-run", "--job-name", $publishJobName)
    $state = Wait-GlueJob -JobName $publishJobName -RunId $run.JobRunId
    $productReady = ($state -eq "SUCCEEDED")
}

# 2. Tabela Athena/Glue existe
try {
    $table = Invoke-AwsJson -Arguments @("glue", "get-table", "--database-name", $glueDatabase, "--name", $productTable)
    Write-TestResult -Name "2. Tabela Athena/Glue existe" -Success ($table.Table.Name -eq $productTable)
}
catch {
    Write-TestResult -Name "2. Tabela Athena/Glue existe" -Success $false -Detail $_.Exception.Message
    $table = $null
}

# 3. Glue Catalog registrou o produto
if ($null -ne $table) {
    $isDataProduct = $table.Table.Parameters.data_product -eq $productTable
    Write-TestResult -Name "3. Glue Catalog registrou o produto" -Success $isDataProduct
}
else {
    Write-TestResult -Name "3. Glue Catalog registrou o produto" -Success $false
}

# 4-7 via Athena
if (-not $SkipAthena -and $null -ne $table) {
    try {
        $statesQuery = "SELECT COUNT(DISTINCT customer_state) AS states FROM $glueDatabase.$productTable"
        $dupQuery = "SELECT COUNT(*) AS dup FROM (SELECT customer_state, COUNT(*) c FROM $glueDatabase.$productTable GROUP BY customer_state HAVING COUNT(*) > 1)"
        $sumQuery = "SELECT SUM(total_clientes) AS product_total FROM $glueDatabase.$productTable"
        $sourceQuery = "SELECT COUNT(*) AS source_total FROM $glueDatabase.customer"

        function Invoke-AthenaQuery {
            param([string]$Query)
            $execution = Invoke-AwsJson -Arguments @("athena", "start-query-execution", "--query-string", $Query, "--work-group", $athenaWorkgroup)
            $queryId = $execution.QueryExecutionId
            do {
                Start-Sleep -Seconds 2
                $result = Invoke-AwsJson -Arguments @("athena", "get-query-execution", "--query-execution-id", $queryId)
                $state = $result.QueryExecution.Status.State
            } while ($state -in @("QUEUED", "RUNNING"))
            if ($state -ne "SUCCEEDED") { throw "Athena failed: $state" }
            $rows = Invoke-AwsJson -Arguments @("athena", "get-query-results", "--query-execution-id", $queryId)
            return [int]$rows.ResultSet.Rows[1].Data[0].VarCharValue
        }

        $stateCount = Invoke-AthenaQuery -Query $statesQuery
        $dupCount = Invoke-AthenaQuery -Query $dupQuery
        $productTotal = Invoke-AthenaQuery -Query $sumQuery
        $sourceTotal = Invoke-AthenaQuery -Query $sourceQuery

        Write-TestResult -Name "4. Estados agregados corretamente" -Success ($stateCount -gt 0) -Detail "Estados: $stateCount"
        Write-TestResult -Name "5. Sem registros duplicados por estado" -Success ($dupCount -eq 0)
        Write-TestResult -Name "6. Soma total_clientes igual a origem" -Success ($productTotal -eq $sourceTotal) -Detail "Produto: $productTotal, Origem: $sourceTotal"

        $format = $table.Table.StorageDescriptor.InputFormat
        $isParquet = $format -like "*parquet*" -or $table.Table.Parameters.classification -eq "parquet"
        Write-TestResult -Name "7. Formato armazenado e Parquet" -Success $isParquet

        $preview = Invoke-AthenaQuery -Query "SELECT COUNT(*) FROM $glueDatabase.$productTable"
        Write-TestResult -Name "9. Athena consulta o Data Product" -Success ($preview -gt 0)
    }
    catch {
        Write-TestResult -Name "4-9. Validacoes Athena" -Success $false -Detail $_.Exception.Message
    }
}
else {
    Write-Host "[SKIP] Testes Athena detalhados" -ForegroundColor Yellow
}

# 4 schema columns
if ($null -ne $table) {
    $columnNames = @($table.Table.StorageDescriptor.Columns | ForEach-Object { $_.Name })
    $missing = @($ExpectedColumns | Where-Object { $_ -notin $columnNames })
    Write-TestResult -Name "4b. Schema com 3 campos do contrato" -Success ($missing.Count -eq 0)
}

# 8. Visivel no catalogo (metadata S3 fora do path Parquet)
try {
    $metadataKey = $metadataS3Uri -replace "^s3://$bucketName/", ""
    Invoke-AwsJson -Arguments @("s3api", "head-object", "--bucket", $bucketName, "--key", $metadataKey) | Out-Null
    Write-TestResult -Name "8. Produto visivel no catalogo (metadata)" -Success $true
}
catch {
    Write-TestResult -Name "8. Produto visivel no catalogo (metadata)" -Success $false -Detail $_.Exception.Message
}

# 10. Apenas consumidor autorizado (LF)
try {
    $lfPerms = Invoke-AwsLakeFormationListPermissions -Resource @{ Table = @{ DatabaseName = $glueDatabase; Name = $productTable } }
    $consumerArn = $consumerRoleArn
    $hasConsumer = $false
    foreach ($perm in @($lfPerms.PrincipalResourcePermissions)) {
        if ($perm.Principal.DataLakePrincipalIdentifier -eq $consumerArn) { $hasConsumer = $true }
    }
    Write-TestResult -Name "10. Consumidor autorizado possui permissao LF" -Success $hasConsumer
}
catch {
    Write-TestResult -Name "10. Consumidor autorizado possui permissao LF" -Success $false -Detail $_.Exception.Message
}

# 10b SLA schedule
$slaOk = $scheduleCron -eq "cron(0 6 * * ? *)"
Write-TestResult -Name "10b. SLA configurado para 06:00 UTC" -Success $slaOk -Detail $scheduleCron

# 5 Glue Job success
try {
    $runs = Invoke-AwsJson -Arguments @("glue", "get-job-runs", "--job-name", $publishJobName, "--max-results", "3")
    $ok = @($runs.JobRuns | Where-Object { $_.JobRunState -eq "SUCCEEDED" }).Count -gt 0
    Write-TestResult -Name "5b. Glue Job de publicacao executado" -Success $ok
}
catch {
    Write-TestResult -Name "5b. Glue Job de publicacao executado" -Success $false -Detail $_.Exception.Message
}

# Tags
try {
    $tags = Invoke-AwsJson -Arguments @("s3api", "get-bucket-tagging", "--bucket", $bucketName)
    $tagMap = @{}; foreach ($t in $tags.TagSet) { $tagMap[$t.Key] = $t.Value }
    $missingTags = @($RequiredTags | Where-Object { -not $tagMap.ContainsKey($_) })
    Write-TestResult -Name "Tags obrigatorias no bucket" -Success ($missingTags.Count -eq 0)
}
catch {
    Write-TestResult -Name "Tags obrigatorias no bucket" -Success $false -Detail $_.Exception.Message
}

Write-Host "`n=== Resumo DM-003 ===" -ForegroundColor Cyan
Write-Host "Passed: $script:Passed | Failed: $script:Failed"
if ($script:Failed -gt 0) { exit 1 }
exit 0
