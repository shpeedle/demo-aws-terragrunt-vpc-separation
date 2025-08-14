# =====================================
# 🔒 SECURITY SCANNING TARGETS
# =====================================

.PHONY: scan-security scan-security-env scan-cron-security scan-cron-security-env scan-cron-go-security scan-cron-go-security-env scan-docker-env scan-docker-local scan-docker-go-env scan-docker-go-local

# Infrastructure security scanning
scan-security: ## 🔍 Run Terrascan security scan on all infrastructure modules
	@echo "$(BLUE)🔍 Running Terrascan security scan on infrastructure modules...$(NC)"
	@terrascan scan -i terraform -t aws -d infrastructure/modules --config-path infrastructure/.terrascan_config.toml || true
	@echo "$(GREEN)✅ Security scan completed for all modules$(NC)"

scan-security-env: ## 🔍 Run Terrascan security scan on specific environment (ENV=dev|staging|prod)
	$(call check_env,$(ENV))
	@echo "$(BLUE)🔍 Running Terrascan security scan on $(ENV) environment...$(NC)"
	@terrascan scan -i terraform -t aws -d infrastructure/live/$(ENV) --config-path infrastructure/.terrascan_config.toml || true
	@echo "$(GREEN)✅ Security scan completed for $(ENV) environment$(NC)"

# Lambda cron service security scanning
scan-cron-security: ## 🔍 Run Terrascan security scan on lambda-cron-service modules
	@echo "$(BLUE)🔍 Running Terrascan security scan on lambda-cron-service modules...$(NC)"
	@terrascan scan -i terraform -t aws -d lambda-cron-service/modules --config-path lambda-cron-service/.terrascan_config.toml || true
	@echo "$(GREEN)✅ Security scan completed for lambda-cron-service modules$(NC)"

scan-cron-security-env: ## 🔍 Run Terrascan security scan on lambda-cron-service environment (ENV=dev|staging|prod)
	$(call check_env,$(ENV))
	@echo "$(BLUE)🔍 Running Terrascan security scan on lambda-cron-service $(ENV) environment...$(NC)"
	@terrascan scan -i terraform -t aws -d lambda-cron-service/live/$(ENV) --config-path lambda-cron-service/.terrascan_config.toml || true
	@echo "$(GREEN)✅ Security scan completed for lambda-cron-service $(ENV) environment$(NC)"

# Lambda cron Go service security scanning
scan-cron-go-security: ## 🔍 Run Terrascan security scan on lambda-cron-go-service modules
	@echo "$(BLUE)🔍 Running Terrascan security scan on lambda-cron-go-service modules...$(NC)"
	@terrascan scan -i terraform -t aws -d lambda-cron-go-service/modules || true
	@echo "$(GREEN)✅ Security scan completed for lambda-cron-go-service modules$(NC)"

scan-cron-go-security-env: ## 🔍 Run Terrascan security scan on lambda-cron-go-service environment (ENV=dev|staging|prod)
	$(call check_env,$(ENV))
	@echo "$(BLUE)🔍 Running Terrascan security scan on lambda-cron-go-service $(ENV) environment...$(NC)"
	@terrascan scan -i terraform -t aws -d lambda-cron-go-service/live/$(ENV) || true
	@echo "$(GREEN)✅ Security scan completed for lambda-cron-go-service $(ENV) environment$(NC)"

# Docker image security scanning
scan-docker-env: ## 🔍 Run Docker image security scan for lambda-cron-service (ENV=dev|staging|prod)
	$(call check_env,$(ENV))
	@echo "$(BLUE)🔍 Running Docker security scan for lambda-cron-service $(ENV) environment...$(NC)"
	@./scripts/scan-docker-security.sh $(ENV)

scan-docker-local: ## 🔍 Run Docker security scan on local Dockerfiles only
	@echo "$(BLUE)🔍 Running local Docker security scan on lambda-cron-service Dockerfiles...$(NC)"
	@echo "$(YELLOW)Scanning main Dockerfile...$(NC)"
	@trivy config --severity HIGH,CRITICAL --format table lambda-cron-service/src/Dockerfile || true
	@echo "$(YELLOW)Scanning worker Dockerfile...$(NC)"
	@trivy config --severity HIGH,CRITICAL --format table lambda-cron-service/src/Dockerfile.worker || true
	@echo "$(GREEN)✅ Local Docker security scan completed$(NC)"

