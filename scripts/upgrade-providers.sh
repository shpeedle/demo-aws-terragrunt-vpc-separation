#!/bin/bash

# Upgrade providers to match new version constraints
echo "🔄 Upgrading providers to match version constraints..."

# Function to upgrade providers in a directory
upgrade_providers_in_dir() {
    local dir=$1
    echo "Upgrading providers in: $dir"
    
    if cd "$dir" 2>/dev/null; then
        # Use terragrunt to run init with upgrade flag
        terragrunt init -upgrade
        cd - > /dev/null
    else
        echo "Warning: Directory $dir not found, skipping..."
    fi
}

# Clear cache and locks first
./clear-cache.sh

echo ""
echo "🔧 Running provider upgrades for infrastructure..."

# Upgrade infrastructure modules
upgrade_providers_in_dir "infrastructure/live/dev/vpc"
upgrade_providers_in_dir "infrastructure/live/dev/rds"
upgrade_providers_in_dir "infrastructure/live/staging/vpc"
upgrade_providers_in_dir "infrastructure/live/staging/rds"
upgrade_providers_in_dir "infrastructure/live/prod/vpc"
upgrade_providers_in_dir "infrastructure/live/prod/rds"

echo ""
echo "🔧 Running provider upgrades for lambda service..."

# Upgrade lambda service modules
upgrade_providers_in_dir "lambda-service/live/dev/ecr"
upgrade_providers_in_dir "lambda-service/live/dev/lambda"
upgrade_providers_in_dir "lambda-service/live/staging/ecr"
upgrade_providers_in_dir "lambda-service/live/staging/lambda"
upgrade_providers_in_dir "lambda-service/live/prod/ecr"
upgrade_providers_in_dir "lambda-service/live/prod/lambda"

echo ""
echo "✅ Provider upgrades complete!"
echo ""
echo "All modules now have updated provider versions matching:"
echo "- AWS Provider: ~> 5.89.0"
echo "- Random Provider: ~> 3.4"