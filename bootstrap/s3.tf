resource "aws_s3_bucket" "s3_backend" {
  bucket = "s3-backend-kubernetes-by-the-hour-x7k2m9"
}

resource "aws_s3_bucket_versioning" "s3_backend" {
  bucket = aws_s3_bucket.s3_backend.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "s3_backend" {
  bucket = aws_s3_bucket.s3_backend.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "s3_backend" {
  bucket                  = aws_s3_bucket.s3_backend.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}