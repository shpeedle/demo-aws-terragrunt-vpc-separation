#!/bin/bash

# Simple cleanup script for bootstrap resources
# Removes S3 bucket and DynamoDB table for specified environment
set -e

# Check arguments
if [ $# -ne 1 ]; then
    echo "Usage: $0 <environment>"
    echo "Example: $0 dev"
    exit 1
fi

ENVIRONMENT=$1

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    echo "❌ Error: Environment must be one of: dev, staging, prod"
    exit 1
fi

echo "🧹 Cleaning up Terragrunt state resources for $ENVIRONMENT..."

# Check AWS CLI
if ! aws sts get-caller-identity >/dev/null 2>&1; then
    echo "❌ Error: AWS CLI not configured"
    exit 1
fi

# Get AWS info
REGION=$(aws configure get region || echo "us-east-1")
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Resource names (must match bootstrap script)
BUCKET_NAME="terragrunt-state-${ENVIRONMENT}-${ACCOUNT_ID}-${REGION}"
TABLE_NAME="terragrunt-locks-${ENVIRONMENT}"

echo "Will delete:"
echo "  S3 Bucket: $BUCKET_NAME (and all contents)"
echo "  DynamoDB Table: $TABLE_NAME"
echo ""
echo "⚠️  WARNING: This will permanently delete all Terraform state files!"
echo ""

# Ask for confirmation
read -p "Are you sure you want to delete these resources? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Cleanup cancelled"
    exit 1
fi

# Delete S3 bucket
echo "📦 Deleting S3 bucket..."
if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
    echo "  Emptying bucket..."
    # Delete all object versions and delete markers
    aws s3api list-object-versions --bucket "$BUCKET_NAME" --output text --query 'Versions[].[Key,VersionId]' | \
    while read key version_id; do
        if [ ! -z "$key" ] && [ ! -z "$version_id" ]; then
            aws s3api delete-object --bucket "$BUCKET_NAME" --key "$key" --version-id "$version_id" >/dev/null 2>&1
        fi
    done
    
    aws s3api list-object-versions --bucket "$BUCKET_NAME" --output text --query 'DeleteMarkers[].[Key,VersionId]' | \
    while read key version_id; do
        if [ ! -z "$key" ] && [ ! -z "$version_id" ]; then
            aws s3api delete-object --bucket "$BUCKET_NAME" --key "$key" --version-id "$version_id" >/dev/null 2>&1
        fi
    done
    
    echo "  Deleting bucket..."
    aws s3api delete-bucket --bucket "$BUCKET_NAME"
    echo "  Deleted S3 bucket"
else
    echo "  Bucket does not exist"
fi

# Delete DynamoDB table
echo "🔒 Deleting DynamoDB table..."
if aws dynamodb describe-table --table-name "$TABLE_NAME" >/dev/null 2>&1; then
    aws dynamodb delete-table --table-name "$TABLE_NAME" >/dev/null
    echo "  Waiting for table deletion..."
    aws dynamodb wait table-not-exists --table-name "$TABLE_NAME"
    echo "  Deleted DynamoDB table"
else
    echo "  Table does not exist"
fi

echo ""
echo "✅ Cleanup completed for $ENVIRONMENT"