#!/bin/bash

# Build and deploy Lambda container to ECR
# Usage: ./build-and-deploy.sh <environment> [image-tag]

set -e

ENVIRONMENT=${1:-dev}
IMAGE_TAG=${2:-latest}

if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    echo "Error: Environment must be dev, staging, or prod"
    exit 1
fi

echo "Building and deploying Lambda container for $ENVIRONMENT environment..."

# Get AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=$(aws configure get region || echo "us-east-1")

# ECR repository name
REPO_NAME="${ENVIRONMENT}-lambda-service"
IMAGE_URI="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${REPO_NAME}:${IMAGE_TAG}"

echo "Repository: $REPO_NAME"
echo "Image URI: $IMAGE_URI"

# Login to ECR
echo "Logging into ECR..."
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com

# Build Docker image
echo "Building Docker image..."
cd lambda-service/src
docker build -t $REPO_NAME:$IMAGE_TAG .

# Tag image for ECR
echo "Tagging image for ECR..."
docker tag $REPO_NAME:$IMAGE_TAG $IMAGE_URI

# Push image to ECR
echo "Pushing image to ECR..."
docker push $IMAGE_URI

echo "Successfully pushed $IMAGE_URI"
echo ""
echo "Next steps:"
echo "1. Deploy ECR repository: cd live/$ENVIRONMENT/ecr && terragrunt apply"
echo "2. Deploy Lambda function: cd live/$ENVIRONMENT/lambda && terragrunt apply"