include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/rds"
}

dependency "vpc" {
  config_path = "../vpc"
  
  mock_outputs = {
    vpc_id                = "vpc-mock"
    private_subnet_ids    = ["subnet-mock-1", "subnet-mock-2"]
    vpc_cidr_block        = "10.0.0.0/16"
  }
  mock_outputs_allowed_terraform_commands = ["init", "plan", "validate"]
}

inputs = {
  environment = "dev"
  
  vpc_id           = dependency.vpc.outputs.vpc_id
  subnet_ids       = dependency.vpc.outputs.private_subnet_ids
  vpc_cidr_block   = dependency.vpc.outputs.vpc_cidr_block
  
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  max_allocated_storage  = 50
  
  database_name     = "devdb"
  database_username = "devuser"
  database_password = "change-me-dev-password"
  
  backup_retention_period = 1
}