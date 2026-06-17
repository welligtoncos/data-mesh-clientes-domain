output "account_id" {
  description = "ID da conta AWS onde os recursos foram provisionados."
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = "Região AWS utilizada no deploy."
  value       = data.aws_region.current.region
}

output "bucket_name" {
  description = "Nome do bucket S3 do domínio Clientes."
  value       = module.s3.bucket_id
}

output "bucket_arn" {
  description = "ARN do bucket S3 do domínio Clientes."
  value       = module.s3.bucket_arn
}

output "internal_data_prefix" {
  description = "Prefixo S3 para datasets internos."
  value       = "s3://${module.s3.bucket_id}/${module.s3.internal_prefix}"
}

output "data_products_prefix" {
  description = "Prefixo S3 para Data Products publicados."
  value       = "s3://${module.s3.bucket_id}/${module.s3.data_products_prefix}"
}

output "glue_database_name" {
  description = "Nome do database Glue Catalog."
  value       = module.glue.database_name
}

output "glue_database_arn" {
  description = "ARN do database Glue Catalog."
  value       = module.glue.database_arn
}

output "iam_domain_admin_role_arn" {
  description = "ARN do papel IAM de administrador do domínio."
  value       = module.iam.domain_admin_role_arn
}

output "iam_domain_admin_role_name" {
  description = "Nome do papel IAM de administrador do domínio."
  value       = module.iam.domain_admin_role_name
}

output "iam_data_product_consumer_role_arn" {
  description = "ARN do papel IAM de consumidor de Data Products."
  value       = module.iam.data_product_consumer_role_arn
}

output "iam_data_product_consumer_role_name" {
  description = "Nome do papel IAM de consumidor de Data Products."
  value       = module.iam.data_product_consumer_role_name
}

output "iam_etl_processing_role_arn" {
  description = "ARN do papel IAM de processamento ETL."
  value       = module.iam.etl_processing_role_arn
}

output "iam_etl_processing_role_name" {
  description = "Nome do papel IAM de processamento ETL."
  value       = module.iam.etl_processing_role_name
}

output "lakeformation_registered_resource_arn" {
  description = "ARN do bucket registrado no Lake Formation."
  value       = module.lakeformation.registered_resource_arn
}

# DM-002 - Ingestao customer
output "customer_table_name" {
  description = "Nome da tabela Glue Catalog customer."
  value       = local.customer_table_name
}

output "customer_source_s3_uri" {
  description = "URI S3 do arquivo customers.csv na area raw."
  value       = local.customer_source_s3_uri
}

output "customer_target_s3_uri" {
  description = "URI S3 do Data Product customer em Parquet."
  value       = local.customer_target_s3_uri
}

output "customer_glue_job_name" {
  description = "Nome do Glue Job de ingestao customer."
  value       = module.customer_ingestion_job.job_name
}

output "customer_glue_crawler_name" {
  description = "Nome do Glue Crawler do Data Product customer."
  value       = module.customer_crawler.crawler_name
}

output "customer_glue_crawler_role_arn" {
  description = "ARN do papel IAM do Glue Crawler."
  value       = module.iam.glue_crawler_role_arn
}

output "athena_workgroup_name" {
  description = "Nome do workgroup Athena do dominio."
  value       = aws_athena_workgroup.domain.name
}

output "customers_csv_local_path" {
  description = "Caminho local do arquivo customers.csv usado no upload."
  value       = var.customers_csv_path
}

# DM-003 - Data Product clientes_por_estado_v1
output "clientes_por_estado_v1_table_name" {
  description = "Nome da tabela publicada clientes_por_estado_v1."
  value       = local.clientes_por_estado_v1_name
}

output "clientes_por_estado_v1_s3_uri" {
  description = "URI S3 dos dados Parquet do Data Product publicado."
  value       = local.clientes_por_estado_v1_s3_uri
}

output "clientes_por_estado_v1_metadata_s3_uri" {
  description = "URI S3 dos metadados do Data Product (fora do path da tabela)."
  value       = "s3://${module.s3.bucket_id}/${local.clientes_por_estado_v1_metadata_key}"
}

output "clientes_por_estado_v1_glue_job_name" {
  description = "Nome do Glue Job de publicacao."
  value       = module.clientes_por_estado_v1_publish_job.job_name
}

output "clientes_por_estado_v1_athena_ddl" {
  description = "DDL Athena do Data Product."
  value       = module.clientes_por_estado_v1_athena.athena_ddl
}

output "clientes_por_estado_v1_schedule_cron" {
  description = "Expressao cron do SLA diario."
  value       = var.clientes_por_estado_v1_schedule_cron
}

