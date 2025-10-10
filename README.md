# Infrastructure (`254carbon-infra`)

> Infrastructure-as-code, cluster bootstrap, and platform dependencies for 254Carbon across local, dev, staging, and production environments.

Reference: [Platform Overview](../PLATFORM_OVERVIEW.md)

---

## Scope
- Provision local multi-node Kubernetes clusters (kind/k3d) for development and integration.
- Manage Kustomize overlays, Terraform stacks, and platform dependencies (Kafka, ClickHouse, Redis, Keycloak, MinIO, etc.).
- Apply baseline security (RBAC, NetworkPolicies, PodSecurity, OPA/Conftest) and observability hooks.
- Provide scripts for backups, drift detection, and node labeling.

Out of scope: application code deployment (handled by service repos) and cloud-provider specific production IaC beyond the included Terraform scaffolding.

---

## Repository Structure
- `k8s/base/` – Namespaces, RBAC, storage classes, network policies, pod security defaults.
- `k8s/overlays/<env>/` – Environment-specific overlays for platform components.
- `terraform/` – Modular stacks for local and hybrid setups (`terraform/stacks/local`).
- `scripts/` – Cluster bootstrap (`kind_bootstrap.sh`, `k3d_bootstrap.sh`), verification, backups, node labeling, teardown.
- `policies/` – OPA/Conftest rules enforcing guard rails (no hostPath, limited capabilities, etc.).
- `helm/` – Shared charts or value overrides (when services choose helm packaging).
- `Makefile` – Entry points for cluster lifecycle, validation, backup, drift detection.

---

## Environments

| Environment | Bootstrap | Notes |
|-------------|-----------|-------|
| `local` | `make dev-setup` (`cluster-up`, `k8s-apply-base`, `k8s-apply-platform`, `verify`) | Multi-node kind/k3d with heterogeneous scheduling (x86 + arm affinity labels). |
| `dev` | `CLUSTER_PROVIDER=k3d make cluster-up` followed by `make k8s-apply-base k8s-apply-platform` | Shared integration; smaller resource requests, mock secrets, shorter retention. |
| `staging` | GitOps (Flux/Argo) applies `k8s/overlays/staging`; Terraform stack `terraform/stacks/hybrid` seeds infra | Mirrors production topology; used for load/SLO rehearsals. |
| `production` | Future cloud modules (AWS/GCP) + GitOps overlays | Requires IaC approval workflow, backup/restore jobs enabled, mTLS enforced. |

Environment selection controlled via `CLUSTER_PROVIDER` and overlay path variables. Secrets for non-local environments are sealed and maintained outside this repo.

---

## Runbook

### Daily / Pre-Deploy Checks
- `make verify` – runs cluster health script (checks API server, node status, core addons).
- Ensure drift free: `make drift-check` (kustomize diff + terraform plan) should return no unexpected changes.
- Monitor backing services (ClickHouse, Postgres, Redis, Kafka) via `kubectl get pods -n platform-data`.

### Cluster Lifecycle
- **Bootstrap local cluster**: `make dev-setup` (creates cluster, applies base + platform, verification).
- **Tear down**: `make dev-teardown`.
- **Change cluster provider**: `CLUSTER_PROVIDER=k3d make dev-setup`.

### Applying Platform Changes
1. Update manifests (kustomize, helm) or Terraform modules.
2. `make validate` – kustomize build, terraform validate, kubeconform schema checks, conftest policies.
3. `make k8s-apply-base` (if base resources changed) then `make k8s-apply-platform`.
4. Run `make verify` and targeted smoke tests from dependent repos (e.g., `../access`, `../ingestion`).

### Backups
- Trigger manual backups for ClickHouse/Postgres/MinIO: `make backup-run` (invokes `scripts/backup_clickhouse.sh` and related helpers).
- Schedule CronJobs defined under `k8s/base/backup-jobs/` for automatic execution.
- Store artifacts in configured persistent volumes or remote storage (configure in Terraform outputs).

