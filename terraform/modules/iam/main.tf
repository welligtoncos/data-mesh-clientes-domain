data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  role_name_prefix = "${var.domain_name}-domain-${var.environment}"

  admin_trusted_principals = length(var.admin_trusted_principals) > 0 ? var.admin_trusted_principals : [
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
  ]

  consumer_trusted_principals = length(var.consumer_trusted_principals) > 0 ? var.consumer_trusted_principals : [
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
  ]
}

# ---------------------------------------------------------------------------
# Domain Admin — ownership total do domínio (S3, Glue, Lake Formation)
# ---------------------------------------------------------------------------
resource "aws_iam_role" "domain_admin" {
  name = "${local.role_name_prefix}-admin"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = local.admin_trusted_principals
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(var.tags, {
    Name    = "${local.role_name_prefix}-admin"
    Purpose = "domain-admin"
  })
}

resource "aws_iam_role_policy" "domain_admin" {
  name = "${local.role_name_prefix}-admin-policy"
  role = aws_iam_role.domain_admin.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3FullDomainAccess"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:GetBucketVersioning",
          "s3:PutBucketVersioning"
        ]
        Resource = var.bucket_arn
      },
      {
        Sid    = "S3ObjectFullAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:GetObjectVersion",
          "s3:DeleteObjectVersion"
        ]
        Resource = "${var.bucket_arn}/*"
      },
      {
        Sid    = "GlueCatalogAdmin"
        Effect = "Allow"
        Action = [
          "glue:GetDatabase",
          "glue:GetDatabases",
          "glue:CreateDatabase",
          "glue:UpdateDatabase",
          "glue:DeleteDatabase",
          "glue:GetTable",
          "glue:GetTables",
          "glue:CreateTable",
          "glue:UpdateTable",
          "glue:DeleteTable",
          "glue:BatchCreatePartition",
          "glue:BatchDeletePartition",
          "glue:BatchGetPartition",
          "glue:GetPartition",
          "glue:GetPartitions",
          "glue:CreatePartition",
          "glue:UpdatePartition",
          "glue:DeletePartition"
        ]
        Resource = [
          var.glue_database_arn,
          "arn:aws:glue:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:catalog",
          "arn:aws:glue:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:table/${var.glue_database_name}/*"
        ]
      },
      {
        Sid    = "LakeFormationAdmin"
        Effect = "Allow"
        Action = [
          "lakeformation:GetDataAccess",
          "lakeformation:GrantPermissions",
          "lakeformation:RevokePermissions",
          "lakeformation:ListPermissions",
          "lakeformation:GetResourceLfTags",
          "lakeformation:ListResources",
          "lakeformation:RegisterResource",
          "lakeformation:DeregisterResource",
          "lakeformation:DescribeResource",
          "lakeformation:AddLFTagsToResource",
          "lakeformation:RemoveLFTagsFromResource",
          "lakeformation:GetLFTag",
          "lakeformation:ListLFTags",
          "lakeformation:CreateLFTag",
          "lakeformation:UpdateLFTag",
          "lakeformation:DeleteLFTag"
        ]
        Resource = "*"
      },
      {
        Sid    = "AthenaQueryAccess"
        Effect = "Allow"
        Action = [
          "athena:StartQueryExecution",
          "athena:GetQueryExecution",
          "athena:GetQueryResults",
          "athena:StopQueryExecution",
          "athena:GetWorkGroup",
          "athena:ListWorkGroups"
        ]
        Resource = "*"
      }
    ]
  })
}

# ---------------------------------------------------------------------------
# Data Product Consumer — leitura de Data Products publicados
# ---------------------------------------------------------------------------
resource "aws_iam_role" "data_product_consumer" {
  name = "${local.role_name_prefix}-consumer"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = local.consumer_trusted_principals
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(var.tags, {
    Name    = "${local.role_name_prefix}-consumer"
    Purpose = "data-product-consumer"
  })
}

