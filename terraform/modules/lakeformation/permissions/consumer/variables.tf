variable "consumer_role_arn" {
  description = "ARN do papel consumidor federado."
  type        = string
}

variable "glue_database_name" {
  description = "Nome do database Glue do dominio produtor."
  type        = string
}

variable "bucket_arn" {
  description = "ARN do bucket S3 registrado no Lake Formation."
  type        = string
}
