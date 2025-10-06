#!/usr/bin/env bash
set -euo pipefail

# Apply All Script for 254Carbon Infrastructure
# Ordered application: base → data → platform

echo "🚀 Applying 254Carbon infrastructure components..."

# Function to check if kubectl is available and cluster is reachable
check_cluster() {
    if ! kubectl cluster-info &> /dev/null; then
        echo "❌ Kubernetes cluster is not reachable"
        echo "   Run 'make k3d-up' to bootstrap the cluster"
        exit 1
    fi
}

# Function to wait for namespace to be ready
wait_for_namespace() {
    local namespace=$1
    echo "⏳ Waiting for namespace $namespace to be ready..."
    kubectl wait --for=condition=Active namespace "$namespace" --timeout=60s || true
}

# Check cluster connectivity
check_cluster

echo "📋 Step 1: Applying base infrastructure (namespaces, RBAC, policies)"
kubectl apply -k k8s/base

# Wait for namespaces to be active
wait_for_namespace "platform-core"
wait_for_namespace "data-plane"
wait_for_namespace "storage"
wait_for_namespace "ml"
wait_for_namespace "ingestion"
wait_for_namespace "observability"
wait_for_namespace "security"
wait_for_namespace "backup"

echo "📊 Step 2: Applying data services"
kubectl apply -k k8s/platform/postgresql
kubectl apply -k k8s/platform/clickhouse
kubectl apply -k k8s/platform/redis
kubectl apply -k k8s/platform/kafka
kubectl apply -k k8s/platform/minio

echo "🔧 Step 3: Applying platform services"
kubectl apply -k k8s/platform/keycloak
kubectl apply -k k8s/platform/mlflow
kubectl apply -k k8s/platform/metrics-stack
kubectl apply -k k8s/platform/otel

echo "🔄 Step 4: Applying backup jobs"
kubectl apply -k k8s/platform/backup-jobs

echo "✅ Infrastructure application complete!"
echo "🔍 Running verification..."
bash scripts/verify.sh
