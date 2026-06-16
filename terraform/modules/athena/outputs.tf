output "table_name" {
  description = "Nome da tabela Glue Catalog."
  value       = aws_glue_catalog_table.data_product.name
}

output "table_arn" {
  description = "ARN da tabela Glue Catalog."
  value       = aws_glue_catalog_table.data_product.arn
}

output "athena_ddl" {
  description = "DDL Athena equivalente da tabela."
  value       = <<-SQL
    CREATE EXTERNAL TABLE IF NOT EXISTS ${var.database_name}.${var.table_name} (
      ${join(",\n      ", [for col in var.columns : "${col.name} ${col.type}"])}
    )
    STORED AS PARQUET
    LOCATION '${var.table_location}'
    TBLPROPERTIES ('classification'='parquet', 'compressionType'='snappy');
  SQL
}

output "named_query_id" {
  description = "ID da named query de preview no Athena."
  value       = aws_athena_named_query.data_product_preview.id
}
