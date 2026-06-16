data "aws_caller_identity" "current" {}

resource "aws_lakeformation_permissions" "consumer_database" {
  principal   = var.consumer_role_arn
  permissions = ["DESCRIBE"]

  database {
    name       = var.glue_database_name
    catalog_id = data.aws_caller_identity.current.account_id
  }

  lifecycle {
    ignore_changes = [permissions, permissions_with_grant_option]
  }
}

resource "aws_lakeformation_permissions" "consumer_data_location" {
  principal   = var.consumer_role_arn
  permissions = ["DATA_LOCATION_ACCESS"]

  data_location {
    arn = var.bucket_arn
  }
}
