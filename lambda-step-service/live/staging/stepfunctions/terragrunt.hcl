terraform {
  source = "../../../modules/stepfunctions"
}

include "root" {
  path = find_in_parent_folders("root.hcl")
}

dependency "vpc" {
  config_path = "../../../../infrastructure/live/staging/vpc"
  
  mock_outputs = {
    vpc_id              = "vpc-mock"
    private_subnet_ids  = ["subnet-mock-1", "subnet-mock-2"]
    vpc_cidr_block      = "10.1.0.0/16"
  }
  mock_outputs_allowed_terraform_commands = ["init", "plan", "validate"]
}

dependency "ecr" {
  config_path = "../ecr"
  
  mock_outputs = {
    repository_urls = {
      "step-processor" = "123456789012.dkr.ecr.us-east-1.amazonaws.com/staging-step-processor"
      "step-validator" = "123456789012.dkr.ecr.us-east-1.amazonaws.com/staging-step-validator"
      "step-notifier"  = "123456789012.dkr.ecr.us-east-1.amazonaws.com/staging-step-notifier"
    }
    repository_arns = {
      "step-processor" = "arn:aws:ecr:us-east-1:123456789012:repository/staging-step-processor"
      "step-validator" = "arn:aws:ecr:us-east-1:123456789012:repository/staging-step-validator"
      "step-notifier"  = "arn:aws:ecr:us-east-1:123456789012:repository/staging-step-notifier"
    }
  }
  mock_outputs_allowed_terraform_commands = ["init", "plan", "validate"]
}

inputs = {
  environment = "staging"
  
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