aws_region = "us-east-1"

project     = "data-mesh-ecommerce"
domain      = "clientes"
environment = "dev"

# Descomente e ajuste para um nome globalmente único, se preferir:
# bucket_name = "clientes-domain"

glue_database_name        = "clientes_domain"
glue_database_description = "Glue Catalog database for Clientes domain data products."

enable_bucket_versioning = true
force_destroy_bucket     = true

# Lake Formation: PutDataLakeSettings exige admin da conta (não incluído em AWSLakeFormationDataAdmin).
create_data_lake_settings = false

# Usuario que faz deploy e administra o dominio
admin_trusted_principals = ["arn:aws:iam::303238378103:user/usuario-dados"]

# DM-002 - Ingestao customer
# Baixe o dataset completo: scripts/Download-OlistCustomers.ps1
run_customer_ingestion_on_apply = false
