variable "environment" {
  description = "Environment name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
}

variable "timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 30
}

variable "memory_size" {
  description = "Lambda function memory size in MB"
  type        = number
  default     = 128
}

variable "environment_variables" {
  description = "Environment variables for the Lambda function"
  type        = map(string)
  default     = {}
}

variable "vpc_config" {
  description = "VPC configuration for Lambda function"
  type = object({
    vpc_id     = string
    subnet_ids = list(string)
  })
  default = null
}

variable "image_uri" {
  description = "ECR image URI for Lambda function"
  type        = string
}

variable "worker_image_uri" {
  description = "ECR image URI for worker Lambda function (optional, defaults to main image_uri)"
  type        = string
  default     = null
}

variable "worker_timeout" {
  description = "Worker Lambda function timeout in seconds (optional, defaults to main timeout)"
  type        = number
  default     = null
}

variable "worker_memory_size" {
  description = "Worker Lambda function memory size in MB (optional, defaults to main memory_size)"
  type        = number
  default     = null
}

variable "sqs_batch_size" {
  description = "Number of messages to process in a batch from SQS"
  type        = number
  default     = 1
}

variable "influxdb_secret_arn" {
  description = "ARN of the AWS Secrets Manager secret containing InfluxDB credentials"
  type        = string
}