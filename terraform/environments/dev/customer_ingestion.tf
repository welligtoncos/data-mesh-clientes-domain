locals {
  customer_table_name    = var.customer_table_name
  customer_s3_prefix     = var.customer_data_prefix
  customer_raw_key       = "${var.customer_raw_prefix}customers.csv"
  customer_script_key    = "${var.glue_scripts_prefix}customer_ingestion.py"
  customer_source_s3_uri = "s3://${module.s3.bucket_id}/${local.customer_raw_key}"
  customer_target_s3_uri = "s3://${module.s3.bucket_id}/${local.customer_s3_prefix}"
  customer_ingestion_job = "${var.domain}-domain-${var.environment}-customer-ingestion"
  customer_crawler_name  = "${var.domain}-domain-${var.environment}-customer-crawler"
}

resource "aws_s3_object" "customer_raw_prefix" {
  bucket  = module.s3.bucket_id
  key     = var.customer_raw_prefix
  content = ""
}

resource "aws_s3_object" "customer_data_prefix" {
  bucket  = module.s3.bucket_id
  key     = local.customer_s3_prefix
  content = ""
}

resource "aws_s3_object" "glue_scripts_prefix" {
  bucket  = module.s3.bucket_id
  key     = var.glue_scripts_prefix
  content = ""
}

resource "aws_s3_object" "customers_csv" {
  bucket = module.s3.bucket_id
  key    = local.customer_raw_key
  source = var.customers_csv_path
  etag   = filemd5(var.customers_csv_path)

  tags = merge(local.common_tags, {
    Name         = "customers-csv-source"
    data_product = local.customer_table_name
  })
}

module "customer_ingestion_job" {
  source = "../../modules/glue_job"

  job_name           = local.customer_ingestion_job
  role_arn           = module.iam.etl_processing_role_arn
  script_bucket      = module.s3.bucket_id
  script_key         = local.customer_script_key
  script_source_path = var.customer_glue_script_path
  glue_version       = var.glue_job_version
  worker_type        = var.glue_job_worker_type
  number_of_workers  = var.glue_job_number_of_workers
  timeout_minutes    = var.glue_job_timeout_minutes

  default_arguments = {
    "--SOURCE_PATH"   = local.customer_source_s3_uri
    "--TARGET_PATH"   = local.customer_target_s3_uri
    "--DATABASE_NAME" = module.glue.database_name
    "--TABLE_NAME"    = local.customer_table_name
  }

  tags = merge(local.common_tags, {
    data_product = local.customer_table_name
  })
}

module "customer_crawler" {
  source = "../../modules/glue_crawler"

  crawler_name   = local.customer_crawler_name
  database_name  = module.glue.database_name
  role_arn       = module.iam.glue_crawler_role_arn
  s3_target_path = local.customer_target_s3_uri

  tags = merge(local.common_tags, {
    data_product = local.customer_table_name
  })

  depends_on = [module.customer_ingestion_job]
}

resource "aws_lakeformation_permissions" "etl_customer_source_table" {
  principal   = module.iam.etl_processing_role_arn
  permissions = ["SELECT", "DESCRIBE"]

  table {
    database_name = module.glue.database_name
    name          = local.customer_table_name
    catalog_id    = data.aws_caller_identity.current.account_id
  }

  depends_on = [module.lakeformation]

  lifecycle {
    ignore_changes = [permissions, permissions_with_grant_option]
  }
}

resource "null_resource" "run_customer_ingestion" {
  count = var.run_customer_ingestion_on_apply ? 1 : 0

  triggers = {
    csv_etag  = aws_s3_object.customers_csv.etag
    script_md = filemd5(var.customer_glue_script_path)
    job_name  = module.customer_ingestion_job.job_name
  }

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-Command"]
    command     = <<-EOT
      $ErrorActionPreference = 'Stop'
      $jobName = '${module.customer_ingestion_job.job_name}'
      $run = aws glue start-job-run --job-name $jobName --output json | ConvertFrom-Json
      $runId = $run.JobRunId
      Write-Host "Started Glue Job $jobName run $runId"
      do {
        Start-Sleep -Seconds 15
        $status = aws glue get-job-run --job-name $jobName --run-id $runId --output json | ConvertFrom-Json
        $state = $status.JobRun.JobRunState
        Write-Host "Job state: $state"
      } while ($state -in @('RUNNING', 'STARTING', 'STOPPING'))
      if ($state -ne 'SUCCEEDED') { throw "Glue Job failed with state $state" }
    EOT
  }

  depends_on = [
    module.customer_ingestion_job,
    aws_s3_object.customers_csv,
    module.lakeformation
  ]
}

resource "null_resource" "run_customer_crawler" {
  count = var.run_customer_ingestion_on_apply ? 1 : 0

  triggers = {
    ingestion = null_resource.run_customer_ingestion[0].id
  }

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-Command"]
    command     = <<-EOT
      $ErrorActionPreference = 'Stop'
      $crawler = '${module.customer_crawler.crawler_name}'
      aws glue start-crawler --name $crawler
      do {
        Start-Sleep -Seconds 10
        $status = aws glue get-crawler --name $crawler --output json | ConvertFrom-Json
        $state = $status.Crawler.State
        Write-Host "Crawler state: $state"
      } while ($state -eq 'RUNNING')
      if ($state -ne 'READY') { throw "Glue Crawler ended with state $state" }
    EOT
  }

  depends_on = [null_resource.run_customer_ingestion]
}

resource "aws_athena_workgroup" "domain" {
  name = "${var.domain}-domain-${var.environment}"

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true

    result_configuration {
      output_location = "s3://${module.s3.bucket_id}/${var.athena_results_prefix}"
    }
  }

  tags = merge(local.common_tags, {
    Name = "${var.domain}-domain-${var.environment}-athena"
  })
}

resource "aws_s3_object" "athena_results_prefix" {
  bucket  = module.s3.bucket_id
  key     = var.athena_results_prefix
  content = ""
}
