#!/usr/bin/env bash
set -euo pipefail

# 254Carbon k3d Cluster Bootstrap Script
# Creates a multi-node k3d cluster with proper configuration

CLUSTER_NAME="local-254carbon"
CONFIG_FILE="config/k3d-cluster.yaml"

echo "🚀 Bootstrapping k3d cluster: $CLUSTER_NAME"

# Check if k3d is installed
if ! command -v k3d &> /dev/null; then
    echo "❌ k3d is not installed. Please install k3d first:"
    echo "   brew install k3d"
    exit 1
fi

# Check if cluster already exists
if k3d cluster list | grep -q "$CLUSTER_NAME"; then
    echo "⚠️  Cluster $CLUSTER_NAME already exists. Deleting..."
    k3d cluster delete "$CLUSTER_NAME"
fi

# Create cluster from config
echo "📋 Creating cluster from config: $CONFIG_FILE"
k3d cluster create --config "$CONFIG_FILE"

# Wait for cluster to be ready
echo "⏳ Waiting for cluster to be ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=300s

# Label nodes for heterogeneous scheduling
echo "🏷️  Labeling nodes..."
bash scripts/label_nodes.sh

# Verify cluster
echo "✅ Verifying cluster setup..."
kubectl get nodes -o wide
kubectl get pods -A

echo "🎉 k3d cluster $CLUSTER_NAME is ready!"
echo "   Use 'kubectl config use-context k3d-$CLUSTER_NAME' to switch context"
