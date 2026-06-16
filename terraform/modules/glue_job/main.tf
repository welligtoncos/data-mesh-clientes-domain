resource "aws_s3_object" "script" {
  bucket = var.script_bucket
  key    = var.script_key
  source = var.script_source_path
  etag   = filemd5(var.script_source_path)

  tags = merge(var.tags, {
    Name = var.script_key
  })
}

resource "aws_glue_job" "this" {
  name     = var.job_name
  role_arn = var.role_arn

  glue_version      = var.glue_version
  worker_type       = var.worker_type
  number_of_workers = var.number_of_workers
  timeout           = var.timeout_minutes

  command {
    name            = "glueetl"
    script_location = "s3://${var.script_bucket}/${var.script_key}"
    python_version  = "3"
  }

  default_arguments = merge(
    {
      "--job-language"                     = "python"
      "--enable-metrics"                   = "true"
      "--enable-continuous-cloudwatch-log" = "true"
      "--enable-glue-datacatalog"          = "true"
    },
    var.default_arguments
  )

  execution_property {
    max_concurrent_runs = 1
  }

  tags = merge(var.tags, {
    Name = var.job_name
  })

  depends_on = [aws_s3_object.script]
}
