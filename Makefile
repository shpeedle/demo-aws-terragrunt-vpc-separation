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

.PHONY: bootstrap
bootstrap: ## 🚀 Bootstrap initial AWS infrastructure (S3 bucket, DynamoDB table)
	@echo "$(BLUE)🚀 Bootstrapping Terragrunt state management infrastructure...$(NC)"
	@./scripts/bootstrap.sh

.PHONY: init-all
init-all: ## 🔧 Initialize Terragrunt in all projects
	@echo "$(BLUE)🔧 Initializing Terragrunt in all projects...$(NC)"
	@echo "$(YELLOW)Initializing infrastructure (VPC first, then RDS)...$(NC)"
	@cd infrastructure && terragrunt init --all --queue-include-dir=live/dev/vpc --queue-include-dir=live/staging/vpc --queue-include-dir=live/prod/vpc
	@cd infrastructure && terragrunt init --all --queue-include-dir=live/dev/rds --queue-include-dir=live/staging/rds --queue-include-dir=live/prod/rds
	@echo "$(YELLOW)Initializing lambda services...$(NC)"
	@cd lambda-service && terragrunt init --all
	@cd lambda-cron-service && terragrunt init --all
	@cd lambda-step-service && terragrunt init --all
	@echo "$(GREEN)✅ All projects initialized$(NC)"

.PHONY: setup
setup: bootstrap init-all ## 🔧 Complete setup: bootstrap + init + plan all infrastructure
	@echo "$(BLUE)🔧 Running complete setup...$(NC)"
	$(MAKE) plan-all

.PHONY: check-aws
check-aws: ## ✅ Check AWS credentials and configuration
	@echo "$(BLUE)🔍 Checking AWS configuration...$(NC)"
	@aws sts get-caller-identity --output table
	@echo "$(GREEN)✅ AWS credentials are valid$(NC)"

# =====================================
# 🏗️ INFRASTRUCTURE TARGETS
# =====================================

.PHONY: infra-plan infra-apply infra-destroy
infra-plan: ## 📋 Plan infrastructure changes for all environments
	@echo "$(BLUE)📋 Planning infrastructure for all environments...$(NC)"
	@cd infrastructure && terragrunt run-all plan

infra-apply: ## 🔨 Apply infrastructure for all environments
	@echo "$(GREEN)🔨 Applying infrastructure for all environments...$(NC)"
	@cd infrastructure && terragrunt run-all apply

infra-destroy: ## 💥 Destroy infrastructure for all environments (DANGEROUS)
	@echo "$(RED)💥 WARNING: This will destroy ALL infrastructure!$(NC)"
	@read -p "Are you sure? Type 'YES' to continue: " confirm && [ "$$confirm" = "YES" ]
	@cd infrastructure && terragrunt run-all destroy

.PHONY: infra-plan-env infra-apply-env infra-destroy-env
infra-plan-env: ## 📋 Plan infrastructure for specific environment (ENV=dev|staging|prod)
	$(call check_env,$(ENV))
	@echo "$(BLUE)📋 Planning infrastructure for $(ENV) environment...$(NC)"
	@cd infrastructure/live/$(ENV)/vpc && terragrunt plan
	@cd infrastructure/live/$(ENV)/rds && terragrunt plan

infra-apply-env: ## 🔨 Apply infrastructure for specific environment (ENV=dev|staging|prod)
	$(call check_env,$(ENV))
	@echo "$(GREEN)🔨 Applying infrastructure for $(ENV) environment...$(NC)"
	@cd infrastructure/live/$(ENV)/vpc && terragrunt apply
	@cd infrastructure/live/$(ENV)/rds && terragrunt apply

infra-destroy-env: ## 💥 Destroy infrastructure for specific environment (ENV=dev|staging|prod)
	$(call check_env,$(ENV))
	@echo "$(RED)💥 WARNING: This will destroy $(ENV) infrastructure!$(NC)"
	@read -p "Are you sure? Type 'YES' to continue: " confirm && [ "$$confirm" = "YES" ]
	@cd infrastructure/live/$(ENV)/rds && terragrunt destroy
	@cd infrastructure/live/$(ENV)/vpc && terragrunt destroy

# =====================================
# 📦 LAMBDA SERVICE TARGETS
# =====================================

