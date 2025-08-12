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
    private_subnet_ids    = ["subnet-mock-1", "subnet-mock-2", "subnet-mock-3"]
    vpc_cidr_block        = "10.2.0.0/16"
  }
  mock_outputs_allowed_terraform_commands = ["plan", "validate"]
}

inputs = {
  environment = "prod"
  
  vpc_id           = dependency("vpc").outputs.vpc_id
  subnet_ids       = dependency("vpc").outputs.private_subnet_ids
  vpc_cidr_block   = dependency("vpc").outputs.vpc_cidr_block
  
  instance_class         = "db.t3.medium"
  allocated_storage      = 100
  max_allocated_storage  = 500
  
  database_name     = "proddb"
  database_username = "produser"
  database_password = "change-me-secure-prod-password"
  
  backup_retention_period = 14
}