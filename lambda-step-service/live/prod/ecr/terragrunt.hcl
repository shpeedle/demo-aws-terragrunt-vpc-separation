terraform {
  source = "../../../modules/ecr"
}

include "root" {
  path = find_in_parent_folders("root.hcl")
}

inputs = {
  environment = "prod"
  lambda_function_names = ["step-processor", "step-validator", "step-notifier"]
}