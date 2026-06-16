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

# ---------------------------------------------------------------------------
# DM-002 - Ingestao customer
# ---------------------------------------------------------------------------

variable "customers_csv_path" {
  description = "Caminho local do arquivo customers.csv para upload ao S3."
  type        = string
  default     = "../../../data/raw/customers.csv"
}

variable "customer_glue_script_path" {
  description = "Caminho local do script Glue de ingestao customer."
  type        = string
  default     = "../../../data-products/customer/scripts/customer_ingestion.py"
}

variable "customer_table_name" {
  description = "Nome da tabela Glue Catalog do Data Product customer."
  type        = string
  default     = "customer"
}

variable "customer_data_prefix" {
  description = "Prefixo S3 do Data Product customer (Parquet particionado)."
  type        = string
  default     = "customer/"
}

variable "customer_raw_prefix" {
  description = "Prefixo S3 da area raw do dataset customers."
  type        = string
  default     = "internal/raw/customers/"
}

variable "glue_scripts_prefix" {
  description = "Prefixo S3 dos scripts Glue do dominio."
  type        = string
  default     = "internal/glue-scripts/"
}

variable "glue_job_version" {
  description = "Versao do runtime AWS Glue."
  type        = string
  default     = "4.0"
}

variable "glue_job_worker_type" {
  description = "Tipo de worker do Glue Job de ingestao."
  type        = string
  default     = "G.1X"
}

variable "glue_job_number_of_workers" {
  description = "Numero de workers do Glue Job de ingestao."
  type        = number
  default     = 2
}

variable "glue_job_timeout_minutes" {
  description = "Timeout do Glue Job de ingestao em minutos."
  type        = number
  default     = 30
}

variable "run_customer_ingestion_on_apply" {
  description = "Executa Glue Job e Crawler apos terraform apply."
  type        = bool
  default     = false
}

variable "athena_results_prefix" {
  description = "Prefixo S3 para resultados de consultas Athena."
  type        = string
  default     = "internal/athena-results/"
}

