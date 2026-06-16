resource "aws_glue_catalog_table" "data_product" {
  name          = var.table_name
  database_name = var.database_name
  table_type    = "EXTERNAL_TABLE"

  parameters = merge(
    {
      classification  = "parquet"
      compressionType = "snappy"
      EXTERNAL        = "TRUE"
    },
    var.table_parameters
  )

  storage_descriptor {
    location      = var.table_location
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"

    ser_de_info {
      name                  = "ParquetHiveSerDe"
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"

      parameters = {
        "serialization.format" = "1"
      }
    }

    dynamic "columns" {
      for_each = var.columns
      content {
        name = columns.value.name
        type = columns.value.type
      }
    }
  }
}

resource "aws_athena_named_query" "data_product_preview" {
  name        = "${var.table_name}-preview"
  database    = var.database_name
  description = "Consulta de validacao do Data Product ${var.table_name}."

  query = <<-SQL
    SELECT *
    FROM ${var.database_name}.${var.table_name}
    ORDER BY total_clientes DESC
    LIMIT 100;
  SQL

  workgroup = var.athena_workgroup_name
}
