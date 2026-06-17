output "api_id" {
  description = "ID da API REST."
  value       = aws_api_gateway_rest_api.this.id
}

output "api_arn" {
  description = "ARN da API REST."
  value       = aws_api_gateway_rest_api.this.arn
}

output "execution_arn" {
  description = "Execution ARN da API REST."
  value       = aws_api_gateway_rest_api.this.execution_arn
}

output "stage_invoke_url" {
  description = "URL base do stage."
  value       = aws_api_gateway_stage.this.invoke_url
}

output "api_key_value" {
  description = "Valor da API Key para consumo."
  value       = aws_api_gateway_api_key.this.value
  sensitive   = true
}

output "por_estado_url" {
  description = "URL do endpoint clientes por estado."
  value       = "${aws_api_gateway_stage.this.invoke_url}/${trim(var.routes["por_estado"].path, "/")}"
}

output "ativos_url" {
  description = "URL do endpoint clientes ativos."
  value       = "${aws_api_gateway_stage.this.invoke_url}/${trim(var.routes["ativos"].path, "/")}"
}
