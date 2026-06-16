data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  common_tags = {
    project     = var.project
    domain      = var.domain
    managed_by  = "terraform"
    environment = var.environment
  }

  bucket_name = coalesce(
    var.bucket_name,
    "${data.aws_caller_identity.current.account_id}-${var.domain}-domain-${var.environment}"
  )
}

module "s3" {
  source = "../../modules/s3"

  bucket_name       = local.bucket_name
  tags              = local.common_tags
  enable_versioning = var.enable_bucket_versioning
  force_destroy     = var.force_destroy_bucket
}

module "glue" {
  source = "../../modules/glue"

  database_name = var.glue_database_name
  description   = var.glue_database_description
  location_uri  = "s3://${module.s3.bucket_id}/"
  tags          = local.common_tags
}

module "iam" {
  source = "../../modules/iam"

  domain_name                        = var.domain
  environment                        = var.environment
  bucket_arn                         = module.s3.bucket_arn
  bucket_name                        = module.s3.bucket_id
  glue_database_name                 = module.glue.database_name
  glue_database_arn                  = module.glue.database_arn
  data_products_prefix               = module.s3.data_products_prefix
  internal_prefix                    = module.s3.internal_prefix
  customer_data_prefix               = var.customer_data_prefix
  published_data_product_tables      = var.published_data_product_tables
  published_data_product_s3_prefixes = var.published_data_product_s3_prefixes
  cross_domain_glue_catalogs = [
    {
      database_name = module.glue_pedidos.database_name
      database_arn  = module.glue_pedidos.database_arn
      s3_prefix     = var.orders_data_prefix
    }
  ]
  admin_trusted_principals    = var.admin_trusted_principals
  consumer_trusted_principals = var.consumer_trusted_principals
  tags                        = local.common_tags
}

module "lakeformation" {
  source = "../../modules/lakeformation"

  bucket_arn                     = module.s3.bucket_arn
  glue_database_name             = module.glue.database_name
  domain_admin_role_arn          = module.iam.domain_admin_role_arn
  data_product_consumer_role_arn = module.iam.data_product_consumer_role_arn
  etl_processing_role_arn        = module.iam.etl_processing_role_arn
  create_data_lake_settings      = var.create_data_lake_settings
  data_lake_admins               = var.data_lake_admins
  tags                           = local.common_tags
}
