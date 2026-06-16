data "aws_caller_identity" "current" {}

locals {
  data_lake_admins = length(var.data_lake_admins) > 0 ? var.data_lake_admins : [
    var.domain_admin_role_arn
  ]
}

resource "aws_lakeformation_data_lake_settings" "domain" {
  count = var.create_data_lake_settings ? 1 : 0

  admins = local.data_lake_admins

  create_database_default_permissions {
    principal   = "IAM_ALLOWED_PRINCIPALS"
    permissions = []
  }

  create_table_default_permissions {
    principal   = "IAM_ALLOWED_PRINCIPALS"
    permissions = []
  }
}

resource "aws_lakeformation_resource" "domain_bucket" {
  arn      = var.bucket_arn
  role_arn = var.etl_processing_role_arn
}

resource "aws_lakeformation_permissions" "etl_database" {
  principal   = var.etl_processing_role_arn
  permissions = ["CREATE_TABLE", "ALTER", "DROP"]

  database {
    name       = var.glue_database_name
    catalog_id = data.aws_caller_identity.current.account_id
  }

  lifecycle {
    ignore_changes = [permissions, permissions_with_grant_option]
  }

  depends_on = [aws_lakeformation_resource.domain_bucket]
}

resource "aws_lakeformation_permissions" "etl_data_location" {
  principal   = var.etl_processing_role_arn
  permissions = ["DATA_LOCATION_ACCESS"]

  data_location {
    arn = var.bucket_arn
  }

  depends_on = [aws_lakeformation_resource.domain_bucket]
}
