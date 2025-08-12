variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "lambda_functions" {
  description = "Configuration for Lambda functions used in Step Functions"
  type = map(object({
    image_uri              = string
    timeout               = number
    memory_size           = number
    environment_variables = map(string)
  }))
}

variable "vpc_config" {
  description = "VPC configuration for Lambda functions"
  type = object({
    vpc_id     = string
    subnet_ids = list(string)
  })
  default = null
}