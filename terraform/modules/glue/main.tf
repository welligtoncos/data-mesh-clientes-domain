resource "aws_glue_catalog_database" "domain" {
  name         = var.database_name
  description  = var.description
  location_uri = var.location_uri

  tags = merge(var.tags, {
    Name = var.database_name
  })
}
