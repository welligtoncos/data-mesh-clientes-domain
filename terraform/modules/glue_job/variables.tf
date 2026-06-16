variable "job_name" {
  description = "Nome do Glue Job."
  type        = string
}

variable "role_arn" {
  description = "ARN do papel IAM de execucao do job."
  type        = string
}

variable "script_bucket" {
  description = "Bucket S3 onde o script do job esta armazenado."
  type        = string
}

variable "script_key" {
  description = "Chave S3 do script do job."
  type        = string
}

variable "script_source_path" {
  description = "Caminho local do script Python do Glue Job."
  type        = string
}

variable "glue_version" {
  description = "Versao do Glue runtime."
  type        = string
  default     = "4.0"
}

variable "worker_type" {
  description = "Tipo de worker do Glue Job."
  type        = string
  default     = "G.1X"
}

variable "number_of_workers" {
  description = "Numero de workers do Glue Job."
  type        = number
  default     = 2
}

variable "timeout_minutes" {
  description = "Timeout do job em minutos."
  type        = number
  default     = 30
}

variable "default_arguments" {
  description = "Argumentos default do Glue Job."
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Tags obrigatorias."
  type        = map(string)
}
