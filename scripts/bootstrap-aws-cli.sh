#!/bin/bash

# Simple bootstrap script using AWS CLI
# Creates S3 bucket and DynamoDB table for Terragrunt state management
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

echo "🚀 Creating Terragrunt state resources for $ENVIRONMENT..."

# Check AWS CLI
if ! aws sts get-caller-identity >/dev/null 2>&1; then
    echo "❌ Error: AWS CLI not configured"
    exit 1
fi

# Get AWS info
REGION=$(aws configure get region || echo "us-east-1")
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Resource names
BUCKET_NAME="terragrunt-state-${ENVIRONMENT}-${ACCOUNT_ID}-${REGION}"
TABLE_NAME="terragrunt-locks-${ENVIRONMENT}"

echo "Creating:"
echo "  S3 Bucket: $BUCKET_NAME"
echo "  DynamoDB Table: $TABLE_NAME"
echo ""

# Create S3 bucket
echo "📦 Creating S3 bucket..."
if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
    echo "  Bucket already exists"
else
    if [ "$REGION" = "us-east-1" ]; then
        aws s3api create-bucket --bucket "$BUCKET_NAME"
    else
        aws s3api create-bucket --bucket "$BUCKET_NAME" --create-bucket-configuration LocationConstraint="$REGION"
    fi
    
    # Enable versioning and encryption
    aws s3api put-bucket-versioning --bucket "$BUCKET_NAME" --versioning-configuration Status=Enabled
    aws s3api put-bucket-encryption --bucket "$BUCKET_NAME" --server-side-encryption-configuration '{
        "Rules": [{
            "ApplyServerSideEncryptionByDefault": {
                "SSEAlgorithm": "AES256"
            }
        }]
    }'
    aws s3api put-public-access-block --bucket "$BUCKET_NAME" --public-access-block-configuration \
        BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
    
    echo "  Created and configured bucket"
fi

# Create DynamoDB table
echo "🔒 Creating DynamoDB table..."
if aws dynamodb describe-table --table-name "$TABLE_NAME" >/dev/null 2>&1; then
    echo "  Table already exists"
else
    aws dynamodb create-table \
        --table-name "$TABLE_NAME" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5
    
    aws dynamodb wait table-exists --table-name "$TABLE_NAME"
    echo "  Created table"
fi

echo ""
echo "✅ Resources created for $ENVIRONMENT"
echo ""
echo "Update your root.hcl files with:"
echo "  bucket = \"$BUCKET_NAME\""
echo "  dynamodb_table = \"$TABLE_NAME\""
echo "  region = \"$REGION\""