.PHONY: lambda-ecr-all lambda-build-all lambda-deploy-all
lambda-ecr-all: ## 📦 Deploy ECR repositories for lambda-service (all environments)
	@echo "$(BLUE)📦 Deploying ECR repositories for lambda-service...$(NC)"
	@cd lambda-service && terragrunt run-all apply --terragrunt-include-dir live/*/ecr

lambda-build-all: lambda-ecr-all ## 🔨 Build and push lambda-service containers (all environments)
	@echo "$(GREEN)🔨 Building and pushing lambda-service containers...$(NC)"
	@./scripts/lambda-build-and-deploy.sh dev
	@./scripts/lambda-build-and-deploy.sh staging
	@./scripts/lambda-build-and-deploy.sh prod

lambda-deploy-all: lambda-build-all ## 🚀 Deploy lambda-service functions (all environments)
	@echo "$(GREEN)🚀 Deploying lambda-service functions...$(NC)"
	@cd lambda-service && terragrunt run-all apply --terragrunt-include-dir live/*/lambda

.PHONY: lambda-ecr-env lambda-build-env lambda-deploy-env
lambda-ecr-env: ## 📦 Deploy ECR repository for lambda-service (ENV=dev|staging|prod)
	$(call check_env,$(ENV))
	@echo "$(BLUE)📦 Deploying ECR repository for lambda-service $(ENV)...$(NC)"
	@cd lambda-service/live/$(ENV)/ecr && terragrunt apply

lambda-build-env: lambda-ecr-env ## 🔨 Build and push lambda-service container (ENV=dev|staging|prod)
	$(call check_env,$(ENV))
	@echo "$(GREEN)🔨 Building and pushing lambda-service container for $(ENV)...$(NC)"
	@./scripts/lambda-build-and-deploy.sh $(ENV)

lambda-deploy-env: lambda-build-env ## 🚀 Deploy lambda-service function (ENV=dev|staging|prod)
	$(call check_env,$(ENV))
	@echo "$(GREEN)🚀 Deploying lambda-service function for $(ENV)...$(NC)"
	@cd lambda-service/live/$(ENV)/lambda && terragrunt apply

.PHONY: lambda-destroy-all lambda-destroy-env
lambda-destroy-all: ## 💥 Destroy lambda-service (all environments)
	@echo "$(RED)💥 WARNING: This will destroy ALL lambda-service resources!$(NC)"
	@read -p "Are you sure? Type 'YES' to continue: " confirm && [ "$$confirm" = "YES" ]
	@cd lambda-service && terragrunt run-all destroy

lambda-destroy-env: ## 💥 Destroy lambda-service (ENV=dev|staging|prod)
	$(call check_env,$(ENV))
	@echo "$(RED)💥 WARNING: This will destroy lambda-service for $(ENV)!$(NC)"
	@read -p "Are you sure? Type 'YES' to continue: " confirm && [ "$$confirm" = "YES" ]
	@cd lambda-service/live/$(ENV)/lambda && terragrunt destroy
	@cd lambda-service/live/$(ENV)/ecr && terragrunt destroy

# =====================================
# ⏰ LAMBDA CRON SERVICE TARGETS
# =====================================

.PHONY: cron-ecr-all cron-build-all cron-deploy-all
cron-ecr-all: ## 📦 Deploy ECR repositories for lambda-cron-service (all environments)
	@echo "$(BLUE)📦 Deploying ECR repositories for lambda-cron-service...$(NC)"
	@cd lambda-cron-service && terragrunt run-all apply --terragrunt-include-dir live/*/ecr

cron-build-all: cron-ecr-all ## 🔨 Build and push lambda-cron-service containers (all environments)
	@echo "$(GREEN)🔨 Building and pushing lambda-cron-service containers...$(NC)"
	@./scripts/lambda-cron-build-and-deploy.sh dev
	@./scripts/lambda-cron-build-and-deploy.sh staging
	@./scripts/lambda-cron-build-and-deploy.sh prod

cron-deploy-all: cron-build-all ## 🚀 Deploy lambda-cron-service functions (all environments)
	@echo "$(GREEN)🚀 Deploying lambda-cron-service functions...$(NC)"
	@cd lambda-cron-service && terragrunt run-all apply --terragrunt-include-dir live/*/lambda

.PHONY: cron-ecr-env cron-build-env cron-deploy-env
cron-ecr-env: ## 📦 Deploy ECR repository for lambda-cron-service (ENV=dev|staging|prod)
	$(call check_env,$(ENV))
	@echo "$(BLUE)📦 Deploying ECR repository for lambda-cron-service $(ENV)...$(NC)"
	@cd lambda-cron-service/live/$(ENV)/ecr && terragrunt apply

