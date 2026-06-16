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
