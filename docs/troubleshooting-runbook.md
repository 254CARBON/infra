# 254Carbon Troubleshooting Runbook

Structured triage checklist for infrastructure incidents affecting the 254Carbon platform.

## When to Engage
- Monitoring alerts (Prometheus/Grafana, future PagerDuty integration)
- `make verify` failures in CI/CD or local validation
- User reports of degraded or unavailable data services

## First Response (0-5 min)
1. Acknowledge alert in incident channel.
2. Confirm Kubernetes connectivity:
   ```bash
   kubectl cluster-info
   kubectl get nodes
   ```
3. Capture current state snapshot:
   ```bash
   kubectl get pods -A -o wide > /tmp/pods-$(date +%Y%m%d-%H%M%S).log
   kubectl describe node <node> > /tmp/node-desc.log
   ```
4. Run `make verify` (or `./scripts/verify.sh`) to collect baseline health with consistent output.

## Core Diagnostics
- **Pods & Workloads**
  ```bash
  kubectl get pods -n <namespace>
  kubectl describe pod <pod>
  kubectl logs <pod> [-c container]
  ```
- **Events**
  ```bash
  kubectl get events --sort-by=.metadata.creationTimestamp | tail
  ```
- **Stateful Workloads**
  ```bash
  kubectl get pvc -n data-plane
  kubectl describe pvc <pvc>
  ```
- **Node Resources**
  ```bash
  kubectl top nodes
  kubectl top pods -A
  ```

## Observability & Tooling
- **Grafana** (`observability` namespace) for dashboards and alert rules.
- **Prometheus** for raw metrics queries (`http://prometheus.observability.svc.cluster.local:9090`).
- **OTel Collector**: use `verify.sh` step 7 to exercise pipelines.
- **MinIO Console** for storage capacity (`http://minio.storage.svc.cluster.local:9000`).
- **Make Targets**:
  - `make k8s-apply-base` to re-apply namespaces, RBAC, policies.
  - `make k8s-apply-platform` to re-apply data and platform dependencies.

## Common Incident Playbooks
| Symptom | Quick Checks | Likely Fix |
|---------|--------------|------------|
| ClickHouse pod crashloop | `kubectl logs statefulset/clickhouse -n data-plane` | Validate configmap, re-apply manifest, consider backup restore (see backup runbook) |
| Kafka unreachable | `kubectl exec -n data-plane kafka-0 -- kafka-topics.sh --list --bootstrap-server localhost:9092` | Restart pod or reapply service, inspect NodePort/ingress |
| MinIO 500 errors | `kubectl logs -n storage deployment/minio` and `mc admin info` | Check disk usage, rotate credentials, scale resources |
| Keycloak 401s | `kubectl logs -n platform-core deployment/keycloak` and `kubectl get secret keycloak-admin -n platform-core` | Restart deployment, ensure secrets current |
| Prometheus scraping gaps | `kubectl get servicemonitors -A`, `curl prometheus.../targets` | Fix service labels/selectors, reapply monitoring manifests |
| OPA admission failures | `kubectl logs -n security deploy/opa-gatekeeper` | Adjust policy or add override annotation |
| Pod Pending | `kubectl describe pod` to review tolerations/resources | Label nodes (`./scripts/label_nodes.sh`) or update resource requests |

## Remediation Patterns
- Restart deployment/statefulset:
  ```bash
  kubectl rollout restart deploy/<name> -n <namespace>
  kubectl rollout status deploy/<name> -n <namespace>
  ```
- Reconcile manifests:
  ```bash
  make k8s-apply-base
  make k8s-apply-platform
  ```
- Scale to zero during maintenance:
  ```bash
  kubectl scale deploy/<name> --replicas=0 -n <namespace>
  ```
- Re-run verification after fix:
  ```bash
  make verify
  ```

## Escalation & Handover
- If incident extends beyond 30 min or service impact spans multiple namespaces, move to dedicated incident call.
- Escalate to Platform lead if manual restore is required or data loss suspected.
- Document root cause, commands executed, and follow-up tasks in the incident retro.

## References
- Repository source of truth: `README.md` sections 14 (backup) and 26 (troubleshooting matrix).
- Detailed backup workflows: `docs/backup-restore-runbook.md`.
- Automation scripts: `scripts/verify.sh`, `scripts/backup_clickhouse.sh`, `scripts/restore_clickhouse.sh`.
