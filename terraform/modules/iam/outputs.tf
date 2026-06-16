output "domain_admin_role_arn" {
  description = "ARN do papel IAM de administrador do domínio."
  value       = aws_iam_role.domain_admin.arn
}

output "domain_admin_role_name" {
  description = "Nome do papel IAM de administrador do domínio."
  value       = aws_iam_role.domain_admin.name
}

output "data_product_consumer_role_arn" {
  description = "ARN do papel IAM de consumidor de Data Products."
  value       = aws_iam_role.data_product_consumer.arn
}

output "data_product_consumer_role_name" {
  description = "Nome do papel IAM de consumidor de Data Products."
  value       = aws_iam_role.data_product_consumer.name
}

output "etl_processing_role_arn" {
  description = "ARN do papel IAM de processamento ETL."
  value       = aws_iam_role.etl_processing.arn
}

output "etl_processing_role_name" {
  description = "Nome do papel IAM de processamento ETL."
  value       = aws_iam_role.etl_processing.name
}

output "glue_crawler_role_arn" {
  description = "ARN do papel IAM do Glue Crawler."
  value       = aws_iam_role.glue_crawler.arn
}

output "glue_crawler_role_name" {
  description = "Nome do papel IAM do Glue Crawler."
  value       = aws_iam_role.glue_crawler.name
}
