#!/bin/bash

# Docker Image Security Scanner for Lambda Cron Service
# Uses Trivy to scan Docker images for vulnerabilities

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
ENVIRONMENT=${1:-dev}
SEVERITY_FILTER=${SEVERITY_FILTER:-HIGH,CRITICAL}
OUTPUT_FORMAT=${OUTPUT_FORMAT:-table}
SCAN_TYPE=${SCAN_TYPE:-vuln}

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    echo -e "${RED}❌ Error: Invalid environment '$ENVIRONMENT'. Valid environments: dev, staging, prod${NC}"
    exit 1
fi

# AWS Account and region (should be configured via AWS CLI or environment)
AWS_REGION=${AWS_REGION:-us-east-1}

echo -e "${BLUE}🔍 Starting Docker security scan for lambda-cron-service ($ENVIRONMENT)${NC}"
echo -e "${BLUE}Severity filter: $SEVERITY_FILTER${NC}"
echo -e "${BLUE}Scan type: $SCAN_TYPE${NC}"
echo ""

# Get AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")

if [[ -z "$AWS_ACCOUNT_ID" ]]; then
    echo -e "${RED}❌ Error: Unable to get AWS account ID. Please configure AWS credentials.${NC}"
    exit 1
fi

# ECR repository URIs
ECR_BASE="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
MAIN_IMAGE="$ECR_BASE/$ENVIRONMENT-lambda-cron-main:latest"
WORKER_IMAGE="$ECR_BASE/$ENVIRONMENT-lambda-cron-worker:latest"

echo -e "${YELLOW}🔍 Images to scan:${NC}"
echo -e "  Main: $MAIN_IMAGE"
echo -e "  Worker: $WORKER_IMAGE"
echo ""

# Function to scan image
scan_image() {
    local image=$1
    local image_name=$2
    
    echo -e "${BLUE}🔍 Scanning $image_name image...${NC}"
    echo -e "${BLUE}Image: $image${NC}"
    
    # Check if image exists locally or pull from ECR
    if ! docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "$(echo $image | cut -d'/' -f2-)"; then
        echo -e "${YELLOW}📥 Pulling image from ECR...${NC}"
        
        # Login to ECR
        aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_BASE || {
            echo -e "${RED}❌ Error: Failed to login to ECR${NC}"
            return 1
        }
        
        docker pull $image || {
            echo -e "${RED}❌ Error: Failed to pull image $image${NC}"
            echo -e "${YELLOW}💡 Make sure the image exists and you have permission to access it${NC}"
            return 1
        }
    fi
    
    # Run Trivy scan
    echo -e "${YELLOW}🔍 Running security scan...${NC}"
    
    if [[ "$OUTPUT_FORMAT" == "json" ]]; then
        trivy image \
            --severity $SEVERITY_FILTER \
            --format json \
            --output "/tmp/trivy-${image_name}-${ENVIRONMENT}.json" \
            $image
        
        echo -e "${GREEN}✅ Scan results saved to: /tmp/trivy-${image_name}-${ENVIRONMENT}.json${NC}"
    else
        trivy image \
            --severity $SEVERITY_FILTER \
            --format table \
            $image
    fi
    
    echo ""
}

# Function to scan filesystem (for local development)
scan_local() {
    local dockerfile_path=$1
    local image_name=$2
    
    if [[ -f "$dockerfile_path" ]]; then
        echo -e "${BLUE}🔍 Scanning local Dockerfile: $dockerfile_path${NC}"
        trivy config \
            --severity $SEVERITY_FILTER \
            --format table \
            $dockerfile_path
        echo ""
    fi
}

# Scan main Lambda image
scan_image "$MAIN_IMAGE" "main" || echo -e "${YELLOW}⚠️  Main image scan failed, continuing...${NC}"

# Scan worker Lambda image  
scan_image "$WORKER_IMAGE" "worker" || echo -e "${YELLOW}⚠️  Worker image scan failed, continuing...${NC}"

# Optional: Scan local Dockerfiles for configuration issues
echo -e "${BLUE}🔍 Scanning local Dockerfile configurations...${NC}"
scan_local "lambda-cron-service/src/Dockerfile" "main-dockerfile"
scan_local "lambda-cron-service/src/Dockerfile.worker" "worker-dockerfile"

echo -e "${GREEN}✅ Docker security scan completed for lambda-cron-service ($ENVIRONMENT)${NC}"

# Summary
echo -e "${BLUE}📋 Summary:${NC}"
echo -e "  Environment: $ENVIRONMENT"
echo -e "  Severity filter: $SEVERITY_FILTER"
echo -e "  Scan type: $SCAN_TYPE"
echo -e "  Output format: $OUTPUT_FORMAT"

if [[ "$OUTPUT_FORMAT" == "json" ]]; then
    echo -e "${YELLOW}💡 JSON reports saved to /tmp/trivy-*-${ENVIRONMENT}.json${NC}"
fi

echo -e "${YELLOW}💡 To customize scan:${NC}"
echo -e "  SEVERITY_FILTER=MEDIUM,HIGH,CRITICAL $0 $ENVIRONMENT"
echo -e "  OUTPUT_FORMAT=json $0 $ENVIRONMENT"
echo -e "  SCAN_TYPE=vuln,config,secret $0 $ENVIRONMENT"