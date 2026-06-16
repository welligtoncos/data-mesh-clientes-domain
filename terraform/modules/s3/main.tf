resource "aws_s3_bucket" "domain" {
  bucket        = var.bucket_name
  force_destroy = var.force_destroy

  tags = merge(var.tags, {
    Name = var.bucket_name
  })
}

resource "aws_s3_bucket_versioning" "domain" {
  bucket = aws_s3_bucket.domain.id

  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Disabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "domain" {
  bucket = aws_s3_bucket.domain.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "domain" {
  bucket = aws_s3_bucket.domain.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_object" "internal_prefix" {
  bucket  = aws_s3_bucket.domain.id
  key     = "internal/"
  content = ""
}

resource "aws_s3_object" "data_products_prefix" {
  bucket  = aws_s3_bucket.domain.id
  key     = "data-products/"
  content = ""
}
