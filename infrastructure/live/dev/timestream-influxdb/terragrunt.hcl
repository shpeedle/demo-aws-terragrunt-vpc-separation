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
    vpc_cidr_block       = "10.0.0.0/16"
    private_subnet_ids   = ["subnet-mock1", "subnet-mock2"]
    public_subnet_ids    = ["subnet-mockpublic1", "subnet-mockpublic2"]
  }
  mock_outputs_allowed_terraform_commands = ["init", "plan", "validate"]
}

inputs = {
  environment = "dev"
  aws_region  = "us-east-1"
  
  # Network configuration - use public subnets for publicly accessible instance
  vpc_id     = dependency.vpc.outputs.vpc_id
  vpc_cidr   = dependency.vpc.outputs.vpc_cidr_block
  subnet_ids = dependency.vpc.outputs.public_subnet_ids
  
  # Instance configuration
  db_instance_type     = "db.influx.medium"
  allocated_storage    = 20
  deployment_type      = "SINGLE_AZ"
  publicly_accessible = true
  
  # InfluxDB configuration
  admin_username    = "admin"
  organization_name = "dev-org"
  bucket_name       = "dev-metrics"
  
  # Security
  allowed_security_groups = []
  
  # Logging
  enable_logging = false
}