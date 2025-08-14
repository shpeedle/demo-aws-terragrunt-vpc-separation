# =====================================
# 🏗️ INFRASTRUCTURE TARGETS
# =====================================

.PHONY: infra-plan infra-apply infra-destroy infra-plan-env infra-apply-env infra-destroy-env

# All environments infrastructure
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

# Single environment infrastructure
infra-plan-env: ## 📋 Plan infrastructure for specific environment (ENV=dev|staging|prod)
	$(call check_env,$(ENV))
	@echo "$(BLUE)📋 Planning infrastructure for $(ENV) environment...$(NC)"
	@cd infrastructure/live/$(ENV)/vpc && terragrunt plan
	@cd infrastructure/live/$(ENV)/rds && terragrunt plan
	@cd infrastructure/live/$(ENV)/timestream-influxdb && terragrunt plan

infra-apply-env: ## 🔨 Apply infrastructure for specific environment (ENV=dev|staging|prod)
	$(call check_env,$(ENV))
	@echo "$(GREEN)🔨 Applying infrastructure for $(ENV) environment...$(NC)"
	@cd infrastructure/live/$(ENV)/vpc && terragrunt apply
	@cd infrastructure/live/$(ENV)/rds && terragrunt apply
	@cd infrastructure/live/$(ENV)/timestream-influxdb && terragrunt apply

infra-destroy-env: ## 💥 Destroy infrastructure for specific environment (ENV=dev|staging|prod)
	$(call check_env,$(ENV))
	@echo "$(RED)💥 WARNING: This will destroy $(ENV) infrastructure!$(NC)"
	@read -p "Are you sure? Type 'YES' to continue: " confirm && [ "$$confirm" = "YES" ]
	@cd infrastructure/live/$(ENV)/timestream-influxdb && terragrunt destroy
	@cd infrastructure/live/$(ENV)/rds && terragrunt destroy
	@cd infrastructure/live/$(ENV)/vpc && terragrunt destroy