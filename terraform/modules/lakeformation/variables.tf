variable "bucket_arn" {
  description = "ARN do bucket S3 registrado no Lake Formation."
  type        = string
}

variable "glue_database_name" {
  description = "Nome do database Glue Catalog governado pelo Lake Formation."
  type        = string
}

variable "domain_admin_role_arn" {
  description = "ARN do papel de administrador do dominio."
  type        = string
}

variable "etl_processing_role_arn" {
  description = "ARN do papel de processamento ETL."
  type        = string
}

variable "create_data_lake_settings" {
  description = "Cria configuracoes do Lake Formation Data Lake."
  type        = bool
  default     = false
}

variable "data_lake_admins" {
  description = "Lista de ARNs de administradores do Lake Formation."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags obrigatorias."
  type        = map(string)
}
