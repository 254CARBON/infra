#!/usr/bin/env bash
set -euo pipefail

# ClickHouse Backup Script for 254Carbon Infrastructure
# Triggers manual backup using clickhouse-backup tool

NAMESPACE="data-plane"
CLICKHOUSE_POD="clickhouse-0"
BACKUP_NAME="manual-$(date +%Y%m%d-%H%M%S)"

echo "💾 Starting ClickHouse backup: $BACKUP_NAME"

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

echo "📋 Creating backup: $BACKUP_NAME"
kubectl exec "$CLICKHOUSE_POD" -n "$NAMESPACE" -- clickhouse-backup create "$BACKUP_NAME"

echo "📋 Listing available backups:"
kubectl exec "$CLICKHOUSE_POD" -n "$NAMESPACE" -- clickhouse-backup list

echo "✅ Backup $BACKUP_NAME created successfully!"

# Optional: Upload to MinIO (if configured)
if kubectl get service "minio" -n "storage" &> /dev/null; then
    echo "📤 Uploading backup to MinIO..."
    kubectl exec "$CLICKHOUSE_POD" -n "$NAMESPACE" -- clickhouse-backup upload "$BACKUP_NAME" || {
        echo "⚠️  Failed to upload to MinIO (this is optional)"
    }
fi

echo "🎉 Backup process complete!"
