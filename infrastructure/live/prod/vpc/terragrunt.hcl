include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/vpc"
}

inputs = {
  environment = "prod"
  vpc_cidr    = "10.2.0.0/16"
  
  public_subnets = [
    "10.2.1.0/24",
    "10.2.2.0/24",
    "10.2.3.0/24"
  ]
  
  private_subnets = [
    "10.2.10.0/24",
    "10.2.20.0/24",
    "10.2.30.0/24"
  ]
}