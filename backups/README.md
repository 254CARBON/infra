# Backups Directory

This directory contains backup metadata and configuration files for the 254Carbon infrastructure.

## Contents

- Backup job configurations
- Retention policies
- Restore procedures
- Backup verification scripts

## Backup Components

### ClickHouse
- **Schedule**: Daily at 2:00 AM (CronJob `clickhouse-backup` in `backup` namespace)
- **Method**: `clickhouse-backup` container with S3 upload
- **Retention**: Tiered (7 daily, 4 weekly, 3 monthly) handled via MinIO lifecycle
- **Storage**: MinIO bucket `backups/clickhouse/<tier>/`

### PostgreSQL
- **Schedule**: Daily at 3:00 AM (CronJob `postgres-backup` in `backup` namespace)
- **Method**: `pg_dump` piped to compressed artifact
- **Retention**: Tiered (7 daily, 4 weekly, 3 monthly) handled via MinIO lifecycle
- **Storage**: MinIO bucket `backups/postgres/<tier>/`

### MinIO
- **Method**: Versioned bucket with lifecycle rules (`minio-backup-maintenance` CronJob)
- **Retention**: 7d daily, 28d weekly, 95d monthly expirations
- **Storage**: Cross-region replication (future)

## Manual Backup Commands

```bash
# ClickHouse backup
kubectl exec -it clickhouse-0 -n data-plane -- clickhouse-backup create manual-$(date +%Y%m%d-%H%M%S)
# Upload manual backup (matches automated layout)
kubectl exec -it clickhouse-0 -n data-plane -- clickhouse-backup upload manual-<timestamp>

# PostgreSQL backup
kubectl exec -it postgresql-0 -n data-plane -- pg_dump -U postgres 254carbon > backup-$(date +%Y%m%d-%H%M%S).sql
```

## Restore Commands

```bash
# ClickHouse restore
kubectl exec -it clickhouse-0 -n data-plane -- clickhouse-backup restore latest

# PostgreSQL restore
kubectl exec -i postgresql-0 -n data-plane -- psql -U postgres 254carbon < backup-file.sql
```

## Verification

Run backup verification:
```bash
make verify
```

This will check:
- Backup job status
- Storage availability
- Restore capability
- Data integrity
