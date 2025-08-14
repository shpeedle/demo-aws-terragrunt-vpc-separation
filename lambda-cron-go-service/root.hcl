locals {
  project_name = "lambda-cron-go-service"
  
  # Extract environment from the path (e.g., live/dev/lambda -> dev)
  environment = regex("live/([^/]+)", path_relative_to_include())[0]
  
  # Get AWS account ID and region for dynamic naming
  account_id = get_aws_account_id()
  region     = get_aws_caller_identity_arn() != "" ? "us-east-1" : "us-east-1"  # fallback to us-east-1
}

terraform {}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.89.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Environment   = var.environment
      Project       = "${local.project_name}"
      ManagedBy     = "terragrunt"
    }
  }
}
EOF
}

remote_state {
  backend = "s3"
  config = {
    bucket         = "terragrunt-state-${local.environment}-${local.account_id}-${local.region}"
    key            = "${local.project_name}/${path_relative_to_include()}/terraform.tfstate"
    region         = local.region
    encrypt        = true
    dynamodb_table = "terragrunt-locks-${local.environment}"
  }
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
}

inputs = {
  aws_region   = local.region
  project_name = local.project_name
  environment  = local.environment
}