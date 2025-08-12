# Deployment Guide

This guide walks you through the complete deployment process for the multi-environment AWS infrastructure using OpenTofu and Terragrunt.

## Overview

The deployment consists of:
1. **Bootstrap**: Create state management resources (S3 bucket, DynamoDB table)
2. **Infrastructure**: Deploy VPC and RDS for each environment
3. **Lambda Service**: Deploy ECR repositories, build containers, and deploy Lambda functions

## Deployment Strategy

### Environment Promotion Workflow (Recommended)

Follow standard DevOps practices by deploying environments in sequence:

**Dev → Staging → Prod**

This approach allows you to:
- ✅ Test changes in dev before promoting
- ✅ Validate in staging before production 
- ✅ Catch issues early in the pipeline
- ✅ Maintain production stability
- ✅ Roll back easily if needed

### Terragrunt Commands for Environment-Specific Deployment

```bash
# Navigate to environment directory and use --all
cd infrastructure/live/[env]
terragrunt [command] --all

# Examples:
cd infrastructure/live/dev && terragrunt plan --all        # Plan dev only
cd infrastructure/live/dev && terragrunt apply --all       # Apply dev only
cd infrastructure/live/staging && terragrunt plan --all    # Plan staging only
```

## Prerequisites

Ensure you have installed:
- [OpenTofu](https://opentofu.org/docs/intro/install/)
- [Terragrunt](https://terragrunt.gruntwork.io/docs/getting-started/install/)
- [Docker](https://docs.docker.com/get-docker/)
- [AWS CLI](https://aws.amazon.com/cli/) configured with credentials (`aws configure`)

## Step 1: Bootstrap State Management

Run the bootstrap script to create the S3 bucket and DynamoDB table for state management:

```bash
./scripts/bootstrap.sh
```

This script will:
- Create an S3 bucket with a random suffix (e.g., `terragrunt-state-bbccddce`)
- Create a DynamoDB table (`terragrunt-locks`)
- Automatically update both `infrastructure/root.hcl` and `lambda-service/root.hcl` with the created resource names

## Step 2: Deploy Infrastructure (VPC + RDS)

### Recommended Approach: Environment-by-Environment Deployment

This follows standard DevOps practices: **Dev → Staging → Prod**

#### Deploy Development Environment
```bash
cd infrastructure/live/dev

# Plan dev environment first
terragrunt plan --all

# Apply dev environment
terragrunt apply --all
```

#### Deploy Staging Environment
```bash
cd ../../staging

# Plan staging environment
terragrunt plan --all

# Apply staging environment  
terragrunt apply --all
```

#### Deploy Production Environment
```bash
cd ../prod

# Plan production environment
terragrunt plan --all

# Apply production environment
terragrunt apply --all
```

### Alternative: Deploy All Environments at Once
```bash
cd infrastructure
terragrunt apply --all
```

**Note**: This works because mock outputs are configured for dependencies, allowing Terragrunt to plan before dependencies are applied.

### Manual Component-by-Component (if needed)
```bash
cd infrastructure

# Development environment
cd live/dev/vpc && terragrunt apply
cd ../rds && terragrunt apply

# Staging environment  
cd ../../staging/vpc && terragrunt apply
cd ../rds && terragrunt apply

# Production environment
cd ../../prod/vpc && terragrunt apply
cd ../rds && terragrunt apply
```

## Step 3: Deploy Lambda Service

### Recommended Approach: Environment-by-Environment Deployment

Deploy Lambda service following **Dev → Staging → Prod** promotion workflow:

#### Deploy Development Lambda Service
```bash
cd lambda-service

# Phase 1: Deploy Dev ECR Repository
cd live/dev/ecr
terragrunt plan
terragrunt apply

# Phase 2: Build and Push Dev Container
cd ../../../
./scripts/lambda-build-and-deploy.sh dev

# Phase 3: Deploy Dev Lambda Function
cd live/dev/lambda
terragrunt plan
terragrunt apply

# Test dev environment before proceeding
echo "Test dev environment at: $(terragrunt output api_gateway_url)"
```

#### Deploy Staging Lambda Service
```bash
cd ../../staging

# Phase 1: Deploy Staging ECR Repository
cd ecr
terragrunt plan
terragrunt apply

# Phase 2: Build and Push Staging Container
cd ../../../../
./scripts/lambda-build-and-deploy.sh staging

# Phase 3: Deploy Staging Lambda Function
cd lambda-service/live/staging/lambda
terragrunt plan
terragrunt apply

# Test staging environment before proceeding
echo "Test staging environment at: $(terragrunt output api_gateway_url)"
```

#### Deploy Production Lambda Service
```bash
cd ../../prod

# Phase 1: Deploy Prod ECR Repository
cd ecr
terragrunt plan
terragrunt apply

# Phase 2: Build and Push Prod Container
cd ../../../../
./scripts/lambda-build-and-deploy.sh prod

# Phase 3: Deploy Prod Lambda Function
cd lambda-service/live/prod/lambda
terragrunt plan
terragrunt apply

# Verify production deployment
echo "Production environment at: $(terragrunt output api_gateway_url)"
```

### Alternative: Deploy All Environments at Once

```bash
cd lambda-service

# Deploy all ECR repositories
for env in dev staging prod; do
  cd live/$env/ecr && terragrunt apply && cd ../../..
done

# Build and push all container images
./scripts/lambda-build-and-deploy.sh dev
./scripts/lambda-build-and-deploy.sh staging
./scripts/lambda-build-and-deploy.sh prod

# Deploy all Lambda functions
for env in dev staging prod; do
  cd live/$env/lambda && terragrunt apply && cd ../../..
done
```

## Step 4: Verify Deployment

After deployment, verify the infrastructure:

### Check Infrastructure
```bash
cd infrastructure
terragrunt run-all output
```

### Check Lambda Service
```bash
cd lambda-service
terragrunt run-all output
```

### Test Lambda Functions
The Lambda functions are accessible via API Gateway. After deployment, you'll get API Gateway URLs in the outputs.

Example test:
```bash
# Get the API Gateway URL from terragrunt output
curl https://your-api-gateway-url/dev/
```

## Environment-Specific Deployment

To deploy only a specific environment (e.g., just development):

```bash
# Infrastructure
cd infrastructure
terragrunt run-all apply --terragrunt-include-dir live/dev

# Lambda Service ECR
cd ../lambda-service
cd live/dev/ecr && terragrunt apply

# Build and push container
cd ../../..
./scripts/lambda-build-and-deploy.sh dev

# Deploy Lambda function
cd live/dev/lambda && terragrunt apply
```

## Cleanup

To destroy resources (⚠️ **BE CAREFUL**):

```bash
# Destroy Lambda service
cd lambda-service
terragrunt run-all destroy

# Destroy infrastructure  
cd ../infrastructure
terragrunt run-all destroy

# Destroy bootstrap (optional - will lose state history)
cd ../bootstrap
tofu destroy
```

## Troubleshooting

### Common Issues

1. **State backend errors**: Ensure bootstrap has been run successfully
2. **Docker build errors**: Ensure Docker is running and you're logged into AWS
3. **Permission errors**: Check AWS credentials and permissions
4. **Cross-environment dependencies**: Deploy infrastructure before Lambda service
5. **Variable not declared errors**: Clear Terragrunt cache after module changes: `./clear-cache.sh`
6. **Module source changes**: Always clear cache when updating module source code
7. **Provider version conflicts**: Use `./upgrade-providers.sh` after changing provider versions
8. **Provider lock file conflicts**: Delete `.terraform.lock.hcl` files and run `terragrunt init -upgrade`

### Useful Commands

```bash
# Plan changes without applying
terragrunt plan

# See current state
terragrunt show

# Force refresh state
terragrunt refresh

# View outputs
terragrunt output

# Clear cache and provider locks
./scripts/clear-cache.sh

# Upgrade providers after version changes
./scripts/upgrade-providers.sh

# Initialize with provider upgrade
terragrunt init -upgrade
```

## Architecture Summary

After deployment, you'll have:

- **3 isolated VPCs** (dev: 10.0.0.0/16, staging: 10.1.0.0/16, prod: 10.2.0.0/16)
- **3 RDS PostgreSQL instances** (one per environment)
- **3 ECR repositories** (one per environment)  
- **3 Lambda functions** running containerized Node.js applications
- **3 API Gateway endpoints** for accessing the Lambda functions

All resources are tagged by environment and managed through Terragrunt with centralized state management.