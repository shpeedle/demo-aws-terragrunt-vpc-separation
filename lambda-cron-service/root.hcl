locals {
  project_name = "lambda-cron-service"
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
    bucket         = "terragrunt-state-10a905d3"
    key            = "${local.project_name}/${path_relative_to_include()}/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terragrunt-locks"
  }
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
}

inputs = {
  aws_region   = "us-east-1"
  project_name = local.project_name
}