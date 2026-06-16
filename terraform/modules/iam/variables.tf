variable "domain_name" {
  description = "Nome do domínio de dados (ex: clientes)."
  type        = string
}

variable "environment" {
  description = "Ambiente de deploy (ex: dev, staging, prod)."
  type        = string
}

variable "bucket_arn" {
  description = "ARN do bucket S3 do domínio."
  type        = string
}

variable "bucket_name" {
  description = "Nome do bucket S3 do domínio."
  type        = string
}

variable "glue_database_name" {
  description = "Nome do database Glue Catalog do domínio."
  type        = string
}

variable "glue_database_arn" {
  description = "ARN do database Glue Catalog do domínio."
  type        = string
}

variable "data_products_prefix" {
  description = "Prefixo S3 dos Data Products publicados."
  type        = string
  default     = "data-products/"
}

variable "internal_prefix" {
  description = "Prefixo S3 dos datasets internos do domínio."
  type        = string
  default     = "internal/"
}

variable "customer_data_prefix" {
  description = "Prefixo S3 do Data Product customer (Parquet particionado)."
  type        = string
  default     = "customer/"
}

variable "admin_trusted_principals" {
  description = "Principais IAM autorizados a assumir o papel de administrador do domínio."
  type        = list(string)
  default     = []
}

variable "consumer_trusted_principals" {
  description = "Principais IAM autorizados a assumir o papel de consumidor de Data Products."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags obrigatórias aplicadas a todos os recursos do módulo."
  type        = map(string)
}
