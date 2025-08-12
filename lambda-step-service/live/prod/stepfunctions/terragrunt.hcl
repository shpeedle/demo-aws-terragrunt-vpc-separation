terraform {
  source = "../../../modules/stepfunctions"
}

include "root" {
  path = find_in_parent_folders("root.hcl")
}

dependency "vpc" {
  config_path = "../../../infrastructure/live/prod/vpc"
}

dependency "ecr" {
  config_path = "../ecr"
}

inputs = {
  environment = "prod"
  
  lambda_functions = {
    step-processor = {
      image_uri = "${dependency.ecr.outputs.repository_urls["step-processor"]}:latest"
      timeout = 120
      memory_size = 1024
      environment_variables = {
        LOG_LEVEL = "WARN"
      }
    }
    step-validator = {
      image_uri = "${dependency.ecr.outputs.repository_urls["step-validator"]}:latest"
      timeout = 60
      memory_size = 512
      environment_variables = {
        LOG_LEVEL = "WARN"
      }
    }
    step-notifier = {
      image_uri = "${dependency.ecr.outputs.repository_urls["step-notifier"]}:latest"
      timeout = 60
      memory_size = 512
      environment_variables = {
        LOG_LEVEL = "WARN"
      }
    }
  }
  
  vpc_config = {
    vpc_id = dependency.vpc.outputs.vpc_id
    subnet_ids = dependency.vpc.outputs.private_subnet_ids
  }
}