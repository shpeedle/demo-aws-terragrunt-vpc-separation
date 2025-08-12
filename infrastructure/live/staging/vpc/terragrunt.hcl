include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/vpc"
}

inputs = {
  environment = "staging"
  vpc_cidr    = "10.1.0.0/16"
  
  public_subnets = [
    "10.1.1.0/24",
    "10.1.2.0/24"
  ]
  
  private_subnets = [
    "10.1.10.0/24",
    "10.1.20.0/24"
  ]
}