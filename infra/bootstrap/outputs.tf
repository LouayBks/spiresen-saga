output "state_bucket_name" {
  description = "S3 bucket to reference in infra/environments/*'s backend \"s3\" block."
  value       = aws_s3_bucket.tfstate.id
}
