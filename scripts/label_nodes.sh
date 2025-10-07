#!/usr/bin/env bash
set -euo pipefail

# Node Labeling Script for 254Carbon kind/k3d clusters
# Applies labels for heterogeneous scheduling (ARM + AMD64)

CONTEXT=${1:-}
if [ -n "${CONTEXT}" ]; then
    KUBECTL=(kubectl --context "${CONTEXT}")
else
    KUBECTL=(kubectl)
fi

echo "🏷️  Labeling cluster nodes..."

# Gather nodes in deterministic order for consistent role assignment
mapfile -t NODES < <("${KUBECTL[@]}" get nodes -o name | sed 's#node/##' | sort)

WORKER_INDEX=0
for node in "${NODES[@]}"; do
    echo "Labeling node: ${node}"

    ARCH=$("${KUBECTL[@]}" get node "${node}" -o jsonpath='{.status.nodeInfo.architecture}')
    "${KUBECTL[@]}" label node "${node}" arch="${ARCH}" --overwrite
    "${KUBECTL[@]}" label node "${node}" zone="local-a" --overwrite

    if [[ "${node}" == *"server"* ]] || [[ "${node}" == *"master"* ]] || [[ "${node}" == *"control-plane"* ]]; then
        "${KUBECTL[@]}" label node "${node}" role="core" --overwrite
        "${KUBECTL[@]}" label node "${node}" accelerator- >/dev/null 2>&1 || true
    else
        if [ "${WORKER_INDEX}" -eq 0 ]; then
            "${KUBECTL[@]}" label node "${node}" role="ml" accelerator="gpu" --overwrite
        else
            "${KUBECTL[@]}" label node "${node}" role="general" --overwrite
            "${KUBECTL[@]}" label node "${node}" accelerator- >/dev/null 2>&1 || true
        fi
        WORKER_INDEX=$((WORKER_INDEX + 1))
    fi

    ROLE=$("${KUBECTL[@]}" get node "${node}" -o jsonpath='{.metadata.labels.role}')
    echo "✅ ${node}: arch=${ARCH}, role=${ROLE}"
done

echo "🎉 Node labeling complete!"
echo "📋 Current node labels:"
"${KUBECTL[@]}" get nodes --show-labels
