output "s3_bucket_name" {
  description = "Name of the S3 bucket for Terragrunt state"
  value       = aws_s3_bucket.terragrunt_state.id
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table for Terragrunt locking"
  value       = aws_dynamodb_table.terragrunt_locks.name
}

output "aws_region" {
  description = "AWS region used"
  value       = var.aws_region
}