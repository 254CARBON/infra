#!/usr/bin/env bash
set -euo pipefail

# Teardown Script for 254Carbon Infrastructure
# Gracefully removes all components and optionally destroys cluster

CLUSTER_NAME="local-254carbon"
DESTROY_CLUSTER=${1:-false}

echo "🧹 Tearing down 254Carbon infrastructure..."

# Function to check if cluster exists
cluster_exists() {
    k3d cluster list | grep -q "$CLUSTER_NAME" 2>/dev/null || return 1
}

# Function to safely delete resources
safe_delete() {
    local resource_type=$1
    local namespace=${2:-""}

    if [ -n "$namespace" ]; then
        echo "Deleting $resource_type in namespace $namespace..."
        kubectl delete "$resource_type" --all -n "$namespace" --ignore-not-found=true || true
    else
        echo "Deleting $resource_type cluster-wide..."
        kubectl delete "$resource_type" --all --ignore-not-found=true || true
    fi
}

# Check if cluster is reachable
if ! kubectl cluster-info &> /dev/null; then
    echo "⚠️  Cluster is not reachable. Proceeding with cluster deletion if requested."
    if [ "$DESTROY_CLUSTER" = "true" ] && cluster_exists; then
        echo "🗑️  Destroying k3d cluster: $CLUSTER_NAME"
        k3d cluster delete "$CLUSTER_NAME"
    fi
    exit 0
fi

echo "📋 Step 1: Removing platform services"
safe_delete "deployments" "platform-core"
safe_delete "deployments" "ml"
safe_delete "deployments" "observability"
safe_delete "deployments" "ingestion"

echo "📊 Step 2: Removing data services"
safe_delete "statefulsets" "data-plane"
safe_delete "statefulsets" "storage"

echo "🔄 Step 3: Removing backup jobs"
safe_delete "cronjobs" "backup"

echo "🔧 Step 4: Removing platform components"
kubectl delete -k k8s/platform/backup-jobs --ignore-not-found=true || true
kubectl delete -k k8s/platform/otel --ignore-not-found=true || true
kubectl delete -k k8s/platform/metrics-stack --ignore-not-found=true || true
kubectl delete -k k8s/platform/mlflow --ignore-not-found=true || true
kubectl delete -k k8s/platform/keycloak --ignore-not-found=true || true

echo "📊 Step 5: Removing data components"
kubectl delete -k k8s/platform/minio --ignore-not-found=true || true
kubectl delete -k k8s/platform/kafka --ignore-not-found=true || true
kubectl delete -k k8s/platform/redis --ignore-not-found=true || true
kubectl delete -k k8s/platform/clickhouse --ignore-not-found=true || true
kubectl delete -k k8s/platform/postgresql --ignore-not-found=true || true

echo "🏗️  Step 6: Removing base infrastructure"
kubectl delete -k k8s/base --ignore-not-found=true || true

# Optional cluster destruction
if [ "$DESTROY_CLUSTER" = "true" ]; then
    echo "🗑️  Destroying k3d cluster: $CLUSTER_NAME"
    k3d cluster delete "$CLUSTER_NAME"
    echo "✅ Cluster destroyed"
else
    echo "ℹ️  Cluster preserved. Use 'make k3d-down' to destroy it."
fi

echo "🧹 Cleanup complete!"
