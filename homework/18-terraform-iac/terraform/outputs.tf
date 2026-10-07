output "bucket_name" {
  description = "Generated bucket name"
  value       = aws_s3_bucket.homework.bucket
}

output "bucket_arn" {
  description = "Bucket ARN"
  value       = aws_s3_bucket.homework.arn
}

output "bucket_region" {
  description = "Region the bucket lives in"
  value       = aws_s3_bucket.homework.region
}

output "versioning_status" {
  value = aws_s3_bucket_versioning.homework.versioning_configuration[0].status
}
