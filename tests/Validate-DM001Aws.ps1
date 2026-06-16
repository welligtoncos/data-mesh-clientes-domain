#Requires -Version 5.1
<#
.SYNOPSIS
    Validação automatizada DM-001 — recursos AWS (S3, Glue, IAM, Lake Formation).

.DESCRIPTION
    Lê os outputs do Terraform e verifica existência, configuração e acesso
    aos recursos provisionados para o domínio Clientes.

.PARAMETER TerraformDir
    Diretório do environment Terraform (default: environments/dev).

.PARAMETER SkipAssumeRole
    Pula testes de assume-role (útil em CI sem permissão sts:AssumeRole).
#>
param(
    [string]$TerraformDir = (Join-Path $PSScriptRoot "..\terraform\environments\dev"),
    [switch]$SkipAssumeRole
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:Passed = 0
$script:Failed = 0
$script:Results = [System.Collections.Generic.List[string]]::new()

function Write-TestResult {
    param(
        [string]$Name,
        [bool]$Success,
        [string]$Detail = ""
    )

    if ($Success) {
        $script:Passed++
        $line = "[PASS] $Name"
    }
    else {
        $script:Failed++
        $line = "[FAIL] $Name"
        if ($Detail) { $line += " - $Detail" }
    }

    $script:Results.Add($line)
    Write-Host $line -ForegroundColor $(if ($Success) { "Green" } else { "Red" })
}

function Invoke-AwsJson {
    param([string[]]$Arguments)

    $output = & aws @Arguments --output json 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw ($output | Out-String).Trim()
    }

    if ([string]::IsNullOrWhiteSpace($output)) {
        return $null
    }

    return $output | ConvertFrom-Json
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
    finally {
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
    }
}

function Get-TerraformOutput {
    param([string]$Name)

    Push-Location $TerraformDir
    try {
        $value = terraform output -raw $Name 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw ($value | Out-String).Trim()
        }
        return $value.Trim()
    }
    finally {
        Pop-Location
    }
}

