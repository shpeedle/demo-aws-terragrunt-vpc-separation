include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/lambda"
}

dependency "vpc" {
  config_path = "../../../../infrastructure/live/dev/vpc"
  
  mock_outputs = {
    vpc_id             = "vpc-mock"
    private_subnet_ids = ["subnet-mock-1", "subnet-mock-2"]
  }
  mock_outputs_allowed_terraform_commands = ["plan", "validate"]
}

dependency "ecr" {
  config_path = "../ecr"
  
  mock_outputs = {
    repository_url = "123456789012.dkr.ecr.us-east-1.amazonaws.com/dev-lambda-service"
  }
  mock_outputs_allowed_terraform_commands = ["plan", "validate"]
}

dependency "rds" {
  config_path = "../../../../infrastructure/live/dev/rds"
  
  mock_outputs = {
    db_instance_address  = "mock-db-address"
    db_instance_port     = 5432
  }
  mock_outputs_allowed_terraform_commands = ["plan", "validate"]
}

inputs = {
  environment = "dev"
  
  timeout     = 30
  memory_size = 128
  
  # ECR image URI - this should be set after building and pushing the image
  image_uri = "${dependency.ecr.outputs.repository_url}:latest"
  
  environment_variables = {
    LOG_LEVEL   = "debug"
    NODE_ENV    = "development"
    ENVIRONMENT = "dev"
    
    # Database connection variables
    DB_HOST     = dependency.rds.outputs.db_instance_address
    DB_PORT     = dependency.rds.outputs.db_instance_port
    DB_NAME     = "devdb"
    DB_USERNAME = "devuser"
    DB_PASSWORD = "change-me-dev-password"
  }
  
  vpc_config = {
    vpc_id     = dependency.vpc.outputs.vpc_id
    subnet_ids = dependency.vpc.outputs.private_subnet_ids
  }
  
  create_api_gateway = true
}