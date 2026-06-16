data "aws_caller_identity" "current" {}

resource "aws_lakeformation_permissions" "domain_admin_database" {
  principal   = var.domain_admin_role_arn
  permissions = ["ALL"]

  database {
    name       = var.glue_database_name
    catalog_id = data.aws_caller_identity.current.account_id
  }

  lifecycle {
    ignore_changes = [permissions, permissions_with_grant_option]
  }
}

resource "aws_lakeformation_permissions" "domain_admin_data_location" {
  principal   = var.domain_admin_role_arn
  permissions = ["DATA_LOCATION_ACCESS"]

  data_location {
    arn = var.bucket_arn
  }
}
