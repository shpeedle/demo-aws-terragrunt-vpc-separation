#!/bin/bash

# Clear Terragrunt cache and provider lock files
echo "🧹 Clearing Terragrunt cache and provider locks..."

# Clear terragrunt cache
find . -name ".terragrunt-cache" -type d -exec rm -rf {} + 2>/dev/null || true

# Clear provider lock files
find . -name ".terraform.lock.hcl" -type f -delete 2>/dev/null || true

echo "✅ Terragrunt cache and provider locks cleared!"
echo ""
echo "This clears:"
echo "- Terragrunt cache directories"
echo "- Provider lock files (.terraform.lock.hcl)"
echo ""
echo "Next steps:"
echo "1. Run terragrunt init to download new providers"
echo "2. Or use terragrunt plan/apply (will auto-init with new providers)"