variable "crawler_name" {
  description = "Nome do Glue Crawler."
  type        = string
}

variable "database_name" {
  description = "Nome do database Glue Catalog alvo."
  type        = string
}

variable "role_arn" {
  description = "ARN do papel IAM do crawler."
  type        = string
}

variable "s3_target_path" {
  description = "Caminho S3 a ser catalogado pelo crawler."
  type        = string
}

variable "table_prefix" {
  description = "Prefixo opcional para nomes de tabelas descobertas."
  type        = string
  default     = ""
}

variable "schedule" {
  description = "Expressao cron do crawler. Null = execucao manual."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags obrigatorias."
  type        = map(string)
}
