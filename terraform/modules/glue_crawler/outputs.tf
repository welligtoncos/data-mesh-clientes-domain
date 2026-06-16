output "crawler_name" {
  description = "Nome do Glue Crawler."
  value       = aws_glue_crawler.this.name
}

output "crawler_arn" {
  description = "ARN do Glue Crawler."
  value       = aws_glue_crawler.this.arn
}
