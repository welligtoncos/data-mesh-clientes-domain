resource "aws_glue_crawler" "this" {
  name          = var.crawler_name
  role          = var.role_arn
  database_name = var.database_name
  schedule      = var.schedule

  s3_target {
    path = var.s3_target_path
  }

  schema_change_policy {
    delete_behavior = "LOG"
    update_behavior = "LOG"
  }

  recrawl_policy {
    recrawl_behavior = "CRAWL_NEW_FOLDERS_ONLY"
  }

  configuration = jsonencode({
    Version = 1.0
    Grouping = {
      TableGroupingPolicy = "CombineCompatibleSchemas"
    }
    CrawlerOutput = {
      Partitions = {
        AddOrUpdateBehavior = "InheritFromTable"
      }
    }
  })

  tags = merge(var.tags, {
    Name = var.crawler_name
  })
}
