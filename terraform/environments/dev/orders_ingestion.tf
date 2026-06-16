locals {
  orders_table_name    = var.orders_table_name
  orders_raw_key       = "${var.orders_raw_prefix}orders.csv"
  orders_script_key    = "${var.glue_scripts_prefix}orders_ingestion.py"
  orders_source_s3_uri = "s3://${module.s3.bucket_id}/${local.orders_raw_key}"
  orders_target_s3_uri = "s3://${module.s3.bucket_id}/${var.orders_data_prefix}"
  orders_ingestion_job = "${var.domain}-domain-${var.environment}-orders-ingestion"
  orders_crawler_name  = "${var.domain}-domain-${var.environment}-orders-crawler"
}

module "glue_pedidos" {
  source = "../../modules/glue"

  database_name = var.pedidos_glue_database_name
  description   = var.pedidos_glue_database_description
  location_uri  = "s3://${module.s3.bucket_id}/${var.orders_cross_domain_prefix}"
  tags          = local.common_tags
}

resource "aws_s3_object" "orders_cross_domain_prefix" {
  bucket  = module.s3.bucket_id
  key     = var.orders_cross_domain_prefix
  content = ""
}

resource "aws_s3_object" "orders_raw_prefix" {
  bucket  = module.s3.bucket_id
  key     = var.orders_raw_prefix
  content = ""
}

resource "aws_s3_object" "orders_data_prefix" {
  bucket  = module.s3.bucket_id
  key     = var.orders_data_prefix
  content = ""
}

resource "aws_s3_object" "orders_csv" {
  bucket = module.s3.bucket_id
  key    = local.orders_raw_key
  source = var.orders_csv_path
  etag   = filemd5(var.orders_csv_path)

  tags = merge(local.common_tags, {
    Name   = "orders-csv-source"
    domain = "pedidos"
  })
}

module "orders_ingestion_job" {
  source = "../../modules/glue_job"

  job_name           = local.orders_ingestion_job
  role_arn           = module.iam.etl_processing_role_arn
  script_bucket      = module.s3.bucket_id
  script_key         = local.orders_script_key
  script_source_path = var.orders_glue_script_path
  glue_version       = var.glue_job_version
  worker_type        = var.glue_job_worker_type
  number_of_workers  = var.glue_job_number_of_workers
  timeout_minutes    = var.glue_job_timeout_minutes

  default_arguments = {
    "--SOURCE_PATH"   = local.orders_source_s3_uri
    "--TARGET_PATH"   = local.orders_target_s3_uri
    "--DATABASE_NAME" = module.glue_pedidos.database_name
    "--TABLE_NAME"    = local.orders_table_name
  }

  tags = merge(local.common_tags, {
    domain = "pedidos"
  })
}

module "orders_crawler" {
  source = "../../modules/glue_crawler"

  crawler_name   = local.orders_crawler_name
  database_name  = module.glue_pedidos.database_name
  role_arn       = module.iam.glue_crawler_role_arn
  s3_target_path = local.orders_target_s3_uri

  tags = merge(local.common_tags, {
    domain = "pedidos"
  })

  depends_on = [module.orders_ingestion_job]
}

resource "aws_glue_catalog_table" "orders" {
  name          = local.orders_table_name
  database_name = module.glue_pedidos.database_name
  table_type    = "EXTERNAL_TABLE"

  parameters = {
    classification  = "parquet"
    compressionType = "snappy"
    EXTERNAL        = "TRUE"
    domain          = "pedidos"
  }

  storage_descriptor {
    location      = local.orders_target_s3_uri
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"

    ser_de_info {
      name                  = "ParquetHiveSerDe"
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
      parameters = {
        "serialization.format" = "1"
      }
    }

    columns {
      name = "order_id"
      type = "string"
    }
    columns {
      name = "customer_id"
      type = "string"
    }
    columns {
      name = "order_approved_at"
      type = "timestamp"
    }
    columns {
      name = "order_delivered_carrier_date"
      type = "timestamp"
    }
    columns {
      name = "order_delivered_customer_date"
      type = "timestamp"
    }
    columns {
      name = "order_estimated_delivery_date"
      type = "timestamp"
    }
    columns {
      name = "order_purchase_timestamp"
      type = "timestamp"
    }
  }

  partition_keys {
    name = "order_status"
    type = "string"
  }

  lifecycle {
    ignore_changes = [parameters, storage_descriptor]
  }
}

resource "aws_lakeformation_permissions" "etl_orders_source_table" {
  principal   = module.iam.etl_processing_role_arn
  permissions = ["SELECT", "DESCRIBE"]

  table {
    database_name = module.glue_pedidos.database_name
    name          = local.orders_table_name
    catalog_id    = data.aws_caller_identity.current.account_id
  }

  depends_on = [module.lakeformation, aws_glue_catalog_table.orders]

  lifecycle {
    ignore_changes = [permissions, permissions_with_grant_option]
  }
}
