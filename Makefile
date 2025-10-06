# 254Carbon Infrastructure Makefile
# k3d-first local cluster management

KUSTOMIZE_DIR := k8s/overlays/local
CLUSTER_NAME := local-254carbon
TERRAFORM_DIR := terraform/stacks/local

.PHONY: help k3d-up k3d-down k8s-apply-base k8s-apply-platform verify clean validate plan apply backup-run drift-check

help: ## Show this help message
	@echo "254Carbon Infrastructure Management"
	@echo "=================================="
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

k3d-up: ## Bootstrap k3d multi-node cluster
	bash scripts/k3d_bootstrap.sh

k3d-down: ## Destroy k3d cluster
	k3d cluster delete $(CLUSTER_NAME) || true

k8s-apply-base: ## Apply base K8s manifests (namespaces, RBAC, policies)
	kubectl apply -k k8s/base

k8s-apply-platform: ## Deploy platform components via kustomize
	kubectl apply -k $(KUSTOMIZE_DIR)

verify: ## Run cluster health verification
	bash scripts/verify.sh

validate: ## Validate terraform, kustomize, and policies
	@echo "Validating Kustomize..."
	kubectl kustomize $(KUSTOMIZE_DIR) > /dev/null
	@echo "Validating Terraform..."
	@if command -v terraform >/dev/null 2>&1; then \
		cd $(TERRAFORM_DIR) && terraform fmt -check && terraform validate; \
	else \
		echo "Terraform not installed, skipping Terraform validation"; \
	fi
	@echo "Validation complete"

plan: ## Show terraform plan for local stack
	@if command -v terraform >/dev/null 2>&1; then \
		cd $(TERRAFORM_DIR) && terraform plan; \
	else \
		echo "Terraform not installed, cannot run plan"; \
	fi

apply: ## Apply terraform local stack
	@if command -v terraform >/dev/null 2>&1; then \
		cd $(TERRAFORM_DIR) && terraform apply; \
	else \
		echo "Terraform not installed, cannot run apply"; \
	fi

backup-run: ## Trigger manual backup jobs
	bash scripts/backup_clickhouse.sh

drift-check: ## Detect unmanaged changes
	@echo "Checking for drift..."
	kubectl diff -k $(KUSTOMIZE_DIR) || true
	cd $(TERRAFORM_DIR) && terraform plan -detailed-exitcode || true

clean: ## Remove temporary artifacts
	rm -rf manifests/.cache || true
	rm -rf $(TERRAFORM_DIR)/.terraform || true
	rm -rf $(TERRAFORM_DIR)/terraform.tfstate* || true

# Development helpers
dev-setup: k3d-up k8s-apply-base k8s-apply-platform verify ## Complete local development setup

dev-teardown: k3d-down clean ## Complete local development cleanup

# Quick start sequence
quick-start: dev-setup ## Alias for dev-setup
