output "bucket_id" {
  description = "ID do bucket S3 do domínio."
  value       = aws_s3_bucket.domain.id
}

output "bucket_arn" {
  description = "ARN do bucket S3 do domínio."
  value       = aws_s3_bucket.domain.arn
}

output "internal_prefix" {
  description = "Prefixo S3 para datasets internos do domínio."
  value       = "internal/"
}

output "data_products_prefix" {
  description = "Prefixo S3 para Data Products publicados."
  value       = "data-products/"
}
