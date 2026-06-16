#Requires -Version 5.1
<#
.SYNOPSIS
    Validacao automatizada DM-002 - ingestao customer (S3, Glue, Athena).

.PARAMETER RunIngestion
    Executa Glue Job e Crawler se a tabela ainda nao existir.

.PARAMETER SkipAthena
    Pula teste de consulta Athena.
#>
param(
    [string]$TerraformDir = (Join-Path $PSScriptRoot "..\terraform\environments\dev"),
    [switch]$RunIngestion,
    [switch]$SkipAthena
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ExpectedColumns = @(
    "customer_id",
    "customer_unique_id",
    "customer_zip_code_prefix",
    "customer_city",
    "customer_state"
)

$RequiredTags = @("project", "domain", "managed_by", "environment")

$script:Passed = 0
$script:Failed = 0

function Write-TestResult {
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

function Wait-GlueCrawler {
    param([string]$CrawlerName)
    do {
        Start-Sleep -Seconds 10
        $status = Invoke-AwsJson -Arguments @("glue", "get-crawler", "--name", $CrawlerName)
        $state = $status.Crawler.State
        Write-Host "  Crawler state: $state"
    } while ($state -eq "RUNNING")
    return $state
}

function Get-CsvRowCount {
    param([string]$Path)
    $lines = Get-Content $Path
    return ($lines | Measure-Object -Line).Lines - 1
}

Write-Host "`n=== DM-002 AWS Integration Tests ===" -ForegroundColor Cyan

# Carregar outputs
$bucketName       = Get-TerraformOutput "bucket_name"
$glueDatabase     = Get-TerraformOutput "glue_database_name"
$customerTable    = Get-TerraformOutput "customer_table_name"
$sourceUri        = Get-TerraformOutput "customer_source_s3_uri"
$targetUri        = Get-TerraformOutput "customer_target_s3_uri"
$glueJobName      = Get-TerraformOutput "customer_glue_job_name"
$crawlerName      = Get-TerraformOutput "customer_glue_crawler_name"
$athenaWorkgroup  = Get-TerraformOutput "athena_workgroup_name"
$awsRegion        = Get-TerraformOutput "aws_region"
$csvLocalPath     = Get-TerraformOutput "customers_csv_local_path"
$csvFullPath      = (Resolve-Path (Join-Path $TerraformDir $csvLocalPath)).Path

$env:AWS_DEFAULT_REGION = $awsRegion
$sourceKey = $sourceUri -replace "^s3://$bucketName/", ""
$targetPrefix = $targetUri -replace "^s3://$bucketName/", ""

# 1. Bucket criado
try {
    Invoke-AwsJson -Arguments @("s3api", "head-bucket", "--bucket", $bucketName) | Out-Null
    Write-TestResult -Name "1. Bucket do dominio criado" -Success $true
}
catch {
    Write-TestResult -Name "1. Bucket do dominio criado" -Success $false -Detail $_.Exception.Message
}

# 2. customers.csv carregado
try {
    $obj = Invoke-AwsJson -Arguments @("s3api", "head-object", "--bucket", $bucketName, "--key", $sourceKey)
    Write-TestResult -Name "2. Arquivo customers.csv armazenado no S3" -Success ($obj.ContentLength -gt 0)
}
catch {
    Write-TestResult -Name "2. Arquivo customers.csv armazenado no S3" -Success $false -Detail $_.Exception.Message
}

# Executar ingestao se necessario
$tableExists = $false
try {
    Invoke-AwsJson -Arguments @("glue", "get-table", "--database-name", $glueDatabase, "--name", $customerTable) | Out-Null
    $tableExists = $true
}
catch { $tableExists = $false }

if (-not $tableExists -and $RunIngestion) {
    Write-Host "Executando ingestao (Glue Job + Crawler)..." -ForegroundColor Yellow
    $run = Invoke-AwsJson -Arguments @("glue", "start-job-run", "--job-name", $glueJobName)
    $jobState = Wait-GlueJob -JobName $glueJobName -RunId $run.JobRunId
    if ($jobState -ne "SUCCEEDED") {
        Write-TestResult -Name "5. Glue Job executado com sucesso" -Success $false -Detail "Estado: $jobState"
    }
    Invoke-AwsJson -Arguments @("glue", "start-crawler", "--name", $crawlerName) | Out-Null
    $crawlerState = Wait-GlueCrawler -CrawlerName $crawlerName
    if ($crawlerState -ne "READY") {
        Write-Host "Crawler terminou com estado: $crawlerState" -ForegroundColor Yellow
    }
    $tableExists = $true
}

# 3. Tabela catalogada
try {
    $table = Invoke-AwsJson -Arguments @("glue", "get-table", "--database-name", $glueDatabase, "--name", $customerTable)
    Write-TestResult -Name "3. Tabela customer catalogada no Glue" -Success ($table.Table.Name -eq $customerTable)
}
catch {
    Write-TestResult -Name "3. Tabela customer catalogada no Glue" -Success $false -Detail $_.Exception.Message
    $table = $null
}

# 4. Cinco campos esperados
if ($null -ne $table) {
    $columnNames = @($table.Table.StorageDescriptor.Columns | ForEach-Object { $_.Name })
    $allColumns = $columnNames + @($table.Table.PartitionKeys | ForEach-Object { $_.Name })
    $missing = @($ExpectedColumns | Where-Object { $_ -notin $allColumns })
    Write-TestResult -Name "4. Glue Catalog possui os 5 campos esperados" -Success ($missing.Count -eq 0) `
        -Detail $(if ($missing.Count -gt 0) { "Faltando: $($missing -join ', ')" } else { "" })
}
else {
    Write-TestResult -Name "4. Glue Catalog possui os 5 campos esperados" -Success $false -Detail "Tabela nao encontrada"
}

# 5. Glue Job executado com sucesso
try {
    $runs = Invoke-AwsJson -Arguments @("glue", "get-job-runs", "--job-name", $glueJobName, "--max-results", "5")
    $succeeded = @($runs.JobRuns | Where-Object { $_.JobRunState -eq "SUCCEEDED" })
    Write-TestResult -Name "5. Glue Job executado com sucesso" -Success ($succeeded.Count -gt 0)
}
catch {
    Write-TestResult -Name "5. Glue Job executado com sucesso" -Success $false -Detail $_.Exception.Message
}

# 6. Contagem de registros
if ($null -ne $table -and (Test-Path $csvFullPath)) {
    try {
        $expectedCount = Get-CsvRowCount -Path $csvFullPath
        $partitions = Invoke-AwsJson -Arguments @(
            "glue", "get-partitions",
            "--database-name", $glueDatabase,
            "--table-name", $customerTable,
            "--max-results", "1000"
        )
        $partitionCount = @($partitions.Partitions).Count
        Write-TestResult -Name "8. Particionamento por customer_state criado" -Success ($partitionCount -gt 0) `
            -Detail "Particoes: $partitionCount"

        if (-not $SkipAthena) {
            $query = "SELECT COUNT(*) AS total FROM $glueDatabase.$customerTable"
            $execution = Invoke-AwsJson -Arguments @(
                "athena", "start-query-execution",
                "--query-string", $query,
                "--work-group", $athenaWorkgroup
            )
            $queryId = $execution.QueryExecutionId
            do {
                Start-Sleep -Seconds 2
                $result = Invoke-AwsJson -Arguments @("athena", "get-query-execution", "--query-execution-id", $queryId)
                $state = $result.QueryExecution.Status.State
            } while ($state -in @("QUEUED", "RUNNING"))

            if ($state -eq "SUCCEEDED") {
                $rows = Invoke-AwsJson -Arguments @("athena", "get-query-results", "--query-execution-id", $queryId)
                $actualCount = [int]$rows.ResultSet.Rows[1].Data[0].VarCharValue
                Write-TestResult -Name "6. Registros na tabela igual ao CSV" -Success ($actualCount -eq $expectedCount) `
                    -Detail "Esperado: $expectedCount, Atual: $actualCount"
            }
            else {
                Write-TestResult -Name "6. Registros na tabela igual ao CSV" -Success $false -Detail "Athena falhou: $state"
            }
        }
        else {
            Write-Host "[SKIP] Teste 6 via Athena (SkipAthena)" -ForegroundColor Yellow
        }
    }
    catch {
        Write-TestResult -Name "6. Registros na tabela igual ao CSV" -Success $false -Detail $_.Exception.Message
        Write-TestResult -Name "8. Particionamento por customer_state criado" -Success $false -Detail $_.Exception.Message
    }
}
else {
    Write-TestResult -Name "6. Registros na tabela igual ao CSV" -Success $false -Detail "Tabela ou CSV local indisponivel"
    Write-TestResult -Name "8. Particionamento por customer_state criado" -Success $false -Detail "Tabela indisponivel"
}

# 7. Formato Parquet
if ($null -ne $table) {
    $format = $table.Table.StorageDescriptor.InputFormat
    $isParquet = $format -like "*parquet*" -or $table.Table.Parameters.'classification' -eq 'parquet'
    Write-TestResult -Name "7. Formato final e Parquet" -Success $isParquet -Detail "InputFormat: $format"
}
else {
    Write-TestResult -Name "7. Formato final e Parquet" -Success $false -Detail "Tabela nao encontrada"
}

# 9. Athena consulta
if (-not $SkipAthena) {
    try {
        $query = "SELECT customer_id, customer_state FROM $glueDatabase.$customerTable LIMIT 5"
        $execution = Invoke-AwsJson -Arguments @(
            "athena", "start-query-execution",
            "--query-string", $query,
            "--work-group", $athenaWorkgroup
        )
        $queryId = $execution.QueryExecutionId
        do {
            Start-Sleep -Seconds 2
            $result = Invoke-AwsJson -Arguments @("athena", "get-query-execution", "--query-execution-id", $queryId)
            $state = $result.QueryExecution.Status.State
        } while ($state -in @("QUEUED", "RUNNING"))
        Write-TestResult -Name "9. Athena consegue consultar os dados" -Success ($state -eq "SUCCEEDED") -Detail "Estado: $state"
    }
    catch {
        Write-TestResult -Name "9. Athena consegue consultar os dados" -Success $false -Detail $_.Exception.Message
    }
}
else {
    Write-Host "[SKIP] Teste 9 Athena (SkipAthena)" -ForegroundColor Yellow
}

# 10. Tags obrigatorias
try {
    $bucketTags = Invoke-AwsJson -Arguments @("s3api", "get-bucket-tagging", "--bucket", $bucketName)
    $tagMap = @{}
    foreach ($tag in $bucketTags.TagSet) { $tagMap[$tag.Key] = $tag.Value }
    $missingTags = @($RequiredTags | Where-Object { -not $tagMap.ContainsKey($_) })
    Write-TestResult -Name "10. Tags obrigatorias aplicadas" -Success ($missingTags.Count -eq 0) `
        -Detail $(if ($missingTags.Count -gt 0) { "Faltando: $($missingTags -join ', ')" } else { "" })
}
catch {
    Write-TestResult -Name "10. Tags obrigatorias aplicadas" -Success $false -Detail $_.Exception.Message
}

# Crawler executado (bonus check for criterion 3)
try {
    $crawler = Invoke-AwsJson -Arguments @("glue", "get-crawler", "--name", $crawlerName)
    $lastCrawl = $crawler.Crawler.LastCrawl.Status
    $crawlerRan = $lastCrawl -eq "SUCCEEDED" -or $null -ne $crawler.Crawler.LastCrawl.Time
    Write-TestResult -Name "3b. Glue Crawler executado ao menos uma vez" -Success $crawlerRan -Detail "LastCrawl: $lastCrawl"
}
catch {
    Write-TestResult -Name "3b. Glue Crawler executado ao menos uma vez" -Success $false -Detail $_.Exception.Message
}

Write-Host "`n=== Resumo DM-002 ===" -ForegroundColor Cyan
Write-Host "Passed: $script:Passed" -ForegroundColor Green
Write-Host "Failed: $script:Failed" -ForegroundColor $(if ($script:Failed -gt 0) { "Red" } else { "Green" })

if ($script:Failed -gt 0) { exit 1 }
exit 0
