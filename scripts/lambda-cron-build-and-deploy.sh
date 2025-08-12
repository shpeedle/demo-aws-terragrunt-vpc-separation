#!/bin/bash

# Build and deploy Lambda cron containers to ECR
# Usage: ./lambda-cron-build-and-deploy.sh <environment> [image-tag]

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Get the project root directory (parent of scripts directory)
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Change to project root to ensure consistent paths
cd "$PROJECT_ROOT"

ENVIRONMENT=${1:-dev}
IMAGE_TAG=${2:-latest}

if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    echo "Error: Environment must be dev, staging, or prod"
    exit 1
fi

echo "Building and deploying Lambda cron containers for $ENVIRONMENT environment..."

# Get AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=$(aws configure get region || echo "us-east-1")

# Lambda function names
LAMBDA_FUNCTIONS=("lambda-cron-service" "lambda-cron-worker")

echo "Account ID: $ACCOUNT_ID"
echo "Region: $REGION"
echo "Environment: $ENVIRONMENT"
echo "Image Tag: $IMAGE_TAG"
echo ""

# Login to ECR
echo "Logging into ECR..."
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com

# Build and push each Lambda function
for FUNCTION_NAME in "${LAMBDA_FUNCTIONS[@]}"; do
    echo "================================================"
    echo "Processing function: $FUNCTION_NAME"
    echo "================================================"
    
    # ECR repository details
    REPO_NAME="${ENVIRONMENT}-${FUNCTION_NAME}"
    IMAGE_URI="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${REPO_NAME}:${IMAGE_TAG}"
    
    echo "Repository: $REPO_NAME"
    echo "Image URI: $IMAGE_URI"
    
    # Build Docker image
    echo "Building Docker image for $FUNCTION_NAME..."
    cd lambda-cron-service/src
    
    if [ "$FUNCTION_NAME" == "lambda-cron-worker" ]; then
        # Build worker with worker Dockerfile
        docker build -f Dockerfile.worker -t $REPO_NAME:$IMAGE_TAG .
    else
        # Build main cron function with regular Dockerfile
        docker build -t $REPO_NAME:$IMAGE_TAG .
    fi
    
    # Tag image for ECR
    echo "Tagging image for ECR..."
    docker tag $REPO_NAME:$IMAGE_TAG $IMAGE_URI
    
    # Push image to ECR
    echo "Pushing image to ECR..."
    docker push $IMAGE_URI
    
    echo "✅ Successfully pushed $IMAGE_URI"
    echo ""
    
    # Return to root directory
    cd "$PROJECT_ROOT"
done

echo "🎉 All Lambda cron containers built and deployed successfully!"
echo ""
echo "Next steps:"
echo "1. Deploy ECR repositories: cd lambda-cron-service/live/$ENVIRONMENT/ecr && terragrunt apply"
echo "2. Deploy Lambda functions: cd lambda-cron-service/live/$ENVIRONMENT/lambda && terragrunt apply"
echo ""
echo "Or deploy all at once:"
echo "cd lambda-cron-service && terragrunt run-all apply"