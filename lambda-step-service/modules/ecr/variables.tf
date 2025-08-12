variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "lambda_function_names" {
  description = "List of Lambda function names for ECR repositories"
  type        = list(string)
  default     = ["step-processor", "step-validator", "step-notifier"]
}