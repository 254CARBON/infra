#!/usr/bin/env bash
set -euo pipefail

# ClickHouse Restore Script for 254Carbon Infrastructure
# Restores from backup using clickhouse-backup tool

NAMESPACE="data-plane"
CLICKHOUSE_POD="clickhouse-0"
BACKUP_NAME=${1:-"latest"}

echo "🔄 Starting ClickHouse restore from backup: $BACKUP_NAME"

# Check if ClickHouse pod exists
if ! kubectl get pod "$CLICKHOUSE_POD" -n "$NAMESPACE" &> /dev/null; then
    echo "❌ ClickHouse pod $CLICKHOUSE_POD not found in namespace $NAMESPACE"
    echo "   Available pods:"
    kubectl get pods -n "$NAMESPACE"
    exit 1
fi

# Check if clickhouse-backup is available
if ! kubectl exec "$CLICKHOUSE_POD" -n "$NAMESPACE" -- clickhouse-backup --help &> /dev/null; then
    echo "❌ clickhouse-backup tool not available in ClickHouse pod"
    echo "   Please ensure clickhouse-backup is installed in the ClickHouse image"
    exit 1
fi

# List available backups
echo "📋 Available backups:"
kubectl exec "$CLICKHOUSE_POD" -n "$NAMESPACE" -- clickhouse-backup list

# Confirm restore operation
if [ "$BACKUP_NAME" != "latest" ]; then
    echo "⚠️  WARNING: This will restore ClickHouse from backup $BACKUP_NAME"
    echo "   This operation will overwrite existing data!"
    read -p "   Are you sure you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Restore cancelled"
        exit 1
    fi
fi

echo "📋 Restoring from backup: $BACKUP_NAME"
kubectl exec "$CLICKHOUSE_POD" -n "$NAMESPACE" -- clickhouse-backup restore "$BACKUP_NAME"

echo "✅ Restore from $BACKUP_NAME completed successfully!"

# Verify restore
echo "📋 Verifying restore..."
kubectl exec "$CLICKHOUSE_POD" -n "$NAMESPACE" -- clickhouse-client --query "SHOW DATABASES"

echo "🎉 Restore process complete!"
