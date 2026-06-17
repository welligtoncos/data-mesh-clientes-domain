variable "function_name" {
  description = "Nome da funcao Lambda."
  type        = string
}

variable "handler" {
  description = "Handler no formato arquivo.funcao."
  type        = string
}

variable "runtime" {
  description = "Runtime Python da Lambda."
  type        = string
  default     = "python3.12"
}

variable "timeout" {
  description = "Timeout em segundos."
  type        = number
  default     = 30
}

variable "memory_size" {
  description = "Memoria em MB."
  type        = number
  default     = 256
}

variable "role_arn" {
  description = "ARN da role de execucao."
  type        = string
}

variable "environment_variables" {
  description = "Variaveis de ambiente."
  type        = map(string)
  default     = {}
}

variable "source_files" {
  description = "Mapa caminho-no-zip => caminho-local do arquivo."
  type        = map(string)
}

variable "log_retention_days" {
  description = "Retencao de logs CloudWatch em dias."
  type        = number
  default     = 14
}

variable "create_log_group" {
  description = "Cria log group explicito. Se false, a Lambda cria no primeiro invoke."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags obrigatorias."
  type        = map(string)
  default     = {}
}