### Emergency Response
- **Control plane down**: check Docker/k3d status; restart cluster via `make cluster-down && make cluster-up`; restore from etcd snapshot if available.
- **Stateful service data loss**: restore using scripts in `scripts/restore_*` (coming soon) after confirming backups.
- **Security incident**: run `policies/opa` audits (`make validate`) and rotate secrets via `scripts/rotate_secrets.sh`.
- **Resource exhaustion**: inspect `kubectl top nodes` and adjust quotas/limits in overlay values; scale node pool via Terraform (hybrid or cloud).

---

## Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `CLUSTER_PROVIDER` | Cluster runtime (`kind` or `k3d`) | `kind` |
| `CLUSTER_NAME` | Local cluster identifier | `local-254carbon` |
| `KUSTOMIZE_DIR` | Overlay applied for platform components | `k8s/overlays/local` |
| `TERRAFORM_DIR` | Active Terraform stack | `terraform/stacks/local` |
| `KUBECONFORM_FLAGS` | Schema validation flags | `-strict -ignore-missing-schemas -summary` |
| `CONTFEST_POLICY_DIR` | OPA policy directory | `policies/opa` |
| `STORAGE_CLASS_DEFAULT` | Storage class defined in `k8s/base/storageclasses/` | `standard` (uses hostPath for kind) |
| `BACKUP_BUCKET` | Target bucket for backups (set via Terraform vars) | empty (configure per env) |

Override via environment variables or per-environment Makefile includes. Cloud environments load additional variables from Terraform `.tfvars`.

---

## Operational Checks
- `scripts/verify.sh` – ensures nodes Ready, critical namespaces active, storage classes available.
- `scripts/apply_all.sh` – apply manifests sequentially (use with caution; prefer Make targets).
- `policies/opa/*.rego` – run with `conftest` to enforce pod security (no host networking, restricted capabilities).
- `scripts/label_nodes.sh` – label nodes for architecture/role (e.g., `platform=control`, `arch=arm64`).

---

## Troubleshooting

### Cluster Fails to Bootstrap
- Check Docker/k3d environment running (`docker ps`, `k3d cluster list`).
- Inspect bootstrap logs: `cat scripts/kind_bootstrap.sh` output; rerun with `set -x` to debug.
- Ensure required ports free (kind uses 80/443/6443). Stop conflicting services.

### Pods Pending Due to Scheduling
- `kubectl describe pod <name>` to view taints/affinity issues.
- Label nodes with `scripts/label_nodes.sh` to satisfy architecture or GPU requirements.
- Adjust resource requests in `k8s/overlays/<env>/` deployment patches.

### PersistentVolume Claims Stuck Pending
- Verify storage class `standard` exists: `kubectl get storageclass`.
- For kind, ensure hostPath directories accessible; review `k8s/base/storageclasses/hostpath.yaml`.
- For k3d/hybrid, confirm Longhorn/NFS or cloud storage provisioner active.

### Terraform Plan Errors
- Initialize: `cd terraform/stacks/local && terraform init`.
- Resolve provider plugins (set `TF_PLUGIN_CACHE_DIR`).
- Ensure required environment variables set (e.g., cloud credentials) before running plan/apply.

### Drift Between Git and Cluster
- `make drift-check` to report differences.
- For Kustomize drift, inspect `kubectl diff` output and reconcile or patch.
- For Terraform drift, address resources manually or run `terraform apply` to correct.

---

## Reference
- `Makefile` – run `make help` for available operations (cluster lifecycle, validation, backups).
- `terraform/modules/` – reusable modules for data stores, observability, security.
- `k8s/` – baseline + overlays; integrate with GitOps repo for automated promotion.
- `scripts/` – utilities for bootstrap, verification, backups, teardown.
- `policies/opa` – guardrails evaluated by CI and `make validate`.

Consult the [Platform Overview](../PLATFORM_OVERVIEW.md) for environment promotion strategy, shared SLOs, and repository relationships.