function Test-CommandExists {
    param([string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

# ---------------------------------------------------------------------------
# Pré-requisitos
# ---------------------------------------------------------------------------
if (-not (Test-CommandExists "terraform")) {
    Write-Error "terraform não encontrado no PATH."
    exit 1
}

if (-not (Test-CommandExists "aws")) {
    Write-Error "aws CLI não encontrado no PATH."
    exit 1
}

if (-not (Test-Path $TerraformDir)) {
    Write-Error "Diretório Terraform não encontrado: $TerraformDir"
    exit 1
}

Write-Host "`n=== DM-001 AWS Integration Tests ===" -ForegroundColor Cyan
Write-Host "Terraform dir: $TerraformDir`n"

# ---------------------------------------------------------------------------
# Carregar outputs
# ---------------------------------------------------------------------------
try {
    $bucketName              = Get-TerraformOutput "bucket_name"
    $bucketArn               = Get-TerraformOutput "bucket_arn"
    $glueDatabaseName        = Get-TerraformOutput "glue_database_name"
    $adminRoleArn            = Get-TerraformOutput "iam_domain_admin_role_arn"
    $adminRoleName           = Get-TerraformOutput "iam_domain_admin_role_name"
    $consumerRoleArn         = Get-TerraformOutput "iam_data_product_consumer_role_arn"
    $consumerRoleName        = Get-TerraformOutput "iam_data_product_consumer_role_name"
    $etlRoleArn              = Get-TerraformOutput "iam_etl_processing_role_arn"
    $etlRoleName             = Get-TerraformOutput "iam_etl_processing_role_name"
    $lfResourceArn           = Get-TerraformOutput "lakeformation_registered_resource_arn"
    $accountId               = Get-TerraformOutput "account_id"
    $awsRegion               = Get-TerraformOutput "aws_region"
}
catch {
    Write-TestResult -Name "Carregar outputs do Terraform" -Success $false -Detail $_.Exception.Message
    exit 1
}

Write-TestResult -Name "Carregar outputs do Terraform" -Success $true

$env:AWS_DEFAULT_REGION = $awsRegion

# ---------------------------------------------------------------------------
# S3 — Bucket
# ---------------------------------------------------------------------------
try {
    Invoke-AwsJson -Arguments @("s3api", "head-bucket", "--bucket", $bucketName) | Out-Null
    Write-TestResult -Name "S3 bucket existe ($bucketName)" -Success $true
}
catch {
    Write-TestResult -Name "S3 bucket existe ($bucketName)" -Success $false -Detail $_.Exception.Message
}

try {
    $objects = Invoke-AwsJson -Arguments @("s3api", "list-objects-v2", "--bucket", $bucketName, "--prefix", "internal/", "--max-items", "5")
    $hasInternal = $null -ne $objects.Contents -and $objects.Contents.Count -gt 0
    Write-TestResult -Name "S3 prefixo internal/ existe" -Success $hasInternal
}
catch {
    Write-TestResult -Name "S3 prefixo internal/ existe" -Success $false -Detail $_.Exception.Message
}

try {
    $objects = Invoke-AwsJson -Arguments @("s3api", "list-objects-v2", "--bucket", $bucketName, "--prefix", "data-products/", "--max-items", "5")
    $hasDataProducts = $null -ne $objects.Contents -and $objects.Contents.Count -gt 0
    Write-TestResult -Name "S3 prefixo data-products/ existe" -Success $hasDataProducts
}
catch {
    Write-TestResult -Name "S3 prefixo data-products/ existe" -Success $false -Detail $_.Exception.Message
}

try {
    $encryption = Invoke-AwsJson -Arguments @("s3api", "get-bucket-encryption", "--bucket", $bucketName)
    $algorithm = $encryption.ServerSideEncryptionConfiguration.Rules[0].ApplyServerSideEncryptionByDefault.SSEAlgorithm
    Write-TestResult -Name "S3 criptografia habilitada (AES256)" -Success ($algorithm -eq "AES256")
}
catch {
    Write-TestResult -Name "S3 criptografia habilitada (AES256)" -Success $false -Detail $_.Exception.Message
}

try {
    $publicBlock = Invoke-AwsJson -Arguments @("s3api", "get-public-access-block", "--bucket", $bucketName)
    $cfg = $publicBlock.PublicAccessBlockConfiguration
    $allBlocked = $cfg.BlockPublicAcls -and $cfg.BlockPublicPolicy -and $cfg.IgnorePublicAcls -and $cfg.RestrictPublicBuckets
    Write-TestResult -Name "S3 block public access habilitado" -Success $allBlocked
}
catch {
    Write-TestResult -Name "S3 block public access habilitado" -Success $false -Detail $_.Exception.Message
}

try {
    $versioning = Invoke-AwsJson -Arguments @("s3api", "get-bucket-versioning", "--bucket", $bucketName)
    Write-TestResult -Name "S3 versionamento habilitado" -Success ($versioning.Status -eq "Enabled")
}
catch {
    Write-TestResult -Name "S3 versionamento habilitado" -Success $false -Detail $_.Exception.Message
}

# ---------------------------------------------------------------------------
# Glue Catalog
# ---------------------------------------------------------------------------
try {
    $database = Invoke-AwsJson -Arguments @("glue", "get-database", "--name", $glueDatabaseName)
    $db = $database.Database
    $nameOk = $db.Name -eq $glueDatabaseName
    $locationOk = $db.LocationUri -like "s3://$bucketName/*"
    Write-TestResult -Name "Glue database existe ($glueDatabaseName)" -Success $nameOk
    Write-TestResult -Name "Glue database aponta para bucket do domínio" -Success $locationOk
}
catch {
    Write-TestResult -Name "Glue database existe ($glueDatabaseName)" -Success $false -Detail $_.Exception.Message
    Write-TestResult -Name "Glue database aponta para bucket do domínio" -Success $false -Detail "database não encontrado"
}

# ---------------------------------------------------------------------------
# IAM — Papéis
# ---------------------------------------------------------------------------
$roleTests = @(
    @{ Name = "IAM role admin"; RoleName = $adminRoleName; Arn = $adminRoleArn },
    @{ Name = "IAM role consumer"; RoleName = $consumerRoleName; Arn = $consumerRoleArn },
    @{ Name = "IAM role etl"; RoleName = $etlRoleName; Arn = $etlRoleArn }
)

foreach ($roleTest in $roleTests) {
    try {
        $role = Invoke-AwsJson -Arguments @("iam", "get-role", "--role-name", $roleTest.RoleName)
        $arnOk = $role.Role.Arn -eq $roleTest.Arn
        Write-TestResult -Name "$($roleTest.Name) existe ($($roleTest.RoleName))" -Success $arnOk
    }
    catch {
        Write-TestResult -Name "$($roleTest.Name) existe ($($roleTest.RoleName))" -Success $false -Detail $_.Exception.Message
    }
}

try {
    $adminPolicies = Invoke-AwsJson -Arguments @("iam", "list-role-policies", "--role-name", $adminRoleName)
    Write-TestResult -Name "IAM admin possui inline policy" -Success ($adminPolicies.PolicyNames.Count -gt 0)
}
catch {
    Write-TestResult -Name "IAM admin possui inline policy" -Success $false -Detail $_.Exception.Message
}

try {
    $etlAttachments = Invoke-AwsJson -Arguments @("iam", "list-attached-role-policies", "--role-name", $etlRoleName)
    $hasGluePolicy = $etlAttachments.AttachedPolicies.PolicyName -contains "AWSGlueServiceRole"
    Write-TestResult -Name "IAM ETL possui AWSGlueServiceRole" -Success $hasGluePolicy
}
catch {
    Write-TestResult -Name "IAM ETL possui AWSGlueServiceRole" -Success $false -Detail $_.Exception.Message
}

# ---------------------------------------------------------------------------
# IAM — Assume Role (funcionalidade)
# ---------------------------------------------------------------------------
if (-not $SkipAssumeRole) {
    try {
        $session = Invoke-AwsJson -Arguments @(
            "sts", "assume-role",
            "--role-arn", $adminRoleArn,
            "--role-session-name", "dm001-validation-$(Get-Date -Format 'yyyyMMddHHmmss')"
        )
        $hasCreds = $null -ne $session.Credentials.AccessKeyId
        Write-TestResult -Name "IAM assume-role admin funciona" -Success $hasCreds

        if ($hasCreds) {
            $testKey = "internal/dm001-validation-$(Get-Date -Format 'yyyyMMddHHmmss').txt"
            $testBody = "dm001-validation-test"
            $tempFile = [System.IO.Path]::GetTempFileName()

            $prevKey = $env:AWS_ACCESS_KEY_ID
            $prevSecret = $env:AWS_SECRET_ACCESS_KEY
            $prevToken = $env:AWS_SESSION_TOKEN

            try {
                Set-Content -Path $tempFile -Value $testBody -NoNewline

                $env:AWS_ACCESS_KEY_ID     = $session.Credentials.AccessKeyId
                $env:AWS_SECRET_ACCESS_KEY = $session.Credentials.SecretAccessKey
                $env:AWS_SESSION_TOKEN     = $session.Credentials.SessionToken

                & aws s3 cp $tempFile "s3://$bucketName/$testKey" 2>&1 | Out-Null
                Write-TestResult -Name "IAM admin escreve em S3 internal/" -Success ($LASTEXITCODE -eq 0)

                if ($LASTEXITCODE -eq 0) {
                    & aws s3api delete-object --bucket $bucketName --key $testKey 2>&1 | Out-Null
                    Write-TestResult -Name "IAM admin remove objeto de teste em S3" -Success ($LASTEXITCODE -eq 0)
                }
            }
            finally {
                Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
                $env:AWS_ACCESS_KEY_ID     = $prevKey
                $env:AWS_SECRET_ACCESS_KEY = $prevSecret
                $env:AWS_SESSION_TOKEN     = $prevToken
            }
        }
    }
    catch {
        Write-TestResult -Name "IAM assume-role admin funciona" -Success $false -Detail $_.Exception.Message
    }
}
else {
    Write-Host "[SKIP] Testes de assume-role (SkipAssumeRole)" -ForegroundColor Yellow
}

# ---------------------------------------------------------------------------
# Lake Formation
# ---------------------------------------------------------------------------
try {
    $lfResources = Invoke-AwsJson -Arguments @("lakeformation", "list-resources")
    $registered = $lfResources.ResourceInfoList.ResourceArn -contains $lfResourceArn
    Write-TestResult -Name "Lake Formation bucket registrado" -Success $registered
}
catch {
    Write-TestResult -Name "Lake Formation bucket registrado" -Success $false -Detail $_.Exception.Message
}

try {
    $lfDbPerms = Invoke-AwsLakeFormationListPermissions -Resource @{ Database = @{ Name = $glueDatabaseName } }
    $adminDbArn = "arn:aws:iam::${accountId}:role/${adminRoleName}"
    $hasDbPerm = $false

    foreach ($perm in @($lfDbPerms.PrincipalResourcePermissions)) {
        if ($perm.Principal.DataLakePrincipalIdentifier -eq $adminDbArn) {
            $hasDbPerm = $true
            break
        }
    }

    Write-TestResult -Name "Lake Formation permissao admin no database" -Success $hasDbPerm
}
catch {
    Write-TestResult -Name "Lake Formation permissao admin no database" -Success $false -Detail $_.Exception.Message
}

try {
    $lfLocPerms = Invoke-AwsLakeFormationListPermissions -Resource @{ DataLocation = @{ ResourceArn = $lfResourceArn } }
    $adminLocArn = "arn:aws:iam::${accountId}:role/${adminRoleName}"
    $hasLocationPerm = $false

    foreach ($perm in @($lfLocPerms.PrincipalResourcePermissions)) {
        if ($perm.Principal.DataLakePrincipalIdentifier -eq $adminLocArn) {
            $hasLocationPerm = $true
            break
        }
    }

    Write-TestResult -Name "Lake Formation permissao admin no data location" -Success $hasLocationPerm
}
catch {
    Write-TestResult -Name "Lake Formation permissao admin no data location" -Success $false -Detail $_.Exception.Message
}

# ---------------------------------------------------------------------------
# Resumo
# ---------------------------------------------------------------------------
Write-Host "`n=== Resumo ===" -ForegroundColor Cyan
Write-Host "Passed: $script:Passed" -ForegroundColor Green
Write-Host "Failed: $script:Failed" -ForegroundColor $(if ($script:Failed -gt 0) { "Red" } else { "Green" })

if ($script:Failed -gt 0) {
    exit 1
}

exit 0
