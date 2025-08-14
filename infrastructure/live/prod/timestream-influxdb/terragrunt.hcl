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
    vpc_cidr_block       = "10.2.0.0/16"
    private_subnet_ids   = ["subnet-mock1", "subnet-mock2"]
  }
  mock_outputs_allowed_terraform_commands = ["init", "plan", "validate"]
}

inputs = {
  environment = "prod"
  aws_region  = "us-east-1"
  
  # Network configuration
  vpc_id     = dependency.vpc.outputs.vpc_id
  vpc_cidr   = dependency.vpc.outputs.vpc_cidr_block
  subnet_ids = dependency.vpc.outputs.private_subnet_ids
  
  # Instance configuration
  db_instance_type     = "db.influx.large"
  allocated_storage    = 100
  deployment_type      = "WITH_MULTIAZ_STANDBY"
  publicly_accessible = false
  
  # InfluxDB configuration
  admin_username    = "admin"
  organization_name = "prod-org"
  bucket_name       = "prod-metrics"
  
  # Security
  allowed_security_groups = []
  
  # Logging
  enable_logging = true
  log_bucket_name = "prod-timestream-influxdb-logs"
}