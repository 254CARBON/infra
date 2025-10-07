# 254Carbon Infrastructure Makefile
# kind/k3d local cluster management

KUSTOMIZE_DIR := k8s/overlays/local
KUSTOMIZE_TARGETS := k8s/base k8s/overlays/local k8s/overlays/dev k8s/overlays/staging
CLUSTER_PROVIDER ?= kind
CLUSTER_NAME := local-254carbon
KIND_CLUSTER_NAME := $(CLUSTER_NAME)
TERRAFORM_DIR := terraform/stacks/local
CONTFEST_POLICY_DIR := policies/opa
KUBECONFORM_FLAGS := -strict -ignore-missing-schemas -summary

ifeq ($(CLUSTER_PROVIDER),kind)
CLUSTER_UP_TARGET := kind-up
CLUSTER_DOWN_TARGET := kind-down
else ifeq ($(CLUSTER_PROVIDER),k3d)
CLUSTER_UP_TARGET := k3d-up
CLUSTER_DOWN_TARGET := k3d-down
else
$(error Unsupported CLUSTER_PROVIDER '$(CLUSTER_PROVIDER)'. Supported values: kind, k3d)
endif

.PHONY: help kind-up kind-down k3d-up k3d-down cluster-up cluster-down k8s-apply-base k8s-apply-platform verify clean validate plan apply backup-run drift-check

help: ## Show this help message
	@echo "254Carbon Infrastructure Management"
	@echo "=================================="
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

kind-up: ## Bootstrap kind multi-node cluster
	bash scripts/kind_bootstrap.sh

kind-down: ## Destroy kind cluster
	kind delete cluster --name $(KIND_CLUSTER_NAME) || true

k3d-up: ## Bootstrap k3d multi-node cluster
	bash scripts/k3d_bootstrap.sh

k3d-down: ## Destroy k3d cluster
	k3d cluster delete $(CLUSTER_NAME) || true

cluster-up: ## Bootstrap local cluster (CLUSTER_PROVIDER=kind|k3d)
	$(MAKE) $(CLUSTER_UP_TARGET)

cluster-down: ## Destroy local cluster (CLUSTER_PROVIDER=kind|k3d)
	$(MAKE) $(CLUSTER_DOWN_TARGET)

k8s-apply-base: ## Apply base K8s manifests (namespaces, RBAC, policies)
	kubectl apply -k k8s/base

k8s-apply-platform: ## Deploy platform components via kustomize
	kubectl apply -k $(KUSTOMIZE_DIR)

verify: ## Run cluster health verification
	bash scripts/verify.sh

validate: ## Validate terraform, kustomize, and policies
	@echo "Validating Kustomize builds..."
	@for target in $(KUSTOMIZE_TARGETS); do \
		echo " - $$target"; \
		kubectl kustomize $$target > /dev/null || exit 1; \
	done
	@echo "Validating Terraform..."
	@if command -v terraform >/dev/null 2>&1; then \
		cd $(TERRAFORM_DIR) && terraform fmt -check && terraform validate; \
	else \
		echo "Terraform not installed, skipping Terraform validation"; \
	fi
	@if command -v kubeconform >/dev/null 2>&1; then \
		echo "Running kubeconform schema checks..."; \
		for target in $(KUSTOMIZE_TARGETS); do \
			echo " - $$target"; \
			kubectl kustomize $$target | kubeconform $(KUBECONFORM_FLAGS) - || exit 1; \
		done; \
	else \
		echo "kubeconform not installed, skipping schema validation"; \
	fi
	@if command -v conftest >/dev/null 2>&1; then \
		echo "Running OPA policy checks with Conftest..."; \
		for target in $(KUSTOMIZE_TARGETS); do \
			echo " - $$target"; \
			kubectl kustomize $$target | conftest test --policy $(CONTFEST_POLICY_DIR) --namespace kubernetes.admission - || exit 1; \
		done; \
	else \
		echo "conftest not installed, skipping policy validation"; \
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
dev-setup: cluster-up k8s-apply-base k8s-apply-platform verify ## Complete local development setup

dev-teardown: cluster-down clean ## Complete local development cleanup

# Quick start sequence
quick-start: dev-setup ## Alias for dev-setup
