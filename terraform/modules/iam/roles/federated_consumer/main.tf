data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  trusted_principals = length(var.trusted_principals) > 0 ? var.trusted_principals : [
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
  ]

  s3_list_prefixes = distinct(flatten([
    for prefix in var.allowed_s3_prefixes : [prefix, "${prefix}*"]
  ]))

  table_arns = [
    for table_name in var.allowed_table_names :
    "arn:aws:glue:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:table/${var.glue_database_name}/${table_name}"
  ]

  s3_object_arns = [
    for prefix in var.allowed_s3_prefixes :
    "${var.bucket_arn}/${prefix}*"
  ]
}

resource "aws_iam_role" "this" {
  name = var.role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = local.trusted_principals
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(var.tags, {
    Name            = var.role_name
    Purpose         = "federated-data-product-consumer"
    consumer_domain = var.consumer_domain
  })
}

resource "aws_iam_role_policy" "read_only_data_products" {
  name = "${var.role_name}-policy"
  role = aws_iam_role.this.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3ListAuthorizedDataProducts"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = var.bucket_arn
        Condition = {
          StringLike = {
            "s3:prefix" = local.s3_list_prefixes
          }
        }
      },
      {
        Sid    = "S3ReadAuthorizedDataProducts"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion"
        ]
        Resource = local.s3_object_arns
      },
      {
        Sid    = "GlueReadAuthorizedTables"
        Effect = "Allow"
        Action = [
          "glue:GetDatabase",
          "glue:GetDatabases",
          "glue:GetTable",
          "glue:GetTables",
          "glue:GetPartition",
          "glue:GetPartitions",
          "glue:BatchGetPartition"
        ]
        Resource = concat(
          [
            var.glue_database_arn,
            "arn:aws:glue:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:catalog"
          ],
          local.table_arns
        )
      },
      {
        Sid    = "LakeFormationDataAccess"
        Effect = "Allow"
        Action = [
          "lakeformation:GetDataAccess"
        ]
        Resource = "*"
      },
      {
        Sid    = "AthenaQueryAuthorizedDataProducts"
        Effect = "Allow"
        Action = [
          "athena:StartQueryExecution",
          "athena:GetQueryExecution",
          "athena:GetQueryResults",
          "athena:StopQueryExecution",
          "athena:GetWorkGroup"
        ]
        Resource = "*"
      }
    ]
  })
}
