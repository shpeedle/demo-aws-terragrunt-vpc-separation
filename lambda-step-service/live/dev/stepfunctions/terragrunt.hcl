terraform {
  source = "../../../modules/stepfunctions"
}

include "root" {
  path = find_in_parent_folders("root.hcl")
}

dependency "vpc" {
  config_path = "../../../infrastructure/live/dev/vpc"
}

dependency "ecr" {
  config_path = "../ecr"
}

inputs = {
  environment = "dev"
  
  lambda_functions = {
    step-processor = {
      image_uri = "${dependency.ecr.outputs.repository_urls["step-processor"]}:latest"
      timeout = 60
      memory_size = 512
      environment_variables = {
        LOG_LEVEL = "INFO"
      }
    }
    step-validator = {
      image_uri = "${dependency.ecr.outputs.repository_urls["step-validator"]}:latest"
      timeout = 30
      memory_size = 256
      environment_variables = {
        LOG_LEVEL = "INFO"
      }
    }
    step-notifier = {
      image_uri = "${dependency.ecr.outputs.repository_urls["step-notifier"]}:latest"
      timeout = 30
      memory_size = 256
      environment_variables = {
        LOG_LEVEL = "INFO"
      }
    }
  }
  
  vpc_config = {
    vpc_id = dependency.vpc.outputs.vpc_id
    subnet_ids = dependency.vpc.outputs.private_subnet_ids
  }
}