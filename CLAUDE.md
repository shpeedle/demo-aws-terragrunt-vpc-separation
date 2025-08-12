# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a multi-environment AWS infrastructure project using OpenTofu (Terraform) and Terragrunt with two separate, interdependent projects:

1. **Infrastructure Project** (`infrastructure/`) - Core network and database resources
2. **Lambda Service Project** (`lambda-service/`) - Application-level Lambda function with dependencies on infrastructure

## Architecture

### Two-Project Structure
- **infrastructure/**: Contains VPC and RDS modules deployed per environment (dev/staging/prod)
- **lambda-service/**: Contains Lambda module with cross-project dependencies on VPC resources

### Cross-Project Dependencies 
The Lambda service depends on infrastructure resources through Terragrunt dependencies:
```hcl
dependency "vpc" {
  config_path = "../../../infrastructure/live/dev/vpc"
}
```
This links each Lambda environment to its corresponding VPC, providing isolated network environments.

### Environment Isolation
Each environment has its own VPC with distinct CIDR blocks:
- Dev: 10.0.0.0/16 
- Staging: 10.1.0.0/16
- Prod: 10.2.0.0/16

## Common Commands

### Infrastructure Deployment (VPC + RDS)
```bash
# Single environment deployment (order matters - VPC before RDS)
cd infrastructure/live/dev/vpc && terragrunt apply
cd ../rds && terragrunt apply

# All environments at once
cd infrastructure && terragrunt run-all apply
```

### Lambda Service Deployment (Container-based)
```bash
# Container deployment requires specific order:
# 1. Deploy ECR repositories
cd lambda-service/live/dev/ecr && terragrunt apply

# 2. Build and push container image
cd ../../.. && ./scripts/lambda-build-and-deploy.sh dev

# 3. Deploy Lambda function
cd live/dev/lambda && terragrunt apply

# For all environments:
cd lambda-service && terragrunt run-all apply --terragrunt-include-dir live/*/ecr
./scripts/lambda-build-and-deploy.sh dev && ./scripts/lambda-build-and-deploy.sh staging && ./scripts/lambda-build-and-deploy.sh prod
terragrunt run-all apply --terragrunt-include-dir live/*/lambda
```

### Planning and Validation
```bash
# Plan changes for single component
terragrunt plan

# Plan all environments/components
terragrunt run-all plan

# Validate configuration
terragrunt validate
```

### State Management
```bash
# Show current state
terragrunt show

# Import existing resource
terragrunt import <resource_type>.<name> <resource_id>

# Destroy resources
terragrunt destroy
```

## Configuration Requirements

### Prerequisites Setup
Before deployment, update both root `terragrunt.hcl` files:
- Set `bucket` to your S3 state storage bucket name
- Set `dynamodb_table` to your state locking table name  
- Verify AWS region matches your target region

### Security Configuration
Database passwords in RDS terragrunt files use placeholder values and must be changed before production deployment.

## Module Structure

### Infrastructure Modules
- **VPC Module**: Creates isolated networks with public/private subnets, NAT gateways, route tables
- **RDS Module**: PostgreSQL instances with environment-specific configurations and security groups

### Lambda Module  
- Packages Node.js source code from `lambda-service/src/`
- Creates IAM roles, security groups, and API Gateway
- Supports both VPC and non-VPC deployment modes
- Includes cross-environment resource tagging

## Container Deployment Workflow
The Lambda service uses Docker containers stored in ECR:
1. **ECR Repository**: Created per environment to store container images
2. **Docker Build**: `scripts/lambda-build-and-deploy.sh` script builds from `lambda-service/src/Dockerfile`
3. **Container Push**: Images pushed to environment-specific ECR repositories
4. **Lambda Deployment**: Uses `image_uri` from ECR dependency to deploy containerized function

## Dependency Chain
1. Infrastructure VPC must be deployed before RDS (within same environment)
2. Infrastructure must be deployed before Lambda service (cross-project)
3. ECR repository must exist before building/pushing containers
4. Container image must exist in ECR before Lambda deployment
5. Terragrunt handles dependency resolution within each project, but cross-project dependencies require manual ordering