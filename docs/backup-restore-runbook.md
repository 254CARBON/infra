# 254Carbon Backup & Restore Runbook

Operational checklist for validating, triggering, and restoring backups across the 254Carbon data plane.

## Audience & Responsibilities
- **Primary**: Platform engineering on-call
- **Secondary**: Data services maintainer (for ClickHouse/PostgreSQL specifics)
- **Escalation**: Head of Platform after two failed restore attempts or >30 min outage

## Preconditions
- `kubectl` context pointed at target cluster with admin rights
- Access to MinIO credentials (`k8s secret storage/minio-creds` or local `.mc` profile)
- Local tooling: `make`, `helm`, and `mc` (MinIO client) or S3-compatible CLI
- Sufficient disk space for temporary restore artifacts when running locally

## Backup Inventory
| Component | Mechanism | Schedule | Retention | Storage Location |
|-----------|-----------|----------|-----------|------------------|
| ClickHouse | `clickhouse-backup` CronJob (`backup` ns) | Daily 02:00 | 7 daily / 4 weekly / 3 monthly | MinIO `backups/clickhouse/<tier>/` |
| PostgreSQL | `pg_dump` CronJob (`backup` ns) | Daily 03:00 | 7 daily / 4 weekly / 3 monthly | MinIO `backups/postgres/<tier>/` |
| MinIO | Versioned bucket + lifecycle | Hourly metadata sweep | 7d daily / 28d weekly / 95d monthly | MinIO (object versioning) |

RPO target is <=15 min for metadata (future improvement). RTO target is <=60 min for core services.

## Daily / Weekly Checks
1. `make verify` (or `./scripts/verify.sh`) for high-level health.
2. Confirm CronJobs succeeded during last window:
   ```bash
   kubectl get cronjobs -n backup
   kubectl get jobs -n backup --sort-by=.status.startTime | tail
   ```
3. Inspect latest job logs if any failures:
   ```bash
   kubectl logs job/<job-name> -n backup
   ```
4. Validate backup objects exist in MinIO:
   ```bash
   mc ls minio/backups/clickhouse/daily | tail
   mc ls minio/backups/postgres/daily | tail
   ```
5. Review MinIO lifecycle status (weekly):
   ```bash
   mc ilm inspect minio/backups
   ```

## Manual Backup Procedures

### ClickHouse
1. Freeze new writes if necessary (scale down heavy writers).
2. Trigger backup:
   ```bash
   ./scripts/backup_clickhouse.sh
   ```
   The script creates and uploads `manual-<timestamp>`.
3. Confirm listing:
   ```bash
   kubectl exec -n data-plane clickhouse-0 -- clickhouse-backup list
   ```

### PostgreSQL
1. Optionally quiesce applications (set maintenance mode).
2. Run manual dump from workstation:
   ```bash
   kubectl exec -i -n data-plane postgresql-0 -- \
     pg_dump -U postgres 254carbon > postgres-backup-$(date +%Y%m%d-%H%M%S).sql
   ```
3. Upload to MinIO for retention:
   ```bash
   mc cp postgres-backup-*.sql minio/backups/postgres/manual/
   ```

### MinIO Bucket Snapshot
1. Ensure bucket versioning enabled (`mc version info minio/backups`).
2. For bulk copy to external storage:
   ```bash
   mc mirror --overwrite minio/backups s3://dr-bucket/254carbon-backups
   ```

## Restore Decision Tree
1. **Scope**  
   - Single dataset corruption -> restore component (ClickHouse or PostgreSQL).  
   - Catastrophic storage loss -> re-provision PVCs, restore both data services.
2. **Pre-restore Controls**  
   - Scale down writers or put service in maintenance.  
   - Snapshot current state if possible (`clickhouse-backup create safety-net`).  
   - Confirm backup object availability in MinIO.
3. **Select Restore Point**  
   - Prefer latest successful. For ClickHouse use `clickhouse-backup list`.  
   - For PostgreSQL pick `.sql` artifact (daily/weekly/manual).

## ClickHouse Restore
1. Verify pod ready:
   ```bash
   kubectl get pod -n data-plane clickhouse-0
   ```
2. Run restore script (defaults to `latest`):
   ```bash
   ./scripts/restore_clickhouse.sh [backup-name]
   ```
3. If restoring from remote tier, download first:
   ```bash
   kubectl exec -n data-plane clickhouse-0 -- \
     clickhouse-backup download <backup-name>
   ```
4. Post-restore checks:
   ```bash
   kubectl exec -n data-plane clickhouse-0 -- clickhouse-client --query "SELECT count(*) FROM system.tables"
   kubectl logs -n data-plane statefulset/clickhouse
   ```

## PostgreSQL Restore
1. Scale deployments depending on database (e.g., `kubectl scale deploy <consumer> --replicas=0`).
2. Load backup:
   ```bash
   kubectl exec -i -n data-plane postgresql-0 -- \
     psql -U postgres 254carbon < postgres-backup.sql
   ```
   Use `mc cp` or `kubectl cp` to place `postgres-backup.sql` inside the pod if large.
3. Vacuum/analyze after import:
   ```bash
   kubectl exec -n data-plane postgresql-0 -- \
     psql -U postgres 254carbon -c "VACUUM ANALYZE;"
   ```

## MinIO Object Restore
- Retrieve deleted object by version:
  ```bash
  mc ls --versions minio/backups/path/to/object
  mc cp minio/backups/path/to/object --versions --prompt
  ```
- For full bucket restore use `mc mirror` from replicated store back into MinIO.

## Post-Restore Validation
1. Run `make verify` to confirm pods and services healthy.
2. Execute smoke queries:
   ```bash
   kubectl exec -n data-plane clickhouse-0 -- clickhouse-client --query "SELECT 1"
   kubectl exec -n data-plane postgresql-0 -- psql -U postgres -c "SELECT 1;"
   ```
3. Re-run application integration checks (API smoke tests, Grafana dashboards).
4. Re-enable scaled down workloads.

## Escalation & Notes
- If restore fails twice, or backup artifact missing, escalate to Platform lead and initiate incident review.
- Capture timeline and commands executed for post-incident analysis.
- Create follow-up Jira for gaps (e.g., increase frequency, automate manual uploads).
