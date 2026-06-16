output "role_arn" {
  description = "ARN do papel IAM do consumidor federado."
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "Nome do papel IAM do consumidor federado."
  value       = aws_iam_role.this.name
}
