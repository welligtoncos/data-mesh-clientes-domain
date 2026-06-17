output "function_name" {
  description = "Nome da funcao Lambda."
  value       = aws_lambda_function.this.function_name
}

output "function_arn" {
  description = "ARN da funcao Lambda."
  value       = aws_lambda_function.this.arn
}

output "invoke_arn" {
  description = "ARN de invocacao da Lambda."
  value       = aws_lambda_function.this.invoke_arn
}

output "log_group_name" {
  description = "Nome do log group CloudWatch."
  value       = var.create_log_group ? aws_cloudwatch_log_group.lambda[0].name : "/aws/lambda/${var.function_name}"
}
