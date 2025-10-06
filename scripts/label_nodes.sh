#!/usr/bin/env bash
set -euo pipefail

# Node Labeling Script for 254Carbon k3d Cluster
# Applies labels for heterogeneous scheduling (ARM + AMD64)

echo "🏷️  Labeling k3d cluster nodes..."

# Get all nodes
NODES=$(kubectl get nodes -o name | sed 's/node\///')

for node in $NODES; do
    echo "Labeling node: $node"

    # Get node info to determine architecture
    ARCH=$(kubectl get node "$node" -o jsonpath='{.status.nodeInfo.architecture}')

    # Apply architecture label
    kubectl label node "$node" arch="$ARCH" --overwrite

    # Apply zone label (all local for now)
    kubectl label node "$node" zone="local-a" --overwrite

    # Determine role based on node name/position
    if [[ "$node" == *"server"* ]] || [[ "$node" == *"master"* ]]; then
        kubectl label node "$node" role="core" --overwrite
    elif [[ "$node" == *"agent-0"* ]]; then
        # First agent: GPU candidate (ARM Mac)
        kubectl label node "$node" role="ml" accelerator="gpu" --overwrite
    else
        # Other agents: general purpose
        kubectl label node "$node" role="general" --overwrite
    fi

    echo "✅ Labeled $node: arch=$ARCH, role=$(kubectl get node "$node" -o jsonpath='{.metadata.labels.role}')"
done

echo "🎉 Node labeling complete!"
echo "📋 Current node labels:"
kubectl get nodes --show-labels