cron-build-env: cron-ecr-env ## 🔨 Build and push lambda-cron-service container (ENV=dev|staging|prod)
	$(call check_env,$(ENV))
	@echo "$(GREEN)🔨 Building and pushing lambda-cron-service container for $(ENV)...$(NC)"
	@./scripts/lambda-cron-build-and-deploy.sh $(ENV)

cron-deploy-env: cron-build-env ## 🚀 Deploy lambda-cron-service function (ENV=dev|staging|prod)
	$(call check_env,$(ENV))
	@echo "$(GREEN)🚀 Deploying lambda-cron-service function for $(ENV)...$(NC)"
	@cd lambda-cron-service/live/$(ENV)/lambda && terragrunt apply

.PHONY: cron-destroy-all cron-destroy-env
cron-destroy-all: ## 💥 Destroy lambda-cron-service (all environments)
	@echo "$(RED)💥 WARNING: This will destroy ALL lambda-cron-service resources!$(NC)"
	@read -p "Are you sure? Type 'YES' to continue: " confirm && [ "$$confirm" = "YES" ]
	@cd lambda-cron-service && terragrunt run-all destroy

cron-destroy-env: ## 💥 Destroy lambda-cron-service (ENV=dev|staging|prod)
	$(call check_env,$(ENV))
	@echo "$(RED)💥 WARNING: This will destroy lambda-cron-service for $(ENV)!$(NC)"
	@read -p "Are you sure? Type 'YES' to continue: " confirm && [ "$$confirm" = "YES" ]
	@cd lambda-cron-service/live/$(ENV)/lambda && terragrunt destroy
	@cd lambda-cron-service/live/$(ENV)/ecr && terragrunt destroy

# =====================================
# 🚀 COMPLETE DEPLOYMENT WORKFLOWS
# =====================================

.PHONY: deploy-all deploy-env
deploy-all: infra-apply lambda-deploy-all cron-deploy-all ## 🚀 Complete deployment: infrastructure + both lambda services (all environments)
	@echo "$(GREEN)🎉 Complete deployment finished for all environments!$(NC)"

deploy-env: infra-apply-env lambda-deploy-env cron-deploy-env ## 🚀 Complete deployment for specific environment (ENV=dev|staging|prod)
	$(call check_env,$(ENV))
	@echo "$(GREEN)🎉 Complete deployment finished for $(ENV) environment!$(NC)"

.PHONY: quick-deploy-env
quick-deploy-env: ## ⚡ Quick deploy: skip infrastructure, deploy services only (ENV=dev|staging|prod)
	$(call check_env,$(ENV))
	@echo "$(YELLOW)⚡ Quick deploying services for $(ENV) environment...$(NC)"
	$(MAKE) lambda-deploy-env ENV=$(ENV)
	$(MAKE) cron-deploy-env ENV=$(ENV)
	@echo "$(GREEN)⚡ Quick deployment finished for $(ENV) environment!$(NC)"

# =====================================
# 📋 PLANNING & VALIDATION
# =====================================

.PHONY: plan-all plan-env validate-all
plan-all: ## 📋 Plan all infrastructure and services
	@echo "$(BLUE)📋 Planning all infrastructure and services...$(NC)"
	$(MAKE) infra-plan
	@cd lambda-service && terragrunt run-all plan
	@cd lambda-cron-service && terragrunt run-all plan

plan-env: ## 📋 Plan specific environment (ENV=dev|staging|prod)
	$(call check_env,$(ENV))
	@echo "$(BLUE)📋 Planning $(ENV) environment...$(NC)"
	$(MAKE) infra-plan-env ENV=$(ENV)
	@cd lambda-service/live/$(ENV)/ecr && terragrunt plan
	@cd lambda-service/live/$(ENV)/lambda && terragrunt plan
	@cd lambda-cron-service/live/$(ENV)/ecr && terragrunt plan
	@cd lambda-cron-service/live/$(ENV)/lambda && terragrunt plan

validate-all: ## ✅ Validate all Terragrunt configurations
	@echo "$(BLUE)✅ Validating all configurations...$(NC)"
	@cd infrastructure && terragrunt run-all validate
	@cd lambda-service && terragrunt run-all validate
	@cd lambda-cron-service && terragrunt run-all validate
	@echo "$(GREEN)✅ All configurations are valid!$(NC)"

