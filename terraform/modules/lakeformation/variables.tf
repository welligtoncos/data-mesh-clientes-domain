variable "bucket_arn" {
  description = "ARN do bucket S3 registrado no Lake Formation."
  type        = string
}

variable "glue_database_name" {
  description = "Nome do database Glue Catalog governado pelo Lake Formation."
  type        = string
}

variable "domain_admin_role_arn" {
  description = "ARN do papel de administrador do domínio."
  type        = string
}

variable "data_product_consumer_role_arn" {
  description = "ARN do papel de consumidor de Data Products."
  type        = string
}

variable "etl_processing_role_arn" {
  description = "ARN do papel de processamento ETL."
  type        = string
}

variable "create_data_lake_settings" {
  description = "Cria configurações do Lake Formation Data Lake. Requer lakeformation:PutDataLakeSettings (admin da conta)."
  type        = bool
  default     = false
}

variable "data_lake_admins" {
  description = "Lista de ARNs de administradores do Lake Formation."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags obrigatórias (usadas em recursos que suportam tagging via LF)."
  type        = map(string)
}
