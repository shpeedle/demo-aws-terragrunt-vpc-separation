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
    repository_url = "123456789012.dkr.ecr.us-east-1.amazonaws.com/prod-lambda-cron-go-service"
    worker_repository_url = "123456789012.dkr.ecr.us-east-1.amazonaws.com/prod-lambda-cron-go-worker"
  }
  mock_outputs_allowed_terraform_commands = ["init", "plan", "validate"]
}

dependency "timestream_influxdb" {
  config_path = "../../../../infrastructure/live/prod/timestream-influxdb"
  
  mock_outputs = {
    influxdb_url            = "https://mock-endpoint:8086"
    admin_username          = "admin"
    organization_name       = "prod-org"
    bucket_name            = "prod-metrics"
    credentials_secret_arn  = "arn:aws:secretsmanager:us-east-1:123456789012:secret:prod-credentials"
  }
  mock_outputs_allowed_terraform_commands = ["init", "plan", "validate"]
}

inputs = {
  environment = "prod"
  
  timeout     = 60
  memory_size = 512
  
  # Worker configuration
  worker_timeout     = 180
  worker_memory_size = 1024
  sqs_batch_size     = 1
  
  # ECR image URIs - these should be set after building and pushing the images
  image_uri        = "${dependency.ecr.outputs.repository_url}:latest"
  worker_image_uri = "${dependency.ecr.outputs.worker_repository_url}:latest"
  
  # InfluxDB secret ARN for IAM permissions - use custom credentials secret with write access
  influxdb_secret_arn = dependency.timestream_influxdb.outputs.credentials_secret_arn
  
  environment_variables = {
    LOG_LEVEL   = "warn"
    ENVIRONMENT = "prod"
    
    # InfluxDB connection variables
    INFLUXDB_URL    = dependency.timestream_influxdb.outputs.influxdb_url
    INFLUXDB_ORG    = dependency.timestream_influxdb.outputs.organization_name
    INFLUXDB_BUCKET = dependency.timestream_influxdb.outputs.bucket_name
    INFLUXDB_SECRET_ARN = dependency.timestream_influxdb.outputs.credentials_secret_arn
  }
  
  vpc_config = {
    vpc_id     = dependency.vpc.outputs.vpc_id
    subnet_ids = dependency.vpc.outputs.private_subnet_ids
  }
}