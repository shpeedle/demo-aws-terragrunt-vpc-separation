# =====================================
# 📦 LAMBDA SERVICE TARGETS
# =====================================

.PHONY: lambda-ecr-all lambda-build-all lambda-deploy-all lambda-ecr-env lambda-build-env lambda-deploy-env lambda-destroy-all lambda-destroy-env
.PHONY: cron-ecr-all cron-build-all cron-deploy-all cron-ecr-env cron-build-env cron-deploy-env cron-destroy-all cron-destroy-env
.PHONY: cron-go-ecr-all cron-go-build-all cron-go-deploy-all cron-go-ecr-env cron-go-build-env cron-go-deploy-env cron-go-destroy-all cron-go-destroy-env

# Lambda Service (basic lambda function)
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

# Lambda Cron Service (cron-based with SQS workers)
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

# Lambda Cron Go Service (Go-based cron with SQS workers)
cron-go-ecr-all: ## 📦 Deploy ECR repositories for lambda-cron-go-service (all environments)
	@echo "$(BLUE)📦 Deploying ECR repositories for lambda-cron-go-service...$(NC)"
	@cd lambda-cron-go-service && terragrunt run-all apply --terragrunt-include-dir live/*/ecr

cron-go-build-all: cron-go-ecr-all ## 🔨 Build and push lambda-cron-go-service containers (all environments)
	@echo "$(GREEN)🔨 Building and pushing lambda-cron-go-service containers...$(NC)"
	@./scripts/lambda-cron-go-build-and-deploy.sh dev
	@./scripts/lambda-cron-go-build-and-deploy.sh staging
	@./scripts/lambda-cron-go-build-and-deploy.sh prod

cron-go-deploy-all: cron-go-build-all ## 🚀 Deploy lambda-cron-go-service functions (all environments)
	@echo "$(GREEN)🚀 Deploying lambda-cron-go-service functions...$(NC)"
	@cd lambda-cron-go-service && terragrunt run-all apply --terragrunt-include-dir live/*/lambda

cron-go-ecr-env: ## 📦 Deploy ECR repository for lambda-cron-go-service (ENV=dev|staging|prod)
	$(call check_env,$(ENV))
	@echo "$(BLUE)📦 Deploying ECR repository for lambda-cron-go-service $(ENV)...$(NC)"
	@cd lambda-cron-go-service/live/$(ENV)/ecr && terragrunt apply

cron-go-build-env: cron-go-ecr-env ## 🔨 Build and push lambda-cron-go-service container (ENV=dev|staging|prod)
	$(call check_env,$(ENV))
	@echo "$(GREEN)🔨 Building and pushing lambda-cron-go-service container for $(ENV)...$(NC)"
	@./scripts/lambda-cron-go-build-and-deploy.sh $(ENV)

cron-go-deploy-env: cron-go-build-env ## 🚀 Deploy lambda-cron-go-service function (ENV=dev|staging|prod)
	$(call check_env,$(ENV))
	@echo "$(GREEN)🚀 Deploying lambda-cron-go-service function for $(ENV)...$(NC)"
	@cd lambda-cron-go-service/live/$(ENV)/lambda && terragrunt apply

cron-go-destroy-all: ## 💥 Destroy lambda-cron-go-service (all environments)
	@echo "$(RED)💥 WARNING: This will destroy ALL lambda-cron-go-service resources!$(NC)"
	@read -p "Are you sure? Type 'YES' to continue: " confirm && [ "$$confirm" = "YES" ]
	@cd lambda-cron-go-service && terragrunt run-all destroy

cron-go-destroy-env: ## 💥 Destroy lambda-cron-go-service (ENV=dev|staging|prod)
	$(call check_env,$(ENV))
	@echo "$(RED)💥 WARNING: This will destroy lambda-cron-go-service for $(ENV)!$(NC)"
	@read -p "Are you sure? Type 'YES' to continue: " confirm && [ "$$confirm" = "YES" ]
	@cd lambda-cron-go-service/live/$(ENV)/lambda && terragrunt destroy
	@cd lambda-cron-go-service/live/$(ENV)/ecr && terragrunt destroy

# Combined Lambda Services
lambda-services-deploy-all: lambda-deploy-all cron-deploy-all cron-go-deploy-all ## 🚀 Deploy all Lambda services (all environments)
	@echo "$(GREEN)🎉 All Lambda services deployed!$(NC)"

lambda-services-deploy-env: lambda-deploy-env cron-deploy-env cron-go-deploy-env ## 🚀 Deploy all Lambda services for specific environment (ENV=dev|staging|prod)
	$(call check_env,$(ENV))
	@echo "$(GREEN)🎉 All Lambda services deployed for $(ENV) environment!$(NC)"