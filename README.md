# AWS Infrastructure with OpenTofu and Terragrunt

This project demonstrates a multi-environment AWS infrastructure setup using OpenTofu (Terraform) and Terragrunt with two separate projects:

1. **Infrastructure Project** - VPC and RDS resources
2. **Lambda Service Project** - Node.js Lambda function with API Gateway

## Project Structure

```
.
├── infrastructure/
│   ├── terragrunt.hcl              # Root configuration
│   ├── modules/
│   │   ├── vpc/                    # VPC module
│   │   └── rds/                    # RDS module
│   └── live/
│       ├── dev/                    # Development environment
│       ├── staging/                # Staging environment
│       └── prod/                   # Production environment
├── lambda-service/
│   ├── terragrunt.hcl              # Root configuration
│   ├── src/                        # Lambda source code
│   ├── modules/lambda/             # Lambda infrastructure module
│   └── live/
│       ├── dev/                    # Development environment
│       ├── staging/                # Staging environment
│       └── prod/                   # Production environment
└── README.md
```

## Prerequisites

1. Install OpenTofu: https://opentofu.org/docs/intro/install/
2. Install Terragrunt: https://terragrunt.gruntwork.io/docs/getting-started/install/
3. Install Docker: https://docs.docker.com/get-docker/
4. Configure AWS credentials (`aws configure`)

## Quick Start

1. **Bootstrap state management:**
   ```bash
   ./scripts/bootstrap.sh
   ```

2. **Initialize Terragrunt in all projects:**
   ```bash
   # Initialize infrastructure (VPC first, then RDS)
   cd infrastructure && terragrunt init --all --queue-include-dir=live/dev/vpc --queue-include-dir=live/staging/vpc --queue-include-dir=live/prod/vpc
   cd infrastructure && terragrunt init --all --queue-include-dir=live/dev/rds --queue-include-dir=live/staging/rds --queue-include-dir=live/prod/rds
   
   # Initialize lambda services
   cd ../lambda-service && terragrunt init --all
   cd ../lambda-cron-service && terragrunt init --all
   cd ../lambda-step-service && terragrunt init --all
   ```

3. **Deploy by environment (recommended):**
   ```bash
   # Deploy Dev environment
   cd infrastructure/live/dev && terragrunt apply --all
   cd ../../lambda-service/live/dev/ecr && terragrunt apply
   cd ../../../ && ./scripts/lambda-build-and-deploy.sh dev
   cd lambda-service/live/dev/lambda && terragrunt apply
   
   # Deploy Staging environment  
   cd ../../../infrastructure/live/staging && terragrunt apply --all
   cd ../../lambda-service/live/staging/ecr && terragrunt apply
   cd ../../../ && ./scripts/lambda-build-and-deploy.sh staging
   cd lambda-service/live/staging/lambda && terragrunt apply
   
   # Deploy Prod environment
   cd ../../../infrastructure/live/prod && terragrunt apply --all
   cd ../../lambda-service/live/prod/ecr && terragrunt apply
   cd ../../../ && ./scripts/lambda-build-and-deploy.sh prod
   cd lambda-service/live/prod/lambda && terragrunt apply
   ```

4. **Or deploy all at once:**
   ```bash
   cd infrastructure && terragrunt apply --all
   cd ../lambda-service && find live -name ecr -type d -exec sh -c 'cd "$1" && terragrunt apply' _ {} \;
   ./scripts/lambda-build-and-deploy.sh dev && ./scripts/lambda-build-and-deploy.sh staging && ./scripts/lambda-build-and-deploy.sh prod
   find live -name lambda -type d -exec sh -c 'cd "$1" && terragrunt apply' _ {} \;
   ```

## Detailed Deployment Guide

For complete step-by-step instructions, environment-specific deployments, and troubleshooting, see **[DEPLOYMENT.md](DEPLOYMENT.md)**.

## Environment Configuration

### Provider Versions
- **AWS Provider**: ~> 5.89.0
- **Random Provider**: ~> 3.4

### VPC CIDR Blocks
- **Dev**: 10.0.0.0/16
- **Staging**: 10.1.0.0/16
- **Prod**: 10.2.0.0/16

### RDS Configuration
- **Dev**: db.t3.micro, 1-day backups
- **Staging**: db.t3.small, 3-day backups
- **Prod**: db.t3.medium, 14-day backups, deletion protection

### Lambda Configuration
- **Dev**: 128MB memory, 30s timeout, debug logging
- **Staging**: 256MB memory, 60s timeout, info logging
- **Prod**: 512MB memory, 60s timeout, warn logging

## Provider Version Upgrade

If you encounter provider version conflicts (e.g., locked to 5.100.0 but need 5.89.x):

```bash
# Upgrade all providers to match new version constraints
./scripts/upgrade-providers.sh
```

## Security Notes

⚠️ **IMPORTANT**: Change default database passwords in the RDS terragrunt.hcl files before deployment!

## Commands

```bash
# Plan changes
terragrunt plan

# Apply changes
terragrunt apply

# Destroy resources
terragrunt destroy

# Deploy all environments at once
terragrunt run-all apply

# Plan all environments
terragrunt run-all plan
```

## API Gateway Endpoints

After deploying the Lambda service, you'll get API Gateway URLs for each environment that you can use to test the Lambda function.