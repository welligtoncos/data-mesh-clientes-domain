variable "glue_database_name" {
  description = "Nome do database Glue Catalog."
  type        = string
}

variable "data_product_table_name" {
  description = "Nome da tabela do Data Product publicado."
  type        = string
}

variable "consumer_role_arns_by_domain" {
  description = "Mapa dominio consumidor => ARN do papel (chaves estaticas para for_each)."
  type        = map(string)
  default     = {}
}

variable "consumer_role_arns" {
  description = "Deprecated: use consumer_role_arns_by_domain."
  type        = list(string)
  default     = []
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
