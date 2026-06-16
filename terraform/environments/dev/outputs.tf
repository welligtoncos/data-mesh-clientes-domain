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
