# DM-005 - Governanca federada Lake Formation

locals {
  governed_data_products = {
    clientes_por_estado_v1 = {
      table_name = var.clientes_por_estado_v1_table_name
      s3_prefix  = var.clientes_por_estado_v1_s3_prefix
      consumers  = var.clientes_por_estado_v1_consumer_domains
    }
    clientes_ativos_v1 = {
      table_name = var.clientes_ativos_v1_table_name
      s3_prefix  = var.clientes_ativos_v1_s3_prefix
      consumers  = var.clientes_ativos_v1_consumer_domains
    }
  }

  federated_consumer_domains = toset(distinct(flatten([
    for product in local.governed_data_products : product.consumers
  ])))

  federated_consumer_tables = {
    for domain in local.federated_consumer_domains : domain => [
      for key, product in local.governed_data_products : product.table_name
      if contains(product.consumers, domain)
    ]
  }

  federated_consumer_s3_prefixes = {
    for domain in local.federated_consumer_domains : domain => [
      for key, product in local.governed_data_products : product.s3_prefix
      if contains(product.consumers, domain)
    ]
  }

  product_consumer_roles_by_domain = {
    for key, product in local.governed_data_products : key => {
      for domain in product.consumers : domain => module.federated_consumer[domain].role_arn
    }
  }
}

module "federated_consumer" {
  for_each = local.federated_consumer_domains
  source   = "../../modules/iam/roles/federated_consumer"

  role_name           = "${var.domain}-domain-${var.environment}-${each.key}-consumer"
  consumer_domain     = each.key
  trusted_principals  = lookup(var.federated_consumer_trusted_principals, each.key, [])
  bucket_arn          = module.s3.bucket_arn
  glue_database_arn   = module.glue.database_arn
  glue_database_name  = module.glue.database_name
  allowed_table_names = local.federated_consumer_tables[each.key]
  allowed_s3_prefixes = local.federated_consumer_s3_prefixes[each.key]

  tags = merge(local.common_tags, {
    governance = "federated-consumer"
  })
}

module "lakeformation_admins" {
  source = "../../modules/lakeformation/admins"

  domain_admin_role_arn = module.iam.domain_admin_role_arn
  glue_database_name    = module.glue.database_name
  bucket_arn            = module.s3.bucket_arn

  depends_on = [module.lakeformation]
}

module "federated_consumer_lf" {
  for_each = local.federated_consumer_domains
  source   = "../../modules/lakeformation/permissions/consumer"

  consumer_role_arn  = module.federated_consumer[each.key].role_arn
  glue_database_name = module.glue.database_name
  bucket_arn         = module.s3.bucket_arn

  depends_on = [module.lakeformation]
}

resource "aws_s3_object" "governance_policy_catalog" {
  bucket = module.s3.bucket_id
  key    = "${module.s3.data_products_prefix}governance/federated-policy.json"
  content = jsonencode({
    version      = "v1"
    owner_domain = var.domain
    managed_by   = "terraform"
    products = {
      for key, product in local.governed_data_products : key => {
        owner     = "Time Clientes"
        consumers = product.consumers
      }
    }
    consumer_roles = {
      for domain, mod in module.federated_consumer : domain => mod.role_name
    }
  })

  tags = merge(local.common_tags, {
    Name       = "federated-governance-policy"
    governance = "lake-formation"
  })
}

resource "null_resource" "revoke_legacy_consumer_lf_grants" {
  count = var.enable_federated_governance ? 1 : 0

  triggers = {
    policy = aws_s3_object.governance_policy_catalog.etag
  }

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-Command"]
    command     = <<-EOT
      $ErrorActionPreference = 'SilentlyContinue'
      $principal = '${module.iam.data_product_consumer_role_arn}'
      $db = '${module.glue.database_name}'
      foreach ($table in @('${var.clientes_por_estado_v1_table_name}', '${var.clientes_ativos_v1_table_name}')) {
        $res = @{ Table = @{ DatabaseName = $db; Name = $table } } | ConvertTo-Json -Compress
        $f = [System.IO.Path]::GetTempFileName() + '.json'
        [System.IO.File]::WriteAllText($f, $res, [System.Text.UTF8Encoding]::new($false))
        aws lakeformation revoke-permissions --principal "DataLakePrincipalIdentifier=$principal" --permissions SELECT DESCRIBE --resource "file://$($f -replace '\\','/')"
        Remove-Item $f -Force
      }
    EOT
  }

  depends_on = [
    module.clientes_por_estado_v1_lf,
    module.clientes_ativos_v1_lf,
    aws_s3_object.governance_policy_catalog,
  ]
}
