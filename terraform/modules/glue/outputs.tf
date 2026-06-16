output "database_name" {
  description = "Nome do database Glue Catalog."
  value       = aws_glue_catalog_database.domain.name
}

output "database_arn" {
  description = "ARN do database Glue Catalog."
  value       = aws_glue_catalog_database.domain.arn
}
