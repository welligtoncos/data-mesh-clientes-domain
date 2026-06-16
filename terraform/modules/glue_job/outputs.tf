output "job_name" {
  description = "Nome do Glue Job."
  value       = aws_glue_job.this.name
}

output "job_arn" {
  description = "ARN do Glue Job."
  value       = aws_glue_job.this.arn
}

output "script_s3_uri" {
  description = "URI S3 do script do job."
  value       = "s3://${var.script_bucket}/${var.script_key}"
}
