variable "aws_region" {
  description = "Região AWS para deploy da infraestrutura."
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Nome do projeto Data Mesh."
  type        = string
  default     = "data-mesh-ecommerce"
}

variable "domain" {
  description = "Domínio de dados sendo provisionado."
  type        = string
  default     = "clientes"
}

variable "environment" {
  description = "Ambiente de deploy."
  type        = string
  default     = "dev"
}

variable "bucket_name" {
  description = "Nome do bucket S3. Se null, será gerado automaticamente com account ID."
  type        = string
  default     = null
}

variable "glue_database_name" {
  description = "Nome do database Glue Catalog do domínio."
  type        = string
  default     = "clientes_domain"
}

variable "glue_database_description" {
  description = "Descrição do catálogo Glue do domínio Clientes."
  type        = string
  default     = "Glue Catalog database for Clientes domain data products."
}

variable "enable_bucket_versioning" {
  description = "Habilita versionamento no bucket do domínio."
  type        = bool
  default     = true
}

variable "force_destroy_bucket" {
  description = "Permite destruir o bucket com objetos (apenas dev)."
  type        = bool
  default     = true
}

variable "admin_trusted_principals" {
  description = "Principais IAM autorizados a assumir o papel de admin do domínio."
  type        = list(string)
  default     = []
}

variable "consumer_trusted_principals" {
  description = "Principais IAM autorizados a assumir o papel de consumidor."
  type        = list(string)
  default     = []
}

variable "create_data_lake_settings" {
  description = "Cria configurações do Lake Formation Data Lake. Requer lakeformation:PutDataLakeSettings (admin da conta). AWSLakeFormationDataAdmin nega essa ação — mantenha false em contas já configuradas."
  type        = bool
  default     = false
}

variable "data_lake_admins" {
  description = "Administradores do Lake Formation. Se vazio, usa o role de admin do domínio."
  type        = list(string)
  default     = []
}
