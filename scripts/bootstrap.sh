#!/bin/bash

# Bootstrap script for Terragrunt state management infrastructure
set -e

echo "🚀 Bootstrapping Terragrunt state management infrastructure..."

# Check if AWS CLI is configured
if ! aws sts get-caller-identity >/dev/null 2>&1; then
    echo "❌ Error: AWS CLI is not configured or credentials are invalid"
    echo "Please run 'aws configure' first"
    exit 1
fi

# Get current AWS region
REGION=$(aws configure get region || echo "us-east-1")
echo "Using AWS region: $REGION"

# Change to bootstrap directory
cd bootstrap

# Initialize tofu
echo "📦 Initializing tofu..."
tofu init

# Plan the deployment
echo "📋 Planning bootstrap infrastructure..."
tofu plan -var="aws_region=$REGION"

# Ask for confirmation
echo ""
read -p "Do you want to create the bootstrap infrastructure? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Bootstrap cancelled"
    exit 1
fi

# Apply the configuration
echo "🔨 Creating bootstrap infrastructure..."
tofu apply -auto-approve -var="aws_region=$REGION"

# Get the outputs
echo "📝 Getting outputs..."
BUCKET_NAME=$(tofu output -raw s3_bucket_name)
TABLE_NAME=$(tofu output -raw dynamodb_table_name)

echo ""
echo "✅ Bootstrap infrastructure created successfully!"
echo "📦 S3 Bucket: $BUCKET_NAME"
echo "🔒 DynamoDB Table: $TABLE_NAME"
echo ""

echo "✅ Configuration files are already configured!"
echo ""
echo "🎉 Bootstrap complete! You can now run terragrunt commands."
echo ""
echo "Next steps:"
echo "1. Deploy infrastructure: cd infrastructure && terragrunt run-all apply"
echo "2. Deploy ECR repositories: Use 'make lambda-ecr-all' and 'make cron-ecr-all'"
echo "3. Build and push containers: Use 'make lambda-build-all' and 'make cron-build-all'"
echo "4. Deploy lambda functions: Use 'make lambda-deploy-all' and 'make cron-deploy-all'"
echo "5. Or use 'make deploy-all' to deploy everything at once"