resource "aws_iam_role_policy" "data_product_consumer" {
  name = "${local.role_name_prefix}-consumer-policy"
  role = aws_iam_role.data_product_consumer.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3ListDataProducts"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = var.bucket_arn
        Condition = {
          StringLike = {
            "s3:prefix" = [
              var.data_products_prefix,
              "${var.data_products_prefix}*",
              var.customer_data_prefix,
              "${var.customer_data_prefix}*"
            ]
          }
        }
      },
      {
        Sid    = "S3ReadDataProducts"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion"
        ]
        Resource = "${var.bucket_arn}/${var.data_products_prefix}*"
      },
      {
        Sid    = "S3ReadCustomerDataProduct"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion"
        ]
        Resource = "${var.bucket_arn}/${var.customer_data_prefix}*"
      },
      {
        Sid    = "GlueReadCatalog"
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
        Resource = [
          var.glue_database_arn,
          "arn:aws:glue:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:catalog",
          "arn:aws:glue:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:table/${var.glue_database_name}/*"
        ]
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
        Sid    = "AthenaQueryDataProducts"
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

# ---------------------------------------------------------------------------
# ETL Processing — pipelines de transformação do domínio
# ---------------------------------------------------------------------------
resource "aws_iam_role" "etl_processing" {
  name = "${local.role_name_prefix}-etl"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = [
            "glue.amazonaws.com",
            "states.amazonaws.com"
          ]
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(var.tags, {
    Name    = "${local.role_name_prefix}-etl"
    Purpose = "etl-processing"
  })
}

resource "aws_iam_role_policy" "etl_processing" {
  name = "${local.role_name_prefix}-etl-policy"
  role = aws_iam_role.etl_processing.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3ListDomainBucket"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = var.bucket_arn
      },
      {
        Sid    = "S3ReadWriteDomainData"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:GetObjectVersion"
        ]
        Resource = [
          "${var.bucket_arn}/${var.internal_prefix}*",
          "${var.bucket_arn}/${var.data_products_prefix}*",
          "${var.bucket_arn}/${var.customer_data_prefix}*"
        ]
      },
      {
        Sid    = "GlueETLAccess"
        Effect = "Allow"
        Action = [
          "glue:GetDatabase",
          "glue:GetDatabases",
          "glue:GetTable",
          "glue:GetTables",
          "glue:CreateTable",
          "glue:UpdateTable",
          "glue:DeleteTable",
          "glue:GetPartition",
          "glue:GetPartitions",
          "glue:CreatePartition",
          "glue:UpdatePartition",
          "glue:DeletePartition",
          "glue:BatchCreatePartition",
          "glue:BatchGetPartition"
        ]
        Resource = [
          var.glue_database_arn,
          "arn:aws:glue:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:catalog",
          "arn:aws:glue:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:table/${var.glue_database_name}/*"
        ]
      },
      {
        Sid    = "GlueServiceAccess"
        Effect = "Allow"
        Action = [
          "glue:CreateJob",
          "glue:UpdateJob",
          "glue:GetJob",
          "glue:GetJobs",
          "glue:StartJobRun",
          "glue:GetJobRun",
          "glue:GetJobRuns",
          "glue:BatchStopJobRun"
        ]
        Resource = "arn:aws:glue:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:job/*"
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
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws-glue/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "etl_glue_service" {
  role       = aws_iam_role.etl_processing.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# ---------------------------------------------------------------------------
# Glue Crawler — catalogacao de Data Products
# ---------------------------------------------------------------------------
resource "aws_iam_role" "glue_crawler" {
  name = "${local.role_name_prefix}-crawler"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(var.tags, {
    Name    = "${local.role_name_prefix}-crawler"
    Purpose = "glue-crawler"
  })
}

resource "aws_iam_role_policy" "glue_crawler" {
  name = "${local.role_name_prefix}-crawler-policy"
  role = aws_iam_role.glue_crawler.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3ListDomainBucket"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = var.bucket_arn
      },
      {
        Sid    = "S3ReadCatalogTargets"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion"
        ]
        Resource = [
          "${var.bucket_arn}/${var.customer_data_prefix}*",
          "${var.bucket_arn}/${var.data_products_prefix}*"
        ]
      },
      {
        Sid    = "GlueCrawlerCatalogAccess"
        Effect = "Allow"
        Action = [
          "glue:GetDatabase",
          "glue:GetDatabases",
          "glue:GetTable",
          "glue:GetTables",
          "glue:CreateTable",
          "glue:UpdateTable",
          "glue:GetPartition",
          "glue:GetPartitions",
          "glue:CreatePartition",
          "glue:UpdatePartition",
          "glue:BatchCreatePartition",
          "glue:BatchGetPartition"
        ]
        Resource = [
          var.glue_database_arn,
          "arn:aws:glue:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:catalog",
          "arn:aws:glue:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:table/${var.glue_database_name}/*"
        ]
      },
      {
        Sid    = "GlueCrawlerServiceAccess"
        Effect = "Allow"
        Action = [
          "glue:StartCrawler",
          "glue:StopCrawler",
          "glue:GetCrawler",
          "glue:GetCrawlers"
        ]
        Resource = "arn:aws:glue:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:crawler/*"
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
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws-glue/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "glue_crawler_service" {
  role       = aws_iam_role.glue_crawler.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}
