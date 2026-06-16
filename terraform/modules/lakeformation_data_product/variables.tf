variable "glue_database_name" {
  description = "Nome do database Glue Catalog."
  type        = string
}

variable "data_product_table_name" {
  description = "Nome da tabela do Data Product publicado."
  type        = string
}

variable "data_product_consumer_role_arn" {
  description = "ARN do papel consumidor autorizado."
  type        = string
}

variable "etl_processing_role_arn" {
  description = "ARN do papel ETL do dominio."
  type        = string
}

variable "domain_admin_role_arn" {
  description = "ARN do papel admin do dominio."
  type        = string
}

variable "tags" {
  description = "Tags obrigatorias."
  type        = map(string)
  default     = {}
}
