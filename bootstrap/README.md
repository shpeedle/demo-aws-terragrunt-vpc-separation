# Bootstrap Infrastructure

This directory contains the bootstrap Terraform configuration to create the S3 bucket and DynamoDB table required for Terragrunt remote state management.

## Usage

1. **Initialize and apply the bootstrap configuration:**
   ```bash
   cd bootstrap
   terraform init
   terraform plan
   terraform apply
   ```

2. **Note the output values:**
   The apply command will output the S3 bucket name and DynamoDB table name.

3. **Update the root configuration files:**
   Copy the output values to both `infrastructure/root.hcl` and `lambda-service/root.hcl`:
   ```hcl
   remote_state {
     backend = "s3"
     config = {
       bucket         = "terragrunt-state-abcd1234"  # Use the actual bucket name from output
       region         = "us-east-1"
       encrypt        = true
       dynamodb_table = "terragrunt-locks"
     }
   }
   ```

4. **Proceed with main infrastructure deployment**

## Important Notes

- This bootstrap configuration stores its own state locally in `terraform.tfstate`
- Keep this file safe or consider moving it to a separate state backend after initial setup
- The S3 bucket name includes a random suffix to ensure global uniqueness