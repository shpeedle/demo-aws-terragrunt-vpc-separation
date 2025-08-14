include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/timestream-influxdb"
}

dependency "vpc" {
  config_path = "../vpc"
  
  mock_outputs = {
    vpc_id               = "vpc-mock"
    vpc_cidr_block       = "10.1.0.0/16"
    private_subnet_ids   = ["subnet-mock1", "subnet-mock2"]
  }
  mock_outputs_allowed_terraform_commands = ["init", "plan", "validate"]
}

inputs = {
  environment = "staging"
  aws_region  = "us-east-1"
  
  # Network configuration
  vpc_id     = dependency.vpc.outputs.vpc_id
  vpc_cidr   = dependency.vpc.outputs.vpc_cidr_block
  subnet_ids = dependency.vpc.outputs.private_subnet_ids
  
  # Instance configuration
  db_instance_type     = "db.influx.medium"
  allocated_storage    = 50
  deployment_type      = "SINGLE_AZ"
  publicly_accessible = false
  
  # InfluxDB configuration
  admin_username    = "admin"
  organization_name = "staging-org"
  bucket_name       = "staging-metrics"
  
  # Security
  allowed_security_groups = []
  
  # Logging
  enable_logging = false
}