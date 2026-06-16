output "registered_resource_arn" {
  description = "ARN do recurso S3 registrado no Lake Formation."
  value       = aws_lakeformation_resource.domain_bucket.arn
}

output "data_lake_settings_created" {
  description = "Indica se as configurações do Data Lake foram criadas neste deploy."
  value       = var.create_data_lake_settings
}