# DM-004 - clientes_ativos_v1
output "pedidos_glue_database_name" {
  description = "Nome do database Glue do dominio Pedidos."
  value       = module.glue_pedidos.database_name
}

output "orders_table_name" {
  description = "Nome da tabela orders (fonte cross-domain)."
  value       = local.orders_table_name
}

output "orders_glue_job_name" {
  description = "Nome do Glue Job de ingestao orders."
  value       = module.orders_ingestion_job.job_name
}

output "clientes_ativos_v1_table_name" {
  description = "Nome da tabela publicada clientes_ativos_v1."
  value       = local.clientes_ativos_v1_name
}

output "clientes_ativos_v1_s3_uri" {
  description = "URI S3 dos dados Parquet do Data Product."
  value       = local.clientes_ativos_v1_s3_uri
}

output "clientes_ativos_v1_metadata_s3_uri" {
  description = "URI S3 dos metadados do Data Product."
  value       = "s3://${module.s3.bucket_id}/${local.clientes_ativos_v1_metadata_key}"
}

output "clientes_ativos_v1_glue_job_name" {
  description = "Nome do Glue Job de publicacao."
  value       = module.clientes_ativos_v1_publish_job.job_name
}

output "clientes_ativos_v1_dias_atividade" {
  description = "Janela em dias para cliente ativo."
  value       = var.clientes_ativos_v1_dias_atividade
}

output "clientes_ativos_v1_athena_ddl" {
  description = "DDL Athena do Data Product clientes_ativos_v1."
  value       = module.clientes_ativos_v1_athena.athena_ddl
}

# DM-005 - Governanca federada
output "clientes_admin_role_arn" {
  description = "ARN do papel administrador do dominio Clientes (alias domain admin)."
  value       = module.iam.domain_admin_role_arn
}

output "clientes_admin_role_name" {
  description = "Nome do papel administrador do dominio Clientes."
  value       = module.iam.domain_admin_role_name
}

output "federated_consumer_role_arns" {
  description = "ARNs dos papeis consumidores federados por dominio."
  value       = { for k, m in module.federated_consumer : k => m.role_arn }
}

output "federated_consumer_role_names" {
  description = "Nomes dos papeis consumidores federados por dominio."
  value       = { for k, m in module.federated_consumer : k => m.role_name }
}

output "governance_policy_s3_uri" {
  description = "URI S3 do catalogo de politicas federadas."
  value       = "s3://${module.s3.bucket_id}/${module.s3.data_products_prefix}governance/federated-policy.json"
}

output "marketing_consumer_role_arn" {
  description = "ARN do papel consumidor Marketing."
  value       = module.federated_consumer["marketing"].role_arn
}

output "analytics_consumer_role_arn" {
  description = "ARN do papel consumidor Analytics."
  value       = module.federated_consumer["analytics"].role_arn
}

output "datascience_consumer_role_arn" {
  description = "ARN do papel consumidor Data Science."
  value       = module.federated_consumer["datascience"].role_arn
}

output "crm_consumer_role_arn" {
  description = "ARN do papel consumidor CRM."
  value       = module.federated_consumer["crm"].role_arn
}

# DM-006 - API Data Products
output "data_products_api_id" {
  description = "ID do API Gateway de Data Products."
  value       = module.data_products_api.api_id
}

output "data_products_api_invoke_url" {
  description = "URL base da API de Data Products."
  value       = module.data_products_api.stage_invoke_url
}

output "data_products_api_por_estado_url" {
  description = "URL do endpoint GET /clientes/por-estado."
  value       = module.data_products_api.por_estado_url
}

output "data_products_api_ativos_url" {
  description = "URL do endpoint GET /clientes/ativos."
  value       = module.data_products_api.ativos_url
}

output "data_products_api_key" {
  description = "API Key para consumo da API de Data Products."
  value       = module.data_products_api.api_key_value
  sensitive   = true
}

output "data_products_api_lambda_por_estado_name" {
  description = "Nome da Lambda clientes por estado."
  value       = module.lambda_clientes_por_estado.function_name
}

output "data_products_api_lambda_ativos_name" {
  description = "Nome da Lambda clientes ativos."
  value       = module.lambda_clientes_ativos.function_name
}

output "data_products_api_lambda_role_name" {
  description = "Nome do papel IAM das Lambdas da API."
  value       = aws_iam_role.api_lambda.name
}

output "data_products_api_openapi_s3_uri" {
  description = "URI S3 do contrato OpenAPI."
  value       = "s3://${module.s3.bucket_id}/${module.s3.data_products_prefix}api/openapi-v1.yaml"
}
