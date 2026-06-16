variable "role_name" {
  description = "Nome do papel IAM do consumidor federado."
  type        = string
}

variable "consumer_domain" {
  description = "Dominio consumidor (marketing, analytics, datascience, crm)."
  type        = string
}

variable "trusted_principals" {
  description = "Principais IAM autorizados a assumir o papel."
  type        = list(string)
  default     = []
}

variable "bucket_arn" {
  description = "ARN do bucket S3 do dominio produtor."
  type        = string
}

variable "glue_database_arn" {
  description = "ARN do database Glue do dominio produtor."
  type        = string
}

variable "glue_database_name" {
  description = "Nome do database Glue do dominio produtor."
  type        = string
}

variable "allowed_table_names" {
  description = "Tabelas Glue autorizadas para leitura."
  type        = list(string)
}

variable "allowed_s3_prefixes" {
  description = "Prefixos S3 dos Data Products autorizados."
  type        = list(string)
}

variable "tags" {
  description = "Tags obrigatorias."
  type        = map(string)
  default     = {}
}
