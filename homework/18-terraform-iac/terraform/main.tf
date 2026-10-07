resource "aws_s3_bucket" "homework" {
  # bucket_prefix instead of bucket: S3 names are global, so a hard-coded
  # name collides with anyone else who ran the same lab.
  bucket_prefix = "${var.project_name}-${var.environment}-"
  force_destroy = true

  tags = {
    Name        = "${var.project_name}-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_versioning" "homework" {
  bucket = aws_s3_bucket.homework.id

  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_object" "readme" {
  bucket       = aws_s3_bucket.homework.id
  key          = "hello.txt"
  content      = "Hello from Terraform - ${var.environment}\n"
  content_type = "text/plain"
}
