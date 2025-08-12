# Infrastructure Separation Guide

This guide explains how to transition from the current monorepo structure to separate Git repositories for infrastructure and lambda services.

## Current Structure (Monorepo)

```
demo-aws-terragrunt-arch/
├── infrastructure/          # VPC + RDS resources
├── lambda-service/          # API Lambda with cross-project dependencies
├── lambda-cron-service/     # Cron Lambda with cross-project dependencies
└── scripts/                 # Deployment scripts
```

## Target Structure (Separate Repos)

```
aws-infrastructure/          # New standalone infrastructure repo
├── modules/
├── live/
└── scripts/

aws-lambda-services/         # Lambda services repo (standalone)
├── lambda-service/
├── lambda-cron-service/
└── scripts/
```

## Step-by-Step Transition Process

### Phase 1: Deploy Infrastructure and Capture Values

1. **Deploy all infrastructure first:**
   ```bash
   cd infrastructure
   terragrunt run-all apply
   ```

2. **Capture infrastructure outputs for each environment:**
   ```bash
   # Dev environment
   cd infrastructure/live/dev/vpc
   echo "VPC ID: $(terragrunt output vpc_id)"
   echo "Private Subnet IDs: $(terragrunt output private_subnet_ids)"
   
   cd ../rds
   echo "RDS Address: $(terragrunt output db_instance_address)"
   echo "RDS Port: $(terragrunt output db_instance_port)"
   
   # Repeat for staging and prod...
   ```

3. **Document all values in a transition spreadsheet:**
   ```
   Environment | VPC ID                | Subnet 1              | Subnet 2              | RDS Address                                              | RDS Port
   dev         | vpc-0123456789abcdef0 | subnet-0123456789abcdef0 | subnet-0123456789abcdef1 | dev-rds-instance.cluster-abc123.us-east-1.rds.amazonaws.com | 5432
   staging     | vpc-0234567890bcdef01 | subnet-0234567890bcdef01 | subnet-0234567890bcdef02 | staging-rds-instance.cluster-def456.us-east-1.rds.amazonaws.com | 5432
   prod        | vpc-0345678901cdef012 | subnet-0345678901cdef012 | subnet-0345678901cdef013 | prod-rds-instance.cluster-ghi789.us-east-1.rds.amazonaws.com | 5432
   ```

### Phase 2: Create Standalone Lambda Configurations

1. **Create hardcoded versions of lambda terragrunt files:**
   
   Replace dependency blocks like:
   ```hcl
   dependency "vpc" {
     config_path = "../../../../infrastructure/live/dev/vpc"
     mock_outputs = {
       vpc_id = "vpc-mock"
       private_subnet_ids = ["subnet-mock-1", "subnet-mock-2"]
     }
   }
   ```
   
   With hardcoded values:
   ```hcl
   # No dependency block needed - values are hardcoded below
   ```

2. **Replace dynamic references with static values:**
   
   **Before (dynamic):**
   ```hcl
   vpc_config = {
     vpc_id     = dependency.vpc.outputs.vpc_id
     subnet_ids = dependency.vpc.outputs.private_subnet_ids
   }
   
   environment_variables = {
     DB_HOST = dependency.rds.outputs.db_instance_address
     DB_PORT = dependency.rds.outputs.db_instance_port
   }
   ```
   
   **After (hardcoded):**
   ```hcl
   vpc_config = {
     vpc_id     = "vpc-0123456789abcdef0"  # Dev VPC ID from infrastructure
     subnet_ids = [
       "subnet-0123456789abcdef0",         # Dev Private Subnet 1
       "subnet-0123456789abcdef1"          # Dev Private Subnet 2
     ]
   }
   
   environment_variables = {
     DB_HOST = "dev-rds-instance.cluster-abc123.us-east-1.rds.amazonaws.com"
     DB_PORT = "5432"
   }
   ```

### Phase 3: Test Standalone Configuration

