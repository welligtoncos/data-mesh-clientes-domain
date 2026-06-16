variable "database_name" {
  description = "Nome do database Glue Catalog."
  type        = string
}

variable "table_name" {
  description = "Nome da tabela do Data Product."
  type        = string
}

variable "table_location" {
  description = "URI S3 da tabela."
  type        = string
}

variable "columns" {
  description = "Colunas do schema do Data Product."
  type = list(object({
    name = string
    type = string
  }))
}

variable "table_parameters" {
  description = "Parametros de metadados da tabela."
  type        = map(string)
  default     = {}
}

variable "athena_workgroup_name" {
  description = "Nome do workgroup Athena para named queries."
  type        = string
}

variable "tags" {
  description = "Tags obrigatorias."
  type        = map(string)
}