# =====================================
# 🧹 MAINTENANCE & UTILITIES
# =====================================

.PHONY: clean clean-cache upgrade-providers
clean: ## 🧹 Clean all Terragrunt cache and lock files
	@echo "$(BLUE)🧹 Cleaning Terragrunt cache and lock files...$(NC)"
	@./scripts/clear-cache.sh

clean-cache: clean ## 🧹 Alias for clean

upgrade-providers: clean ## ⬆️ Upgrade all OpenTofu providers
	@echo "$(BLUE)⬆️ Upgrading OpenTofu providers...$(NC)"
	@./scripts/upgrade-providers.sh

.PHONY: status outputs
status: ## 📊 Show deployment status for all environments
	@echo "$(BLUE)📊 Deployment Status$(NC)"
	@echo "===================="
	@for env in dev staging prod; do \
		echo "$(YELLOW)Environment: $$env$(NC)"; \
		echo "Infrastructure:"; \
		cd infrastructure/live/$$env/vpc && terragrunt show 2>/dev/null | grep -q "vpc-" && echo "  VPC: $(GREEN)✅ Deployed$(NC)" || echo "  VPC: $(RED)❌ Not deployed$(NC)"; \
		cd ../../../../infrastructure/live/$$env/rds && terragrunt show 2>/dev/null | grep -q "db-" && echo "  RDS: $(GREEN)✅ Deployed$(NC)" || echo "  RDS: $(RED)❌ Not deployed$(NC)"; \
		echo "Lambda Services:"; \
		cd ../../../../lambda-service/live/$$env/lambda && terragrunt show 2>/dev/null | grep -q "lambda" && echo "  Lambda Service: $(GREEN)✅ Deployed$(NC)" || echo "  Lambda Service: $(RED)❌ Not deployed$(NC)"; \
		cd ../../../../lambda-cron-service/live/$$env/lambda && terragrunt show 2>/dev/null | grep -q "lambda" && echo "  Lambda Cron: $(GREEN)✅ Deployed$(NC)" || echo "  Lambda Cron: $(RED)❌ Not deployed$(NC)"; \
		echo ""; \
	done

outputs: ## 📋 Show outputs for all deployed resources
	@echo "$(BLUE)📋 Infrastructure Outputs$(NC)"
	@echo "========================="
	@for env in dev staging prod; do \
		echo "$(YELLOW)Environment: $$env$(NC)"; \
		echo "VPC Outputs:"; \
		cd infrastructure/live/$$env/vpc && terragrunt output 2>/dev/null || echo "  No outputs available"; \
		echo "RDS Outputs:"; \
		cd ../../../../infrastructure/live/$$env/rds && terragrunt output 2>/dev/null || echo "  No outputs available"; \
		echo ""; \
	done

.PHONY: logs-lambda logs-cron
logs-lambda: ## 📖 Show Lambda service logs (ENV=dev|staging|prod)
	$(call check_env,$(ENV))
	@echo "$(BLUE)📖 Lambda service logs for $(ENV)...$(NC)"
	@aws logs tail /aws/lambda/$(ENV)-lambda-function --follow

logs-cron: ## 📖 Show Lambda cron service logs (ENV=dev|staging|prod)
	$(call check_env,$(ENV))
	@echo "$(BLUE)📖 Lambda cron service logs for $(ENV)...$(NC)"
	@aws logs tail /aws/lambda/$(ENV)-lambda-cron-function --follow

# =====================================
# 💥 DESTRUCTION (DANGEROUS)
# =====================================

.PHONY: destroy-all destroy-env
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
	@echo "  make bootstrap                    # Bootstrap initial infrastructure"
	@echo "  make deploy-env ENV=dev          # Deploy everything to dev"
	@echo "  make lambda-deploy-env ENV=prod  # Deploy lambda service to prod"
	@echo "  make plan-all                    # Plan all environments"
	@echo "  make clean                       # Clean cache files"
	@echo ""
	@echo "$(YELLOW)Available targets:$(NC)"
	@awk 'BEGIN {FS = ":.*##"; printf ""} /^[a-zA-Z_-]+:.*?##/ { printf "  $(CYAN)%-25s$(NC) %s\n", $$1, $$2 }' $(MAKEFILE_LIST) | sort