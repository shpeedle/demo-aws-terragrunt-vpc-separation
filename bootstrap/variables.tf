variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "bucket_prefix" {
  description = "Prefix for the S3 bucket name"
  type        = string
  default     = "terragrunt-state"
}

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table for locking"
  type        = string
  default     = "terragrunt-locks"
}