1. **Test lambda services with hardcoded values:**
   ```bash
   # Test dev environment
   cd lambda-service/live/dev/lambda
   cp terragrunt.hcl terragrunt.hcl.backup
   cp terragrunt.hcl.standalone terragrunt.hcl
   terragrunt plan
   
   # Test staging environment
   cd ../../staging/lambda
   cp terragrunt.hcl terragrunt.hcl.backup
   cp terragrunt.hcl.standalone terragrunt.hcl
   terragrunt plan
   
   # Test prod environment
   cd ../../prod/lambda
   cp terragrunt.hcl terragrunt.hcl.backup
   cp terragrunt.hcl.standalone terragrunt.hcl
   terragrunt plan
   ```

2. **Verify no infrastructure dependencies:**
   ```bash
   cd lambda-service
   terragrunt run-all plan
   # Should work without infrastructure/ directory present
   ```

### Phase 4: Create Separate Repositories

1. **Create new infrastructure repository:**
   ```bash
   mkdir ../aws-infrastructure
   cd ../aws-infrastructure
   git init
   
   # Copy infrastructure content
   cp -r ../demo-aws-terragrunt-arch/infrastructure/* .
   cp ../demo-aws-terragrunt-arch/scripts/bootstrap.sh scripts/
   cp ../demo-aws-terragrunt-arch/bootstrap/ .
   
   # Update root.hcl key path (remove "infrastructure/" prefix)
   sed -i 's|key.*=.*"infrastructure/|key = "|g' root.hcl
   
   git add .
   git commit -m "Initial infrastructure repository"
   ```

2. **Create new lambda services repository:**
   ```bash
   mkdir ../aws-lambda-services
   cd ../aws-lambda-services
   git init
   
   # Copy lambda service content
   cp -r ../demo-aws-terragrunt-arch/lambda-service .
   cp -r ../demo-aws-terragrunt-arch/lambda-cron-service .
   cp -r ../demo-aws-terragrunt-arch/scripts .
   
   # Use the standalone terragrunt files
   find . -name "terragrunt.hcl.standalone" -exec sh -c 'mv "$1" "${1%.standalone}"' _ {} \;
   
   git add .
   git commit -m "Initial lambda services repository"
   ```

### Phase 5: Update Build Scripts and Documentation

1. **Update build scripts for new structure:**
   ```bash
   # In aws-lambda-services repo
   # Update scripts to work from new directory structure
   ```

2. **Update Makefile:**
   ```bash
   # Remove infrastructure targets from lambda repo
   # Keep only lambda-specific targets
   ```

3. **Create separate documentation:**
   - `aws-infrastructure/README.md` - Infrastructure deployment guide
   - `aws-lambda-services/README.md` - Lambda services deployment guide

## Benefits of Separation

✅ **Independent Development**: Infrastructure and applications can evolve separately  
✅ **Team Boundaries**: Different teams can own infrastructure vs applications  
✅ **Deployment Independence**: Deploy infrastructure changes without affecting apps  
✅ **Security**: Separate access controls for infrastructure vs application code  
✅ **CI/CD Simplicity**: Simpler build pipelines focused on specific concerns  

## Considerations

⚠️ **Manual Coordination**: Infrastructure changes must be manually communicated to app teams  
⚠️ **Value Management**: Infrastructure output values must be manually maintained in app configs  
⚠️ **Testing Complexity**: Integration testing across repos requires coordination  

## Alternative: Remote State References

Instead of hardcoding values, you could use Terragrunt's remote state feature:

```hcl
# In lambda terragrunt.hcl
terraform {
  source = "../../../modules/lambda"
}

# Reference remote state from infrastructure repo
remote_state {
  backend = "s3"
  config = {
    bucket = "your-infrastructure-state-bucket"
    key    = "infrastructure/live/dev/vpc/terraform.tfstate"
    region = "us-east-1"
  }
}

inputs = {
  vpc_config = {
    vpc_id     = remote_state.vpc.outputs.vpc_id
    subnet_ids = remote_state.vpc.outputs.private_subnet_ids
  }
}
```

This maintains dynamic references but requires shared state bucket access between repositories.