scan-docker-go-env: ## 🔍 Run Docker image security scan for lambda-cron-go-service (ENV=dev|staging|prod)
	$(call check_env,$(ENV))
	@echo "$(BLUE)🔍 Running Docker security scan for lambda-cron-go-service $(ENV) environment...$(NC)"
	@echo "$(YELLOW)Scanning Go main image...$(NC)"
	@AWS_ACCOUNT_ID=$$(aws sts get-caller-identity --query Account --output text); \
	AWS_REGION=$$(aws configure get region || echo "us-east-1"); \
	trivy image --severity HIGH,CRITICAL --format table \
		$$AWS_ACCOUNT_ID.dkr.ecr.$$AWS_REGION.amazonaws.com/$(ENV)-lambda-cron-go-service:latest || true
	@echo "$(YELLOW)Scanning Go worker image...$(NC)"
	@AWS_ACCOUNT_ID=$$(aws sts get-caller-identity --query Account --output text); \
	AWS_REGION=$$(aws configure get region || echo "us-east-1"); \
	trivy image --severity HIGH,CRITICAL --format table \
		$$AWS_ACCOUNT_ID.dkr.ecr.$$AWS_REGION.amazonaws.com/$(ENV)-lambda-cron-go-worker:latest || true
	@echo "$(GREEN)✅ Docker security scan completed for lambda-cron-go-service$(NC)"

scan-docker-go-local: ## 🔍 Run Docker security scan on Go service local Dockerfiles only
	@echo "$(BLUE)🔍 Running local Docker security scan on lambda-cron-go-service Dockerfiles...$(NC)"
	@echo "$(YELLOW)Scanning Go main Dockerfile...$(NC)"
	@trivy config --severity HIGH,CRITICAL --format table lambda-cron-go-service/src/Dockerfile || true
	@echo "$(YELLOW)Scanning Go worker Dockerfile...$(NC)"
	@trivy config --severity HIGH,CRITICAL --format table lambda-cron-go-service/src/Dockerfile.worker || true
	@echo "$(GREEN)✅ Local Docker security scan completed for Go service$(NC)"

# Combined security scanning
scan-security-all: ## 🔍 Run all security scans (infrastructure + lambda services + docker)
	@echo "$(BLUE)🔍 Running comprehensive security scan...$(NC)"
	$(MAKE) scan-security
	$(MAKE) scan-cron-security
	$(MAKE) scan-cron-go-security
	$(MAKE) scan-docker-local
	$(MAKE) scan-docker-go-local
	@echo "$(GREEN)🎉 All security scans completed$(NC)"

scan-security-all-env: ## 🔍 Run all security scans for specific environment (ENV=dev|staging|prod)
	$(call check_env,$(ENV))
	@echo "$(BLUE)🔍 Running comprehensive security scan for $(ENV) environment...$(NC)"
	$(MAKE) scan-security-env ENV=$(ENV)
	$(MAKE) scan-cron-security-env ENV=$(ENV)
	$(MAKE) scan-cron-go-security-env ENV=$(ENV)
	$(MAKE) scan-docker-env ENV=$(ENV)
	$(MAKE) scan-docker-go-env ENV=$(ENV)
	@echo "$(GREEN)🎉 All security scans completed for $(ENV) environment$(NC)"

# Go service specific combined scanning
scan-cron-go-all: ## 🔍 Run all security scans for lambda-cron-go-service only
	@echo "$(BLUE)🔍 Running comprehensive security scan for lambda-cron-go-service...$(NC)"
	$(MAKE) scan-cron-go-security
	$(MAKE) scan-docker-go-local
	@echo "$(GREEN)🎉 All lambda-cron-go-service security scans completed$(NC)"

scan-cron-go-all-env: ## 🔍 Run all security scans for lambda-cron-go-service specific environment (ENV=dev|staging|prod)
	$(call check_env,$(ENV))
	@echo "$(BLUE)🔍 Running comprehensive security scan for lambda-cron-go-service $(ENV) environment...$(NC)"
	$(MAKE) scan-cron-go-security-env ENV=$(ENV)
	$(MAKE) scan-docker-go-env ENV=$(ENV)
	@echo "$(GREEN)🎉 All lambda-cron-go-service security scans completed for $(ENV) environment$(NC)"