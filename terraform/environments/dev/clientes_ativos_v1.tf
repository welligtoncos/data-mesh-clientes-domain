locals {
  clientes_ativos_v1_name         = var.clientes_ativos_v1_table_name
  clientes_ativos_v1_s3_prefix    = var.clientes_ativos_v1_s3_prefix
  clientes_ativos_v1_data_prefix  = "${local.clientes_ativos_v1_s3_prefix}data/"
  clientes_ativos_v1_s3_uri       = "s3://${module.s3.bucket_id}/${local.clientes_ativos_v1_data_prefix}"
  clientes_ativos_v1_script_key   = "${var.glue_scripts_prefix}clientes_ativos_v1_publish.py"
  clientes_ativos_v1_job_name     = "${var.domain}-domain-${var.environment}-clientes-ativos-v1-publish"
  clientes_ativos_v1_metadata_key = "${local.clientes_ativos_v1_s3_prefix}metadata.json"
}

resource "aws_s3_object" "clientes_ativos_v1_prefix" {
  bucket  = module.s3.bucket_id
  key     = local.clientes_ativos_v1_s3_prefix
  content = ""
}

resource "aws_s3_object" "clientes_ativos_v1_data_prefix" {
  bucket  = module.s3.bucket_id
  key     = local.clientes_ativos_v1_data_prefix
  content = ""
}

resource "aws_s3_object" "clientes_ativos_v1_metadata" {
  bucket = module.s3.bucket_id
  key    = local.clientes_ativos_v1_metadata_key
  source = var.clientes_ativos_v1_metadata_path
  etag   = filemd5(var.clientes_ativos_v1_metadata_path)

  tags = merge(local.common_tags, {
    Name         = local.clientes_ativos_v1_name
    data_product = local.clientes_ativos_v1_name
  })
}

module "clientes_ativos_v1_athena" {
  source = "../../modules/athena"

  database_name         = module.glue.database_name
  table_name            = local.clientes_ativos_v1_name
  table_location        = local.clientes_ativos_v1_s3_uri
  athena_workgroup_name = aws_athena_workgroup.domain.name
  preview_order_column  = "customer_state"

  columns = [
    { name = "customer_id", type = "string" },
    { name = "customer_unique_id", type = "string" },
    { name = "ultima_compra", type = "timestamp" },
    { name = "dias_desde_ultima_compra", type = "int" },
    { name = "ativo", type = "boolean" },
    { name = "data_referencia", type = "date" },
  ]

  partition_keys = [
    { name = "customer_state", type = "string" },
  ]

  table_parameters = {
    data_product   = local.clientes_ativos_v1_name
    domain         = var.domain
    version        = "v1"
    owner          = "Time Clientes"
    sla            = "06:00 UTC"
    periodicidade  = "diaria"
    classificacao  = "Behavioral Data Product"
    dias_atividade = tostring(var.clientes_ativos_v1_dias_atividade)
  }

  tags = merge(local.common_tags, {
    data_product = local.clientes_ativos_v1_name
  })
}

module "clientes_ativos_v1_publish_job" {
  source = "../../modules/glue_job"

  job_name           = local.clientes_ativos_v1_job_name
  role_arn           = module.iam.etl_processing_role_arn
  script_bucket      = module.s3.bucket_id
  script_key         = local.clientes_ativos_v1_script_key
  script_source_path = var.clientes_ativos_v1_glue_script_path
  glue_version       = var.glue_job_version
  worker_type        = var.glue_job_worker_type
  number_of_workers  = var.glue_job_number_of_workers
  timeout_minutes    = var.glue_job_timeout_minutes

  default_arguments = {
    "--CUSTOMER_DATABASE" = module.glue.database_name
    "--CUSTOMER_TABLE"    = var.customer_table_name
    "--ORDERS_DATABASE"   = module.glue_pedidos.database_name
    "--ORDERS_TABLE"      = var.orders_table_name
    "--TARGET_PATH"       = local.clientes_ativos_v1_s3_uri
    "--DATABASE_NAME"     = module.glue.database_name
    "--TABLE_NAME"        = local.clientes_ativos_v1_name
    "--DIAS_ATIVIDADE"    = tostring(var.clientes_ativos_v1_dias_atividade)
  }

  tags = merge(local.common_tags, {
    data_product = local.clientes_ativos_v1_name
  })
}

module "clientes_ativos_v1_lf" {
  source = "../../modules/lakeformation/data-products"

  glue_database_name           = module.glue.database_name
  data_product_table_name      = local.clientes_ativos_v1_name
  consumer_role_arns_by_domain = local.product_consumer_roles_by_domain["clientes_ativos_v1"]
  etl_processing_role_arn      = module.iam.etl_processing_role_arn
  domain_admin_role_arn        = module.iam.domain_admin_role_arn
  tags                         = local.common_tags

  depends_on = [
    module.clientes_ativos_v1_athena,
    module.federated_consumer,
  ]
}

resource "aws_glue_trigger" "clientes_ativos_v1_daily" {
  name     = "${var.domain}-domain-${var.environment}-clientes-ativos-v1-daily"
  type     = "SCHEDULED"
  schedule = var.clientes_ativos_v1_schedule_cron
  enabled  = var.clientes_ativos_v1_schedule_enabled

  actions {
    job_name = module.clientes_ativos_v1_publish_job.job_name
  }

  tags = merge(local.common_tags, {
    data_product = local.clientes_ativos_v1_name
    sla          = "06:00 UTC"
  })
}

resource "null_resource" "run_clientes_ativos_v1_publish" {
  count = var.run_clientes_ativos_v1_on_apply ? 1 : 0

  triggers = {
    script_md = filemd5(var.clientes_ativos_v1_glue_script_path)
    job_name  = module.clientes_ativos_v1_publish_job.job_name
  }

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-Command"]
    command     = <<-EOT
      $ErrorActionPreference = 'Stop'
      $jobName = '${module.clientes_ativos_v1_publish_job.job_name}'
      $run = aws glue start-job-run --job-name $jobName --output json | ConvertFrom-Json
      $runId = $run.JobRunId
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
    module.clientes_ativos_v1_publish_job,
    module.clientes_ativos_v1_athena,
    module.clientes_ativos_v1_lf,
    module.customer_ingestion_job,
    module.orders_ingestion_job
  ]
}
