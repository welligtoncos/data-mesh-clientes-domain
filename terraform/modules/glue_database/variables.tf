variable "database_name" {
  description = "Nome do database Glue Catalog do dominio."
  type        = string
}

variable "description" {
  description = "Descricao do catalogo de dados do dominio."
  type        = string
  default     = "Glue Catalog database for domain data products."
}

variable "location_uri" {
  description = "URI S3 raiz associada ao catalogo do dominio."
  type        = string
}

variable "tags" {
  description = "Tags obrigatorias aplicadas a todos os recursos do modulo."
  type        = map(string)
}
