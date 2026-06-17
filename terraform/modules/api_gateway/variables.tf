variable "api_name" {
  description = "Nome da API REST."
  type        = string
}

variable "stage_name" {
  description = "Nome do stage (ex: v1)."
  type        = string
  default     = "v1"
}

variable "routes" {
  description = "Rotas GET com integracao Lambda proxy."
  type = map(object({
    path              = string
    lambda_invoke_arn = string
  }))
}

variable "api_key_required" {
  description = "Exige API Key nas requisicoes."
  type        = bool
  default     = true
}

variable "usage_plan_burst_limit" {
  description = "Burst limit do usage plan."
  type        = number
  default     = 100
}

variable "usage_plan_rate_limit" {
  description = "Rate limit do usage plan (req/s)."
  type        = number
  default     = 50
}

variable "tags" {
  description = "Tags obrigatorias."
  type        = map(string)
  default     = {}
}
