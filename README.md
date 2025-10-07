# 254Carbon Infrastructure (`254carbon-infra`)

> Infrastructure-as-Code (IaC) and environment orchestration for the 254Carbon platform.  
> Designed for a staged evolution: **local heterogeneous cluster (Linux x86 + macOS ARM w/ GPU)** → **hybrid multi-host** → **future cloud or multi-region**.

---

## Quick Start

```bash
# 1. Bootstrap k3d multi-node cluster (default)
make k3d-up

# 2. Apply base (namespaces, RBAC, policies)
make k8s-apply-base

# 3. Deploy data + platform dependencies
make k8s-apply-platform

# 4. Verify critical services
make verify

# 5. Tear down (clean)
make k3d-down
```

Prefer kind for local testing? Swap the bootstrap/teardown commands:

```bash
make kind-up
# ...
make kind-down
```

Or reuse the aggregated targets with `CLUSTER_PROVIDER=kind make cluster-up` and `CLUSTER_PROVIDER=kind make cluster-down`.

---

## Table of Contents
- [Quick Start](#quick-start)
- [1. Vision & Principles](#1-vision--principles)
- [2. Scope & Non-Scope](#2-scope--non-scope)
- [3. Architecture Overview](#3-architecture-overview)
- [4. Repository Structure](#4-repository-structure)
- [5. Environments & Promotion Model](#5-environments--promotion-model)
- [6. Local Cluster (3-Node Hybrid)](#6-local-cluster-3-node-hybrid)
- [7. Kubernetes Layout & Namespaces](#7-kubernetes-layout--namespaces)
- [8. Core Platform Components](#8-core-platform-components)
- [9. Terraform Module Design](#9-terraform-module-design)
- [10. GitOps & Deployment Flow](#10-gitops--deployment-flow)
- [11. Secrets & Configuration Management](#11-secrets--configuration-management)
- [12. Networking & Ingress Topology](#12-networking--ingress-topology)
- [13. Storage, Persistence & Data Classes](#13-storage-persistence--data-classes)
- [14. Backup & Restore Strategy](#14-backup--restore-strategy)
- [15. Observability Integration (Metrics, Logs, Traces)](#15-observability-integration-metrics-logs-traces)
- [16. Security & Policy Enforcement](#16-security--policy-enforcement)
- [17. Multi-Arch & Heterogeneous Scheduling](#17-multi-arch--heterogeneous-scheduling)
- [18. Resource Naming & Tagging Conventions](#18-resource-naming--tagging-conventions)
- [19. Automation Scripts & Make Targets](#19-automation-scripts--make-targets)
- [20. CI/CD Pipeline (Infra Changes)](#20-cicd-pipeline-infra-changes)
- [21. Drift Detection & Guard Rails](#21-drift-detection--guard-rails)
- [22. Disaster Recovery & Resilience (Roadmap)](#22-disaster-recovery--resilience-roadmap)
- [23. Cost / Resource Footprint Awareness (Local)](#23-cost--resource-footprint-awareness-local)
- [24. Future Cloud Migration Blueprint](#24-future-cloud-migration-blueprint)
- [25. Contribution Workflow](#25-contribution-workflow)
- [26. Troubleshooting Matrix](#26-troubleshooting-matrix)
- [27. Roadmap](#27-roadmap)
- [28. Changelog Template](#28-changelog-template)
- [29. License / Ownership](#29-license--ownership)

---

## 1. Vision & Principles

| Principle | Description |
|-----------|-------------|
| Reproducibility | Complete platform standing up from scratch with a single command. |
| Incremental Evolution | Start local; modules already cloud‑ready in structure. |
| Explicit Boundaries | Clear separation: base infra vs platform services vs data stores. |
| Observability Default | Every component exported metrics/logs/traces from day one. |
| Ephemerality for Dev | Non‑critical services can be torn down & rebuilt quickly. |
| Idempotency | Repeated applies produce no drift. |
| Policy as Code | Security & guardrails shift-left (OPA/Conftest). |
| Multi-Arch Awareness | ARM + AMD64 images & node targeting built-in. |

---

## 2. Scope & Non-Scope

### In Scope
- Terraform scaffolding (even if local execution is partial).
- Kubernetes cluster bootstrap (kind/k3d + manifest layering).
- Namespaces, RBAC, NetworkPolicies, storage classes.
- Deployment templates for: ClickHouse, PostgreSQL, Redis, Kafka, MinIO, Keycloak, MLflow, OTel Collector, Prometheus stack.
- GitOps integration hooks (ArgoCD/Flux optional).
- Backup job specs (ClickHouse + Postgres + MinIO lifecycle).
- Security baseline (pod security, resource quotas, minimal privileges).
- Multi-arch build + scheduling strategies.

### Out of Scope
- Application business logic (see other repos).
- Individual service Helm charts (reside in their own repos or a shared chart repo).
- Cloud provider provisioning (future layers will add AWS / GCP modules).

---

## 3. Architecture Overview

Logical Layers:

```text
┌─────────────────────────────────────────────┐
│ Access Layer (Ingress / Gateway / Streaming)│
├─────────────────────────────────────────────┤
│ Core Platform Services (Auth, Entitlements, │
│ Metrics, Normalization, ML, Search, etc.)   │
├─────────────────────────────────────────────┤
│ Data Services (PostgreSQL, ClickHouse,      │
│ Redis, Kafka, MinIO, Vector Store)          │
├─────────────────────────────────────────────┤
│ Infra Control Plane (K8s API, Certs,        │
│ CNI, StorageClasses, Monitoring Stack)      │
├─────────────────────────────────────────────┤
│ Host Layer (Linux x86 node, 2 × macOS ARM)  │
└─────────────────────────────────────────────┘
```

---

## 4. Repository Structure

```text
/
  terraform/
    modules/
      k8s_cluster/
      clickhouse/
      postgresql/
      redis/
      kafka/
      minio/
      keycloak/
      mlflow/
      observability/
      storage/
    stacks/
      local/
        main.tf
        variables.tf
        outputs.tf
      hybrid/
        main.tf
  k8s/
    base/
      namespaces/
      storageclasses/
      rbac/
      network-policies/
      podsecurity/
    platform/
      clickhouse/
      postgresql/
      redis/
      kafka/
      minio/
      keycloak/
      mlflow/
      metrics-stack/
      otel/
      backup-jobs/
    overlays/
      local/
      dev/
      staging/ (future placeholder)
  helm/ (optional umbrella or value overrides)
  scripts/
    kind_bootstrap.sh
    k3d_bootstrap.sh
    label_nodes.sh
    apply_all.sh
    teardown.sh
    verify.sh
    backup_clickhouse.sh
    restore_clickhouse.sh
    rotate_secrets.sh
  policies/
    opa/
      deny-excess-privileges.rego
      restrict-hostpath.rego
    conftest/
  config/
    cluster-config.yaml
    kind-cluster.yaml
    k3d-cluster.yaml
    ingress-values.yaml
  manifests/
    (Generated or static compiled configs)
  backups/
    (Metadata, not actual dumps)
  Makefile
  .agent/context.yaml
  README.md
  CHANGELOG.md
```

---

## 5. Environments & Promotion Model

| Environment | Purpose | Execution Mode | Promotion Source |
|-------------|---------|---------------|------------------|
| local | Primary dev & experimentation | kind/k3d + host processes | N/A |
| dev (future) | Shared integration | Real K8s cluster | Tagged infra modules |
| staging (future) | Pre‑prod validation | Real K8s | dev after drift-free |
| prod (future) | Mission operation | Multi-region | staging after SLO stable |

Local clusters rely on the Rancher `local-path` CSI provisioner (works for both kind and k3d). Staging/prod will migrate to network-attached or SSD-backed PV classes.

---

## 6. Local Cluster (3-Node Hybrid)

Nodes:
1. Linux x86_64 (control-plane + data services affinity).
2. macOS ARM #1 (GPU candidate, label: `arch=arm64, accelerator=gpu, role=ml`).
3. macOS ARM #2 (general ARM workloads, label: `arch=arm64, role=general`).

Local simulation uses kind (`config/kind-cluster.yaml` + `scripts/kind_bootstrap.sh`) to spin up a 3-node cluster (1 control-plane, 2 workers) with equivalent scheduling labels applied via `scripts/label_nodes.sh`.

Node Labeling Script: `scripts/label_nodes.sh`

Example Labels Applied:
| Label | Value |
|-------|-------|
| arch | amd64 / arm64 |
| accelerator | gpu (if available) |
| role | core | ml | general |
| zone | local-a |

Taints (optional):
- `role=core:NoSchedule` for control-plane pref workloads.
- GPU node toleration for ML pods.

---

## 7. Kubernetes Layout & Namespaces

| Namespace | Purpose |
|-----------|---------|
| kube-system | Control plane (managed) |
| platform-core | Core services (auth, entitlements, metrics) |
| data-plane | Data layer (postgres, clickhouse, kafka, redis) |
| storage | MinIO & related |
| ml | MLflow, model-serving, embedding/search (when deployed) |
| ingestion | Airflow / connectors / seatunnel (if running here) |
| observability | Prometheus, Grafana, Loki (if added), OTel collector |
| security | Policy controllers, OPA |
| backup | Backup jobs & retention logic |

Network Policies: Default deny east-west except required ports & explicit allowances.

---

## 8. Core Platform Components

| Component | Deployment | Storage/PV | Notes |
|-----------|-----------|------------|-------|
| PostgreSQL | StatefulSet | 1 × PVC | Transactional metadata |
| ClickHouse | StatefulSet (single shard early) | 1 × PVC (fast disk preferred) | Time-series + analytics |
| Redis | Deployment/StatefulSet | Ephemeral ok (dev) | Caching only |
| Kafka | Single-broker (dev) | 1 × PVC | Zookeeper-less (e.g., Redpanda optional later) |
| MinIO | StatefulSet | 1 × PVC | MLflow artifacts, backups |
| Keycloak | Deployment | PVC (postgres external) | Auth provider |
| MLflow | Deployment | Uses Postgres + MinIO | Tracking |
| OTel Collector | Deployment | - | Tracing pipeline |
| Prometheus Stack | Helm chart | PV for TSDB | Metrics |
| Backup Jobs | CronJob | - | Snapshots to MinIO |

---

## 9. Terraform Module Design

Even for local, modules mimic cloud patterns:

```text
terraform/modules/
  k8s_cluster/          # (future: EKS/GKE variant)
  clickhouse/
    main.tf
    variables.tf
  postgresql/
  redis/
  kafka/
  minio/
  keycloak/
  mlflow/
  observability/
  storage/
```

Module Interface Example (clickhouse):
```hcl
variable "namespace" { type = string }
variable "storage_size" { type = string default = "50Gi" }
variable "replicas" { type = number default = 1 }
output "service_name" { value = "clickhouse" }
```

Stacks:
- `stacks/local` stitches modules + outputs kube YAML.
- `stacks/hybrid` placeholder for evolving infrastructure (cloud modules + local bridging).

---

## 10. GitOps & Deployment Flow

Two Options (choose one or dual):

| Approach | Tool | Pros | Cons |
|----------|------|------|------|
| Push-based | `make apply` + kubectl | Simple, direct | Harder audit |
| Pull-based (recommended future) | ArgoCD or Flux | Drift detection, rollback | Initial overhead |

Suggested Transition:
1. Phase 1: Manual `kubectl apply -k k8s/overlays/local`.
2. Phase 2: Introduce ArgoCD pointing at environment overlay directory.
3. Phase 3: ArgoCD ApplicationSet for multi-environment expansions.

---

## 11. Secrets & Configuration Management

**SOPS (default)**
- `.sops.yaml` defines Age-backed creation rules for `secrets/`, `k8s/**/secrets/`, Terraform `*.tfvars`, and the walkthrough assets under `examples/sops/`.
- Generate your own Age key with `age-keygen -o ~/.config/sops/age/keys.txt` (or reuse an existing team key) and add the public recipient to `.sops.yaml`.
- `examples/sops/demo.agekey` is a demo-only private key; use it to explore the flow, then replace with your personal key before committing real secrets.
- Walkthrough manifests live at `examples/sops/demo-secret.plain.yaml` (source) and `examples/sops/demo-secret.enc.yaml` (encrypted). Keep plaintext helpers as `*.plain.yaml` and commit only the encrypted variants.
- Encrypt new files in place: `cp path/to/secret.yaml path/to/secret.enc.yaml && sops --encrypt --in-place path/to/secret.enc.yaml`.
- Decrypt with an explicit key file: `SOPS_AGE_KEY_FILE=examples/sops/demo.agekey sops --decrypt examples/sops/demo-secret.enc.yaml`.

**Kubernetes Secrets (bootstrap)**
- Plain K8s secrets remain available for quick local smoke tests, but they are base64 only—prefer migrating them into SOPS-managed overlays.

**External Secrets (roadmap)**
- Longer term we will integrate with cloud secret managers via External Secrets Operator once cloud landing zones are ready.

**Helpers**
- `scripts/rotate_secrets.sh` will re-encrypt all tracked files when recipients change.
- `secrets/` remains gitignored; never commit production credentials, only encrypted artefacts or `.example` templates.

---

## 12. Networking & Ingress Topology

- Ingress Controller: NGINX (initial).
- (Future) Add MetalLB for LoadBalancer semantics if multi-host.
- Internal DNS conventions:
  - `api.local.254carbon` → Gateway
  - `stream.local.254carbon` → Streaming
  - `mlflow.local.254carbon` → MLflow
  - `keycloak.local.254carbon` → Keycloak

TLS (Optional for Local):
- Self-signed CA via mkcert
- Cert-manager installation path (future overlay)

---

## 13. Storage, Persistence & Data Classes

| Data Type | Storage Class | Retention |
|-----------|---------------|-----------|
| ClickHouse primary | fast-local (`rancher.io/local-path`, WaitForFirstConsumer) | 90d raw, TTLs |
| PostgreSQL metadata | standard-local (`rancher.io/local-path`) | Indefinite (backups) |
| MinIO artifacts | standard-local (`rancher.io/local-path`) | Configurable lifecycle |
| Kafka logs | standard-local (`rancher.io/local-path`) | 7d retention (topic-level) |
| Redis | memory + ephemeral | No persistence required early |
| Backups | backup-storage (`rancher.io/local-path`, Retain) | MinIO lifecycle rules |

Data tier classification:
- Tier 0: Critical (Postgres schema & MinIO artifacts, ClickHouse metadata)
- Tier 1: Recomputable (Cache, Kafka streams)
- Tier 2: Synthetic (Derived views, projections)

Storage verification (local):
- `make verify` confirms `standard-local`, `fast-local`, and `backup-storage` are backed by the `rancher.io/local-path` provisioner on both kind and k3d clusters.

---

## 14. Backup & Restore Strategy

For the step-by-step operational checklist, see `docs/backup-restore-runbook.md`.

| Component | Backup Method | Frequency | Tooling |
|-----------|---------------|----------|---------|
| PostgreSQL | pg_dump (logical) | Daily | CronJob |
| ClickHouse | `clickhouse-backup` | Daily + retention policy | CronJob (already present style) |
| MinIO | Versioned bucket (enable) | Continuous | MinIO lifecycle rules |
| Kafka (optional) | Snapshot export (low priority early) | Manual | Future |
| MLflow Artifacts | Covered by MinIO | N/A | Same policy |

Restore Steps (Example ClickHouse):
```bash
kubectl exec -it clickhouse-0 -- clickhouse-backup list
kubectl exec -it clickhouse-0 -- clickhouse-backup restore latest
```

Retention Policy:
- Keep last 7 daily
- Keep 4 weekly
- Keep 3 monthly (configurable in backup CronJob env)

Implementation Notes:
- CronJobs (`clickhouse-backup`, `postgres-backup`) stream artifacts to MinIO prefixes `backups/<component>/<tier>/`.
- `minio-backup-maintenance` ensures the `backups` bucket exists, versioning is enabled, and lifecycle rules enforce the tiered retention windows.

---

## 15. Observability Integration (Metrics, Logs, Traces)

| Layer | Tool | Notes |
|-------|------|-------|
| Metrics | Prometheus + Grafana | K8s cluster + app scraping |
| Tracing | OpenTelemetry Collector | Exports to Tempo/Jaeger (future) |
| Logs (future) | Loki / OpenSearch | Structured JSON correlation |
| Alerts | Alertmanager rules | SLO burn + component readiness |

Metrics Naming Baseline:
- infra_* (node, cluster)
- db_* (clickhouse_, postgres_)
- mq_* (kafka_)
- objstore_* (minio_)
- auth_* (keycloak_)

---

## 16. Security & Policy Enforcement

Baseline (Local):
- Pod Security (restricted profile) where possible
- NetworkPolicies isolate namespaces
- No privileged pods (except where unavoidable: low-level system components)
- OPA/Conftest policies (advisory first, enforcing later)

Policies (examples):
- `deny-excess-privileges.rego`: Block privileged & hostPID/IPC
- `restrict-hostpath.rego`: Warn/deny unsanctioned hostPath mounts
- Image registry allowlist: ghcr.io/254carbon/*

Future Additions:
- gVisor / Kata containers for sandboxed analytics workloads
- Sigstore cosign verification gates

---

## 17. Multi-Arch & Heterogeneous Scheduling

Node Affinity Example (ML Pods → GPU ARM Mac):
```yaml
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
        - matchExpressions:
            - key: arch
              operator: In
              values: ["arm64"]
            - key: accelerator
              operator: In
              values: ["gpu"]
```

Tolerations:
```yaml
tolerations:
  - key: "role"
    operator: "Equal"
    value: "ml"
    effect: "NoSchedule"
```

Images:
- All application repos publish `linux/amd64,linux/arm64` multi-arch images.
- Data services (Kafka, ClickHouse) may remain amd64 → pin to Linux node via nodeSelector.

---

## 18. Resource Naming & Tagging Conventions

Naming Convention:
```text
<system>-<component>-<role>-<suffix>
```
Examples:
- `mi-clickhouse-sts`
- `mi-postgres-pvc`
- `ml-embedding-deploy`

Labels:
| Key | Purpose | Example |
|-----|---------|---------|
| app | Component identity | clickhouse |
| tier | Layer classification | data |
| domain | Domain grouping | ml / access / ingestion |
| managed-by | Provisioning tool | terraform / helm / kustomize |
| version | Release tracking | 1.0.0 |

Annotations:
- `observability.254carbon.io/scrape: "true"`
- `security.254carbon.io/profile: restricted`
- `maintenance.254carbon.io/backup: daily`

---

## 19. Automation Scripts & Make Targets

Make Targets (suggested):
| Target | Action |
|--------|--------|
| make k3d-up | Bootstrap k3d multi-node cluster (default) |
| make k3d-down | Destroy k3d cluster |
| make kind-up | Bootstrap kind multi-node cluster (alternative) |
| make kind-down | Destroy kind cluster |
| make k8s-apply-base | Apply base infra (namespaces, policies) |
| make k8s-apply-platform | Deploy data + platform components |
| make verify | Run cluster health + storage verification script |
| make validate | Render Kustomize overlays, run kubeconform & Conftest, Terraform fmt/validate |
| make backup-run | Trigger ad-hoc backup jobs |
| make drift-check | Validate terraform + k8s drift |
| make clean | Remove temp artifacts |

Scripts:
- `kind_bootstrap.sh`: Creates kind cluster w/ worker node labels.
- `k3d_bootstrap.sh`: Alternative k3d cluster bootstrap (mirrors layout).
- `apply_all.sh`: Ordered apply (base → data → platform).
- `verify.sh`: Validates storage classes and checks critical endpoints/liveness.
- `backup_clickhouse.sh`: Manual snapshot invoker.

---

## 20. CI/CD Pipeline (Infra Changes)

Pipeline Stages:
1. Lint & Format (Terraform fmt/validate, Kustomize render, kubeconform schema checks)
2. Security Scan (tfsec, kube-score)
3. Policy Check (Conftest OPA)
4. Terraform Plan (for applicable stacks)
5. Preview Comment (Plan & diff summary)
6. Manual Approval (for non-local stacks)
7. Apply (auto for local, gated for future envs)
8. Post-Apply Drift Snapshot (JSON artifact)

Branch Protections:
- `main` requires 1 approval + passing policy gates.

---

## 21. Drift Detection & Guard Rails

Tools:
- `terraform plan` scheduled (cron GitHub Action)
- `kubectl diff` against rendered manifests
- OPA policies for regression (e.g., addition of privileged pods)
- Alert on drift (issue auto-created in infra repo)

Example OPA Policy (pseudocode):
```rego
deny[msg] {
  input.kind == "Pod"
  input.spec.containers[_].securityContext.privileged == true
  msg = "Privileged pods not allowed"
}
```

---

## 22. Disaster Recovery & Resilience (Roadmap)

| Item | Current | Target |
|------|---------|--------|
| Backups | Logical + ClickHouse snapshot | Multi-copy, off-site |
| Kafka durability | Single broker | 3+ broker replication |
| ClickHouse HA | Single node | Replicated shards |
| Postgres HA | Single primary | Patroni/Crunchy cluster |
| Object storage | Single MinIO instance | Distributed MinIO set |
| Multi-region | Not implemented | Active/passive replication |

RPO/RTO (Draft Targets Future):
- RPO: ≤ 15m (metadata)
- RTO: ≤ 1h (core services)

---

## 23. Cost / Resource Footprint Awareness (Local)

Resource Classes:
| Component | CPU | Memory | Notes |
|-----------|-----|--------|------|
| Postgres | 0.5–1 core | 1–2 Gi | Tune shared buffers ~25% mem |
| ClickHouse | 1–2 cores | 2–4 Gi | Column compression reduces disk |
| Kafka | 1 core | 1–2 Gi | Single broker only |
| MinIO | 0.5–1 core | 512 Mi–1 Gi | Depends on artifact volume |
| Keycloak | 0.5–1 core | 512 Mi–1 Gi | Enable DB connection pooling |
| MLflow | 0.25 core | 256–512 Mi | Lightweight |
| OTel Collector | 0.25 core | 256 Mi | Batch export tuned |
| Prometheus | 0.5–1 core | 1–2 Gi | Retention trimmed (e.g., 15d) |

---

## 24. Future Cloud Migration Blueprint

| Capability | Local Strategy | Cloud Evolution |
|------------|----------------|-----------------|
| Cluster | kind/k3d | Managed K8s (EKS/GKE) |
| Storage | Rancher local-path CSI | EBS / PD / CSI |
| Secrets | Manual / K8s | AWS/GCP Secret Manager + ExternalSecrets |
| Ingress | NGINX | Cloud LB + Ingress Controller |
| Observability | Self-hosted | Managed (CloudWatch / GCP Ops + Tempo/Loki) |
| Backups | MinIO internal | Cross-region object storage replication |
| Identity | Keycloak | Keycloak HA / External IdP integration |
| Terraform backend | Local state | Remote state (S3 + DynamoDB / GCS) |
| GitOps | ArgoCD | ArgoCD multi-cluster ApplicationSet |

---

## 25. Contribution Workflow

1. Create feature branch.
2. Change infra module / k8s overlays / policies.
3. Run local validation:
   ```bash
   make validate
   make plan   # (Terraform plan)
   make k8s-dry-run
   ```
4. Open PR (attach plan output).
5. Address policy & security scan results.
6. Merge after approval; CI runs apply for `local` (or queue for approval in higher environments).

Commit Message Examples:
- `feat(clickhouse): add TTL policy for bronze ticks`
- `chore(observability): increase scrape interval`
- `fix(keycloak): correct admin svc port`

---

## 26. Troubleshooting Matrix

For the full incident triage playbook, see `docs/troubleshooting-runbook.md`.

| Issue | Symptom | Diagnostics | Resolution |
|-------|---------|-------------|-----------|
| ClickHouse pod crashloop | Fails on start | `kubectl logs` → config parse error | Validate configmap syntax |
| Kafka unreachable | Gateway cannot consume | `kubectl exec -it kafka -- kafka-topics --list` | Restart pod / check service DNS |
| MinIO upload fails | MLflow artifact errors 500 | `kubectl logs minio` | Check access key secret / disk full |
| Keycloak auth failure | 401 from Auth svc | `curl keycloak:8080/realms/<realm>` | Realm misconfig or Keycloak restart |
| Prometheus missing metrics | Grafana panels empty | `curl prometheus/api/v1/targets` | Fix ServiceMonitor labels |
| OPA policy blocking deploy | Apply fails | See admission webhook logs | Adjust policy or add annotation override |
| Node scheduling failure | Pod Pending | `kubectl describe pod` | Adjust affinity/taints or add node labels |

---

## 27. Roadmap

| Milestone | Description | Status |
|-----------|-------------|--------|
| M1 | Baseline local cluster automation | In progress |
| M2 | Policy enforcement (OPA advisory) | Planned |
| M3 | GitOps introduction (ArgoCD) | Planned |
| M4 | HA data services prototype (ClickHouse replicated) | Future |
| M5 | Observability: full log aggregation (Loki) | Future |
| M6 | Security scanning integration (Trivy + Cosign) | Future |
| M7 | Cloud provider overlay modules | Future |
| M8 | Disaster recovery rehearsal scripts | Future |

---

## 28. Changelog Template

```markdown
## [1.2.0] - 2025-10-08
### Added
- clickhouse: TTL for raw ticks (90d)
- observability: Added OTel Collector config

### Changed
- kafka: updated retention to 7d
- postgres: increased shared buffers to 256MB

### Fixed
- keycloak pvc size mismatch

### Deprecated
- legacy ingress config (removed in 1.3.0)

### Security
- OPA policy blocking hostPath usage
```

---

## 29. License / Ownership

- Internal repository until cloud transition.
- Ownership: Platform Engineering (single developer + AI agents).
- Future externalization only for neutral Helm charts or generalized Terraform modules (if desired).

---

> “Infrastructure should feel like a stable substrate: **predictable**, **observable**, and **quiet**—empowering rapid iteration above it.”
