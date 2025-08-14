# =====================================
# 🧹 UTILITIES & MAINTENANCE
# =====================================

.PHONY: clean clean-cache upgrade-providers status outputs logs-lambda logs-cron validate-all plan-all plan-env

# Cleanup and maintenance
clean: ## 🧹 Clean all Terragrunt cache and lock files
	@echo "$(BLUE)🧹 Cleaning Terragrunt cache and lock files...$(NC)"
	@./scripts/clear-cache.sh

clean-cache: clean ## 🧹 Alias for clean

upgrade-providers: clean ## ⬆️ Upgrade all OpenTofu providers
	@echo "$(BLUE)⬆️ Upgrading OpenTofu providers...$(NC)"
	@./scripts/upgrade-providers.sh

# Status and monitoring
status: ## 📊 Show deployment status for all environments
	@echo "$(BLUE)📊 Deployment Status$(NC)"
	@echo "===================="
	@for env in dev staging prod; do \
		echo "$(YELLOW)Environment: $$env$(NC)"; \
		echo "Infrastructure:"; \
		cd infrastructure/live/$$env/vpc && terragrunt show 2>/dev/null | grep -q "vpc-" && echo "  VPC: $(GREEN)✅ Deployed$(NC)" || echo "  VPC: $(RED)❌ Not deployed$(NC)"; \
		cd ../../../../infrastructure/live/$$env/rds && terragrunt show 2>/dev/null | grep -q "db-" && echo "  RDS: $(GREEN)✅ Deployed$(NC)" || echo "  RDS: $(RED)❌ Not deployed$(NC)"; \
		cd ../../../../infrastructure/live/$$env/timestream-influxdb && terragrunt show 2>/dev/null | grep -q "timestream" && echo "  InfluxDB: $(GREEN)✅ Deployed$(NC)" || echo "  InfluxDB: $(RED)❌ Not deployed$(NC)"; \
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
		echo "InfluxDB Outputs:"; \
		cd ../../../../infrastructure/live/$$env/timestream-influxdb && terragrunt output 2>/dev/null || echo "  No outputs available"; \
		echo ""; \
	done

# Logging
logs-lambda: ## 📖 Show Lambda service logs (ENV=dev|staging|prod)
	$(call check_env,$(ENV))
	@echo "$(BLUE)📖 Lambda service logs for $(ENV)...$(NC)"
	@aws logs tail /aws/lambda/$(ENV)-lambda-function --follow

logs-cron: ## 📖 Show Lambda cron service logs (ENV=dev|staging|prod)
	$(call check_env,$(ENV))
	@echo "$(BLUE)📖 Lambda cron service logs for $(ENV)...$(NC)"
	@aws logs tail /aws/lambda/$(ENV)-lambda-cron-function --follow

# Validation and planning
validate-all: ## ✅ Validate all Terragrunt configurations
	@echo "$(BLUE)✅ Validating all configurations...$(NC)"
	@cd infrastructure && terragrunt run-all validate
	@cd lambda-service && terragrunt run-all validate
	@cd lambda-cron-service && terragrunt run-all validate
	@echo "$(GREEN)✅ All configurations are valid!$(NC)"

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