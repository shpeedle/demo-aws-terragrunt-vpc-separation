include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/lambda"
}

dependency "vpc" {
  config_path = "../../../../infrastructure/live/prod/vpc"
  
  mock_outputs = {
    vpc_id             = "vpc-mock"
    private_subnet_ids = ["subnet-mock-1", "subnet-mock-2"]
  }
  mock_outputs_allowed_terraform_commands = ["init", "plan", "validate"]
}

dependency "ecr" {
  config_path = "../ecr"
  
  mock_outputs = {
    repository_url = "123456789012.dkr.ecr.us-east-1.amazonaws.com/prod-lambda-cron-service"
  }
  mock_outputs_allowed_terraform_commands = ["init", "plan", "validate"]
}

dependency "rds" {
  config_path = "../../../../infrastructure/live/prod/rds"
  
  mock_outputs = {
    db_instance_address  = "mock-db-address"
    db_instance_port     = 5432
  }
  mock_outputs_allowed_terraform_commands = ["init", "plan", "validate"]
}

inputs = {
  environment = "prod"
  
  timeout     = 60
  memory_size = 512
  
  # ECR image URI - this should be set after building and pushing the image
  image_uri = "${dependency.ecr.outputs.repository_url}:latest"
  
  environment_variables = {
    LOG_LEVEL   = "warn"
    NODE_ENV    = "production"
    ENVIRONMENT = "prod"
    
    # Database connection variables
    DB_HOST     = dependency.rds.outputs.db_instance_address
    DB_PORT     = dependency.rds.outputs.db_instance_port
    DB_NAME     = "proddb"
    DB_USERNAME = "produser"
    DB_PASSWORD = "change-me-prod-password"
  }
  
  vpc_config = {
    vpc_id     = dependency.vpc.outputs.vpc_id
    subnet_ids = dependency.vpc.outputs.private_subnet_ids
  }
}