variable "domain_admin_role_arn" {
  description = "ARN do papel administrador do dominio produtor."
  type        = string
}

variable "glue_database_name" {
  description = "Nome do database Glue governado."
  type        = string
}

variable "bucket_arn" {
  description = "ARN do bucket S3 registrado no Lake Formation."
  type        = string
}
