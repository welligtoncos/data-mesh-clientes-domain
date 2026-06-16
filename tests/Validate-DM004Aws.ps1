#Requires -Version 5.1
param(
    [string]$TerraformDir = (Join-Path $PSScriptRoot "..\terraform\environments\dev"),
    [switch]$RunPublish,
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

function Wait-GlueJob { param([string]$JobName, [string]$RunId)
    do { Start-Sleep 15; $s = Invoke-AwsJson @("glue","get-job-run","--job-name",$JobName,"--run-id",$RunId); Write-Host "  $JobName : $($s.JobRun.JobRunState)" } while ($s.JobRun.JobRunState -in @("RUNNING","STARTING","STOPPING"))
    return $s.JobRun.JobRunState
}

function Invoke-AthenaScalar { param([string]$Query, [string]$Workgroup)
    $e = Invoke-AwsJson @("athena","start-query-execution","--query-string",$Query,"--work-group",$Workgroup)
    do { Start-Sleep 2; $r = Invoke-AwsJson @("athena","get-query-execution","--query-execution-id",$e.QueryExecutionId); $st = $r.QueryExecution.Status.State } while ($st -in @("QUEUED","RUNNING"))
    if ($st -ne "SUCCEEDED") { throw "Athena failed: $st" }
    $rows = Invoke-AwsJson @("athena","get-query-results","--query-execution-id",$e.QueryExecutionId)
    return $rows.ResultSet.Rows[1].Data[0].VarCharValue
}

Write-Host "`n=== DM-004 AWS Integration Tests ===" -ForegroundColor Cyan

$bucket = Get-TerraformOutput "bucket_name"
$clientesDb = Get-TerraformOutput "glue_database_name"
$pedidosDb = Get-TerraformOutput "pedidos_glue_database_name"
$product = Get-TerraformOutput "clientes_ativos_v1_table_name"
$productUri = Get-TerraformOutput "clientes_ativos_v1_s3_uri"
$metadataUri = Get-TerraformOutput "clientes_ativos_v1_metadata_s3_uri"
$publishJob = Get-TerraformOutput "clientes_ativos_v1_glue_job_name"
$ordersJob = Get-TerraformOutput "orders_glue_job_name"
$wg = Get-TerraformOutput "athena_workgroup_name"
$dias = [int](Get-TerraformOutput "clientes_ativos_v1_dias_atividade")
$consumerArn = Get-TerraformOutput "marketing_consumer_role_arn"
$env:AWS_DEFAULT_REGION = Get-TerraformOutput "aws_region"
$productPrefix = $productUri -replace "^s3://$bucket/", ""

# Pipeline se necessario
$hasData = $false
try {
    $objs = Invoke-AwsJson @("s3api","list-objects-v2","--bucket",$bucket,"--prefix",$productPrefix,"--max-items","5")
    $hasData = @($objs.Contents | Where-Object { $_.Key -match "customer_state=" }).Count -gt 0
} catch { $hasData = $false }

if (-not $hasData -and $RunPublish) {
    Write-Host "Executando pipeline (orders + publish)..." -ForegroundColor Yellow
    foreach ($job in @($ordersJob, $publishJob)) {
        $run = Invoke-AwsJson @("glue","start-job-run","--job-name",$job)
        $state = Wait-GlueJob -JobName $job -RunId $run.JobRunId
        if ($state -ne "SUCCEEDED") { throw "Job $job failed: $state" }
    }
    $hasData = $true
}

# 1
Write-TestResult "1. Data Product criado no S3" ($hasData)

# 2
try {
    $runs = Invoke-AwsJson @("glue","get-job-runs","--job-name",$publishJob,"--max-results","3")
    Write-TestResult "2. Glue Job executou sem erros" (@($runs.JobRuns | Where-Object { $_.JobRunState -eq "SUCCEEDED" }).Count -gt 0)
} catch { Write-TestResult "2. Glue Job executou sem erros" $false -Detail $_.Exception.Message }

# 3-12 via Athena/Glue
try {
    $table = Invoke-AwsJson @("glue","get-table","--database-name",$clientesDb,"--name",$product)
    Write-TestResult "7. Registrado no Glue Catalog" ($table.Table.Parameters.data_product -eq $product)

    $fmt = $table.Table.StorageDescriptor.InputFormat
    Write-TestResult "9. Formato Parquet" ($fmt -like "*parquet*")

    $partitions = Invoke-AwsJson @("glue","get-partitions","--database-name",$clientesDb,"--table-name",$product,"--max-results","50")
    Write-TestResult "10. Particionamento customer_state" (@($partitions.Partitions).Count -gt 0) -Detail "Particoes: $(@($partitions.Partitions).Count)"

    if (-not $SkipAthena -and $hasData) {
        $over = Invoke-AthenaScalar "SELECT COUNT(*) FROM $clientesDb.$product WHERE dias_desde_ultima_compra > $dias" $wg
        Write-TestResult "3. Apenas clientes dentro de $dias dias" ([int]$over -eq 0)

        $allActive = Invoke-AthenaScalar "SELECT COUNT(*) FROM $clientesDb.$product WHERE ativo = false" $wg
        Write-TestResult "3b. Todos marcados como ativos" ([int]$allActive -eq 0)

        $orphan = Invoke-AthenaScalar @"
SELECT COUNT(*) FROM $clientesDb.$product p
LEFT JOIN $clientesDb.customer c ON p.customer_id = c.customer_id
WHERE c.customer_id IS NULL
"@ $wg
        Write-TestResult "4. Clientes sem pedidos nao aparecem (join valido)" ([int]$orphan -eq 0)

        $mismatch = Invoke-AthenaScalar @"
SELECT COUNT(*) FROM (
  SELECT p.customer_id
  FROM $clientesDb.$product p
  JOIN (
    SELECT customer_id, MAX(order_purchase_timestamp) AS ultima
    FROM $pedidosDb.orders GROUP BY customer_id
  ) o ON p.customer_id = o.customer_id
  WHERE CAST(p.ultima_compra AS timestamp) <> CAST(o.ultima AS timestamp)
)
"@ $wg
        Write-TestResult "5. Ultima compra calculada corretamente" ([int]$mismatch -eq 0)

        $expected = Invoke-AthenaScalar @"
SELECT COUNT(*) FROM (
  SELECT c.customer_id
  FROM $clientesDb.customer c
  JOIN (
    SELECT customer_id, MAX(order_purchase_timestamp) AS ultima
    FROM $pedidosDb.orders GROUP BY customer_id
  ) o ON c.customer_id = o.customer_id
  WHERE DATE_DIFF('day', CAST(o.ultima AS date), CURRENT_DATE) <= $dias
)
"@ $wg
        $actual = Invoke-AthenaScalar "SELECT COUNT(*) FROM $clientesDb.$product" $wg
        Write-TestResult "6. Total consistente com regra de negocio" ([int]$actual -eq [int]$expected) -Detail "Esperado: $expected, Atual: $actual"

        Invoke-AthenaScalar "SELECT COUNT(*) FROM $clientesDb.$product LIMIT 1" $wg | Out-Null
        Write-TestResult "8. Athena consulta os dados" $true
    }
} catch {
    Write-TestResult "Validacoes Glue/Athena" $false -Detail $_.Exception.Message
}

# 11 metadata
try {
    $metaKey = $metadataUri -replace "^s3://$bucket/", ""
    Invoke-AwsJson @("s3api","head-object","--bucket",$bucket,"--key",$metaKey) | Out-Null
    Write-TestResult "11. Visivel no catalogo federado (metadata)" $true
} catch { Write-TestResult "11. Visivel no catalogo federado (metadata)" $false }

# 12 LF
try {
    $temp = [System.IO.Path]::ChangeExtension([System.IO.Path]::GetTempFileName(), ".json")
    [System.IO.File]::WriteAllText($temp, (@{ Table = @{ DatabaseName = $clientesDb; Name = $product } } | ConvertTo-Json -Compress), [System.Text.UTF8Encoding]::new($false))
    $uri = "file://$($temp -replace '\\','/')"
    $lf = Invoke-AwsJson @("lakeformation","list-permissions","--resource",$uri)
    $ok = $false
    foreach ($p in @($lf.PrincipalResourcePermissions)) { if ($p.Principal.DataLakePrincipalIdentifier -eq $consumerArn) { $ok = $true } }
    Write-TestResult "12. Permissoes Lake Formation aplicadas" $ok
    Remove-Item $temp -Force
} catch { Write-TestResult "12. Permissoes Lake Formation aplicadas" $false -Detail $_.Exception.Message }

Write-Host "`n=== Resumo DM-004 === Passed: $script:Passed | Failed: $script:Failed"
if ($script:Failed -gt 0) { exit 1 }
