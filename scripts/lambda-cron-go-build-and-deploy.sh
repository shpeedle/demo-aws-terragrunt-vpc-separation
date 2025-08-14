#!/bin/bash

# Build and deploy Go Lambda containers to ECR
# Usage: ./lambda-cron-go-build-and-deploy.sh <environment> [image-tag]

set -e

ENVIRONMENT=${1:-dev}
IMAGE_TAG=${2:-latest}

if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    echo "Error: Environment must be dev, staging, or prod"
    exit 1
fi

echo "Building and deploying Go Lambda containers for $ENVIRONMENT environment..."

# Get AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=$(aws configure get region || echo "us-east-1")

# ECR repository names
MAIN_REPO_NAME="${ENVIRONMENT}-lambda-cron-go-service"
WORKER_REPO_NAME="${ENVIRONMENT}-lambda-cron-go-worker"

MAIN_IMAGE_URI="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${MAIN_REPO_NAME}:${IMAGE_TAG}"
WORKER_IMAGE_URI="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${WORKER_REPO_NAME}:${IMAGE_TAG}"

echo "Main Repository: $MAIN_REPO_NAME"
echo "Main Image URI: $MAIN_IMAGE_URI"
echo "Worker Repository: $WORKER_REPO_NAME"
echo "Worker Image URI: $WORKER_IMAGE_URI"

# Login to ECR
echo "Logging into ECR..."
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com

# Change to source directory
cd lambda-cron-go-service/src

echo "Building main Lambda Docker image..."
docker build -f Dockerfile -t $MAIN_REPO_NAME:$IMAGE_TAG .

echo "Building worker Lambda Docker image..."
docker build -f Dockerfile.worker -t $WORKER_REPO_NAME:$IMAGE_TAG .

# Tag images for ECR
echo "Tagging images for ECR..."
docker tag $MAIN_REPO_NAME:$IMAGE_TAG $MAIN_IMAGE_URI
docker tag $WORKER_REPO_NAME:$IMAGE_TAG $WORKER_IMAGE_URI

# Push images to ECR
echo "Pushing main image to ECR..."
docker push $MAIN_IMAGE_URI

echo "Pushing worker image to ECR..."
docker push $WORKER_IMAGE_URI

echo "Successfully pushed both images:"
echo "- Main: $MAIN_IMAGE_URI"
echo "- Worker: $WORKER_IMAGE_URI"
echo ""
echo "Next steps:"
echo "1. Deploy ECR repositories: cd lambda-cron-go-service/live/$ENVIRONMENT/ecr && terragrunt apply"
echo "2. Deploy Lambda functions: cd lambda-cron-go-service/live/$ENVIRONMENT/lambda && terragrunt apply"