variable "database_name" {
  description = "Nome do database Glue Catalog do domínio."
  type        = string
}

variable "description" {
  description = "Descrição do catálogo de dados do domínio."
  type        = string
  default     = "Glue Catalog database for domain data products."
}

variable "location_uri" {
  description = "URI S3 raiz associada ao catálogo do domínio."
  type        = string
}

variable "tags" {
  description = "Tags obrigatórias aplicadas a todos os recursos do módulo."
  type        = map(string)
}
