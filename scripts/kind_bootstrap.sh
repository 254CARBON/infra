#!/usr/bin/env bash
set -euo pipefail

# 254Carbon kind Cluster Bootstrap Script
# Provisions a three-node kind cluster (1 control-plane + 2 workers)

CLUSTER_NAME="local-254carbon"
CONFIG_FILE="config/kind-cluster.yaml"
KUBECTL_CONTEXT="kind-${CLUSTER_NAME}"

echo "🚀 Bootstrapping kind cluster: ${CLUSTER_NAME}"

# Sanity checks
if ! command -v kind >/dev/null 2>&1; then
    echo "❌ kind is not installed. Install via:"
    echo "   brew install kind"
    exit 1
fi

if ! command -v kubectl >/dev/null 2>&1; then
    echo "❌ kubectl is not installed. Install via:"
    echo "   brew install kubectl"
    exit 1
fi

if [ ! -f "${CONFIG_FILE}" ]; then
    echo "❌ Missing cluster config: ${CONFIG_FILE}"
    exit 1
fi

# Delete existing cluster if present
if kind get clusters | grep -Fxq "${CLUSTER_NAME}"; then
    echo "⚠️  Existing cluster ${CLUSTER_NAME} detected. Deleting..."
    kind delete cluster --name "${CLUSTER_NAME}"
fi

# Create cluster
echo "📋 Creating cluster from ${CONFIG_FILE}"
kind create cluster --name "${CLUSTER_NAME}" --config "${CONFIG_FILE}"

# Wait for nodes to be ready
echo "⏳ Waiting for nodes to become Ready..."
kubectl --context "${KUBECTL_CONTEXT}" wait --for=condition=Ready nodes --all --timeout=300s

# Apply node labels for scheduling tiers
echo "🏷️  Applying node labels..."
bash scripts/label_nodes.sh "${KUBECTL_CONTEXT}"

# Show cluster status
echo "✅ Cluster nodes:"
kubectl --context "${KUBECTL_CONTEXT}" get nodes -o wide

echo "📦 System pods:"
kubectl --context "${KUBECTL_CONTEXT}" get pods -A

echo "🎉 kind cluster ${CLUSTER_NAME} is ready!"
echo "   kubectl config use-context ${KUBECTL_CONTEXT}"
