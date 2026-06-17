# DM-006 - Exposicao de Data Products via API Gateway + Lambda + Athena

locals {
  data_products_api_name = "${var.domain}-domain-${var.environment}-data-products-api"
  api_lambda_role_name   = "${var.domain}-domain-${var.environment}-api-lambda"
  lambda_src_root        = abspath("${path.module}/../../../src/lambdas")

  lambda_shared_files = {
    "shared/__init__.py"         = "${local.lambda_src_root}/shared/__init__.py"
    "shared/athena_client.py"    = "${local.lambda_src_root}/shared/athena_client.py"
    "shared/response_builder.py" = "${local.lambda_src_root}/shared/response_builder.py"
  }

  lambda_common_env = {
    ATHENA_WORKGROUP = aws_athena_workgroup.domain.name
    GLUE_DATABASE    = module.glue.database_name
  }
}

resource "aws_iam_role" "api_lambda" {
  name = local.api_lambda_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name       = local.api_lambda_role_name
    governance = "data-products-api"
  })
}

resource "aws_iam_role_policy" "api_lambda" {
  name = "${local.api_lambda_role_name}-policy"
  role = aws_iam_role.api_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.domain}-domain-${var.environment}-api-*"
      },
      {
        Sid    = "AthenaQuery"
        Effect = "Allow"
        Action = [
          "athena:StartQueryExecution",
          "athena:GetQueryExecution",
          "athena:GetQueryResults",
          "athena:StopQueryExecution",
          "athena:GetWorkGroup"
        ]
        Resource = [
          "arn:aws:athena:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:workgroup/${aws_athena_workgroup.domain.name}"
        ]
      },
      {
        Sid    = "GlueCatalogRead"
        Effect = "Allow"
        Action = [
          "glue:GetDatabase",
          "glue:GetTable",
          "glue:GetPartition",
          "glue:GetPartitions"
        ]
        Resource = [
          module.glue.database_arn,
          "arn:aws:glue:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:catalog",
          "arn:aws:glue:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:table/${module.glue.database_name}/${var.clientes_por_estado_v1_table_name}",
          "arn:aws:glue:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:table/${module.glue.database_name}/${var.clientes_ativos_v1_table_name}",
        ]
      },
      {
        Sid    = "AthenaResultsS3"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          module.s3.bucket_arn,
          "${module.s3.bucket_arn}/${var.athena_results_prefix}*"
        ]
      },
      {
        Sid    = "LakeFormationDataAccess"
        Effect = "Allow"
        Action = [
          "lakeformation:GetDataAccess"
        ]
        Resource = "*"
      }
    ]
  })
}

module "lambda_clientes_por_estado" {
  source = "../../modules/lambda_function"

  function_name = "${var.domain}-domain-${var.environment}-api-clientes-por-estado"
  handler       = "handler.handler"
  role_arn      = aws_iam_role.api_lambda.arn
  timeout       = var.data_products_api_lambda_timeout
  memory_size   = var.data_products_api_lambda_memory

  source_files = merge(local.lambda_shared_files, {
    "handler.py" = "${local.lambda_src_root}/clientes_por_estado/handler.py"
  })

  environment_variables = merge(local.lambda_common_env, {
    TABLE_NAME = var.clientes_por_estado_v1_table_name
  })

  tags = merge(local.common_tags, {
    data_product = var.clientes_por_estado_v1_table_name
    component    = "data-products-api"
  })
}

module "lambda_clientes_ativos" {
  source = "../../modules/lambda_function"

  function_name = "${var.domain}-domain-${var.environment}-api-clientes-ativos"
  handler       = "handler.handler"
  role_arn      = aws_iam_role.api_lambda.arn
  timeout       = var.data_products_api_lambda_timeout
  memory_size   = var.data_products_api_lambda_memory

  source_files = merge(local.lambda_shared_files, {
    "handler.py" = "${local.lambda_src_root}/clientes_ativos/handler.py"
  })

  environment_variables = merge(local.lambda_common_env, {
    TABLE_NAME = var.clientes_ativos_v1_table_name
  })

  tags = merge(local.common_tags, {
    data_product = var.clientes_ativos_v1_table_name
    component    = "data-products-api"
  })
}

module "data_products_api" {
  source = "../../modules/api_gateway"

  providers = {
    aws = aws.no_default_tags
  }

  api_name         = local.data_products_api_name
  stage_name       = var.data_products_api_stage_name
  api_key_required = var.data_products_api_key_required

  routes = {
    por_estado = {
      path              = "clientes/por-estado"
      lambda_invoke_arn = module.lambda_clientes_por_estado.invoke_arn
    }
    ativos = {
      path              = "clientes/ativos"
      lambda_invoke_arn = module.lambda_clientes_ativos.invoke_arn
    }
  }

  tags = merge(local.common_tags, {
    component = "data-products-api"
  })
}

resource "aws_lambda_permission" "api_clientes_por_estado" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda_clientes_por_estado.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${module.data_products_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_clientes_ativos" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda_clientes_ativos.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${module.data_products_api.execution_arn}/*/*"
}

module "api_lambda_lf" {
  source = "../../modules/lakeformation/permissions/consumer"

  consumer_role_arn  = aws_iam_role.api_lambda.arn
  glue_database_name = module.glue.database_name
  bucket_arn         = module.s3.bucket_arn

  depends_on = [module.lakeformation]
}

resource "aws_lakeformation_permissions" "api_lambda_por_estado" {
  principal   = aws_iam_role.api_lambda.arn
  permissions = ["SELECT", "DESCRIBE"]

  table {
    database_name = module.glue.database_name
    name          = var.clientes_por_estado_v1_table_name
    catalog_id    = data.aws_caller_identity.current.account_id
  }

  lifecycle {
    ignore_changes = [permissions, permissions_with_grant_option]
  }
}

resource "aws_lakeformation_permissions" "api_lambda_ativos" {
  principal   = aws_iam_role.api_lambda.arn
  permissions = ["SELECT", "DESCRIBE"]

  table {
    database_name = module.glue.database_name
    name          = var.clientes_ativos_v1_table_name
    catalog_id    = data.aws_caller_identity.current.account_id
  }

  lifecycle {
    ignore_changes = [permissions, permissions_with_grant_option]
  }
}

resource "aws_s3_object" "openapi_spec" {
  bucket = module.s3.bucket_id
  key    = "${module.s3.data_products_prefix}api/openapi-v1.yaml"
  source = var.data_products_api_openapi_path
  etag   = filemd5(var.data_products_api_openapi_path)

  tags = merge(local.common_tags, {
    Name      = "data-products-api-openapi"
    component = "data-products-api"
  })
}
