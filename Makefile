# AWS Terragrunt Multi-Environment Infrastructure Makefile
# ===========================================================

.PHONY: help
.DEFAULT_GOAL := help

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[0;33m
BLUE := \033[0;34m
PURPLE := \033[0;35m
CYAN := \033[0;36m
NC := \033[0m # No Color

# Environment validation
VALID_ENVS := dev staging prod
ENV ?= dev

define check_env
	@if ! echo "$(VALID_ENVS)" | grep -wq "$(1)"; then \
		echo "$(RED)❌ Error: Invalid environment '$(1)'. Valid environments: $(VALID_ENVS)$(NC)"; \
		exit 1; \
	fi
endef

# =====================================
# 🚀 BOOTSTRAP & SETUP
# =====================================

.PHONY: bootstrap init-all setup check-aws

bootstrap: ## 🚀 Bootstrap initial AWS infrastructure (S3 bucket, DynamoDB table)
	@echo "$(BLUE)🚀 Bootstrapping Terragrunt state management infrastructure...$(NC)"
	@./scripts/bootstrap.sh

init-all: ## 🔧 Initialize Terragrunt in all projects
	@echo "$(BLUE)🔧 Initializing Terragrunt in all projects...$(NC)"
	@echo "$(YELLOW)Initializing infrastructure (VPC first, then RDS, then InfluxDB)...$(NC)"
	@cd infrastructure && terragrunt init --all --queue-include-dir=live/dev/vpc --queue-include-dir=live/staging/vpc --queue-include-dir=live/prod/vpc
	@cd infrastructure && terragrunt init --all --queue-include-dir=live/dev/rds --queue-include-dir=live/staging/rds --queue-include-dir=live/prod/rds
	@cd infrastructure && terragrunt init --all --queue-include-dir=live/dev/timestream-influxdb --queue-include-dir=live/staging/timestream-influxdb --queue-include-dir=live/prod/timestream-influxdb
	@echo "$(YELLOW)Initializing lambda services...$(NC)"
	@cd lambda-service && terragrunt init --all
	@cd lambda-cron-service && terragrunt init --all
	@cd lambda-step-service && terragrunt init --all
	@echo "$(GREEN)✅ All projects initialized$(NC)"

setup: bootstrap init-all ## 🔧 Complete setup: bootstrap + init + plan all infrastructure
	@echo "$(BLUE)🔧 Running complete setup...$(NC)"
	$(MAKE) plan-all

check-aws: ## ✅ Check AWS credentials and configuration
	@echo "$(BLUE)🔍 Checking AWS configuration...$(NC)"
	@aws sts get-caller-identity --output table
	@echo "$(GREEN)✅ AWS credentials are valid$(NC)"

# =====================================
# 🚀 DEPLOYMENT WORKFLOWS
# =====================================

.PHONY: deploy-all deploy-env quick-deploy-env destroy-all destroy-env

deploy-all: infra-apply lambda-services-deploy-all ## 🚀 Complete deployment: infrastructure + all lambda services (all environments)
	@echo "$(GREEN)🎉 Complete deployment finished for all environments!$(NC)"

deploy-env: infra-apply-env lambda-services-deploy-env ## 🚀 Complete deployment for specific environment (ENV=dev|staging|prod)
	$(call check_env,$(ENV))
	@echo "$(GREEN)🎉 Complete deployment finished for $(ENV) environment!$(NC)"

quick-deploy-env: ## ⚡ Quick deploy: skip infrastructure, deploy services only (ENV=dev|staging|prod)
	$(call check_env,$(ENV))
	@echo "$(YELLOW)⚡ Quick deploying services for $(ENV) environment...$(NC)"
	$(MAKE) lambda-services-deploy-env ENV=$(ENV)
	@echo "$(GREEN)⚡ Quick deployment finished for $(ENV) environment!$(NC)"

destroy-all: ## 💥 Destroy EVERYTHING (VERY DANGEROUS)
	@echo "$(RED)💥 WARNING: This will destroy ALL infrastructure and services!$(NC)"
	@echo "$(RED)This includes:$(NC)"
	@echo "$(RED)- All Lambda functions and ECR repositories$(NC)"
	@echo "$(RED)- All databases and VPCs$(NC)"
	@echo "$(RED)- All environments (dev, staging, prod)$(NC)"
	@echo ""
	@read -p "Type 'DESTROY-EVERYTHING' to confirm: " confirm && [ "$$confirm" = "DESTROY-EVERYTHING" ]
	$(MAKE) cron-destroy-all
	$(MAKE) lambda-destroy-all
	$(MAKE) infra-destroy

destroy-env: ## 💥 Destroy specific environment (ENV=dev|staging|prod)
	$(call check_env,$(ENV))
	@echo "$(RED)💥 WARNING: This will destroy ALL resources in $(ENV) environment!$(NC)"
	@read -p "Type 'DESTROY-$(ENV)' to confirm: " confirm && [ "$$confirm" = "DESTROY-$(ENV)" ]
	$(MAKE) cron-destroy-env ENV=$(ENV)
	$(MAKE) lambda-destroy-env ENV=$(ENV)
	$(MAKE) infra-destroy-env ENV=$(ENV)

# =====================================
# 📚 HELP & DOCUMENTATION
# =====================================

.PHONY: help

help: ## 📚 Show this help message
	@echo "$(BLUE)AWS Terragrunt Multi-Environment Infrastructure$(NC)"
	@echo "=============================================="
	@echo ""
	@echo "$(YELLOW)Usage:$(NC) make [target] [ENV=environment]"
	@echo ""
	@echo "$(YELLOW)Valid environments:$(NC) dev, staging, prod"
	@echo "$(YELLOW)Default environment:$(NC) dev"
	@echo ""
	@echo "$(YELLOW)Examples:$(NC)"
	@echo "  make bootstrap                     # Bootstrap initial infrastructure"
	@echo "  make deploy-env ENV=dev           # Deploy everything to dev"
	@echo "  make lambda-deploy-env ENV=prod   # Deploy lambda service to prod"
	@echo "  make scan-security-all ENV=dev    # Run all security scans for dev"
	@echo "  make plan-all                     # Plan all environments"
	@echo "  make clean                        # Clean cache files"
	@echo ""
	@echo "$(PURPLE)📋 Main Categories:$(NC)"
	@echo "  $(CYAN)🚀 Setup & Bootstrap$(NC)  - bootstrap, init-all, setup, check-aws"
	@echo "  $(CYAN)🏗️  Infrastructure$(NC)     - infra-*, plan-*, validate-all"
	@echo "  $(CYAN)📦 Lambda Services$(NC)     - lambda-*, cron-* (ECR, build, deploy)"
	@echo "  $(CYAN)🔒 Security Scanning$(NC)   - scan-* (infrastructure, docker, cron)"
	@echo "  $(CYAN)🧹 Utilities$(NC)           - clean, status, outputs, logs-*"
	@echo "  $(CYAN)💥 Destruction$(NC)         - destroy-* (DANGEROUS)"
	@echo ""
	@echo "$(YELLOW)Available targets:$(NC)"
	@awk 'BEGIN {FS = ":.*##"; printf ""} /^[a-zA-Z_-]+:.*?##/ { printf "  $(CYAN)%-28s$(NC) %s\n", $$1, $$2 }' $(MAKEFILE_LIST) makefiles/*.mk | sort

# =====================================
# 📁 INCLUDE MODULE MAKEFILES
# =====================================

# Include modular makefiles
include makefiles/infrastructure.mk
include makefiles/lambda-services.mk
include makefiles/security.mk
include makefiles/utils.mk