data "aws_caller_identity" "current" {}

resource "aws_lakeformation_permissions" "consumer_data_product_table" {
  principal   = var.data_product_consumer_role_arn
  permissions = ["SELECT", "DESCRIBE"]

  table {
    database_name = var.glue_database_name
    name          = var.data_product_table_name
    catalog_id    = data.aws_caller_identity.current.account_id
  }

  lifecycle {
    ignore_changes = [permissions, permissions_with_grant_option]
  }
}

resource "aws_lakeformation_permissions" "etl_data_product_table" {
  principal   = var.etl_processing_role_arn
  permissions = ["ALL"]

  table {
    database_name = var.glue_database_name
    name          = var.data_product_table_name
    catalog_id    = data.aws_caller_identity.current.account_id
  }

  lifecycle {
    ignore_changes = [permissions, permissions_with_grant_option]
  }
}

resource "aws_lakeformation_permissions" "admin_data_product_table" {
  principal   = var.domain_admin_role_arn
  permissions = ["ALL"]

  table {
    database_name = var.glue_database_name
    name          = var.data_product_table_name
    catalog_id    = data.aws_caller_identity.current.account_id
  }

  lifecycle {
    ignore_changes = [permissions, permissions_with_grant_option]
  }
}
