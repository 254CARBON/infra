# Backups Directory

This directory contains backup metadata and configuration files for the 254Carbon infrastructure.

## Contents

- Backup job configurations
- Retention policies
- Restore procedures
- Backup verification scripts

## Backup Components

### ClickHouse
- **Schedule**: Daily at 2:00 AM
- **Method**: `clickhouse-backup` tool
- **Retention**: 7 daily, 4 weekly, 3 monthly
- **Storage**: MinIO bucket `backups/clickhouse/`

### PostgreSQL
- **Schedule**: Daily at 3:00 AM
- **Method**: `pg_dump` logical backup
- **Retention**: 30 days
- **Storage**: MinIO bucket `backups/postgres/`

### MinIO
- **Method**: Versioned bucket with lifecycle rules
- **Retention**: Configurable via lifecycle policies
- **Storage**: Cross-region replication (future)

## Manual Backup Commands

```bash
# ClickHouse backup
kubectl exec -it clickhouse-0 -n data-plane -- clickhouse-backup create manual-$(date +%Y%m%d-%H%M%S)

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
