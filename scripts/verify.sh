#!/usr/bin/env bash
set -euo pipefail

# Verification Script for 254Carbon Infrastructure
# Checks critical endpoints and component health

echo "🔍 Verifying 254Carbon infrastructure..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if kubectl is available and cluster is reachable
check_cluster() {
    if ! kubectl cluster-info &> /dev/null; then
        echo -e "${RED}❌ Kubernetes cluster is not reachable${NC}"
        return 1
    fi
    echo -e "${GREEN}✅ Cluster is reachable${NC}"
    return 0
}

# Function to check namespace exists
check_namespace() {
    local namespace=$1
    if kubectl get namespace "$namespace" &> /dev/null; then
        echo -e "${GREEN}✅ Namespace $namespace exists${NC}"
        return 0
    else
        echo -e "${RED}❌ Namespace $namespace missing${NC}"
        return 1
    fi
}

# Function to check pod readiness
check_pods() {
    local namespace=$1
    local app_label=${2:-""}

    if [ -n "$app_label" ]; then
        local pods=$(kubectl get pods -n "$namespace" -l app="$app_label" --no-headers 2>/dev/null | wc -l)
        local ready_pods=$(kubectl get pods -n "$namespace" -l app="$app_label" --no-headers 2>/dev/null | grep "Running" | wc -l)
    else
        local pods=$(kubectl get pods -n "$namespace" --no-headers 2>/dev/null | wc -l)
        local ready_pods=$(kubectl get pods -n "$namespace" --no-headers 2>/dev/null | grep "Running" | wc -l)
    fi

    if [ "$pods" -gt 0 ] && [ "$ready_pods" -eq "$pods" ]; then
        echo -e "${GREEN}✅ All pods ready in $namespace ($ready_pods/$pods)${NC}"
        return 0
    elif [ "$pods" -gt 0 ]; then
        echo -e "${YELLOW}⚠️  Some pods not ready in $namespace ($ready_pods/$pods)${NC}"
        return 1
    else
        echo -e "${YELLOW}⚠️  No pods found in $namespace${NC}"
        return 1
    fi
}

# Function to check service endpoint
check_service() {
    local namespace=$1
    local service=$2
    local port=${3:-80}

    if kubectl get service "$service" -n "$namespace" &> /dev/null; then
        local endpoint=$(kubectl get service "$service" -n "$namespace" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
        if [ -n "$endpoint" ]; then
            echo -e "${GREEN}✅ Service $service has external endpoint: $endpoint:$port${NC}"
            return 0
        else
            echo -e "${YELLOW}⚠️  Service $service exists but no external endpoint${NC}"
            return 1
        fi
    else
        echo -e "${RED}❌ Service $service not found in $namespace${NC}"
        return 1
    fi
}

# Main verification
echo "📋 Step 1: Cluster connectivity"
check_cluster || exit 1

echo ""
echo "📋 Step 2: Namespace verification"
check_namespace "platform-core"
check_namespace "data-plane"
check_namespace "storage"
check_namespace "ml"
check_namespace "observability"
check_namespace "security"
check_namespace "backup"

echo ""
echo "📋 Step 3: Component health checks"

# Check critical data services
echo "🗄️  Data Services:"
check_pods "data-plane" "postgresql" || true
check_pods "data-plane" "clickhouse" || true
check_pods "data-plane" "redis" || true
check_pods "data-plane" "kafka" || true

# Check platform services
echo "🔧 Platform Services:"
check_pods "platform-core" "keycloak" || true
check_pods "ml" "mlflow" || true
check_pods "observability" "prometheus" || true
check_pods "observability" "grafana" || true

# Check storage
echo "💾 Storage:"
check_pods "storage" "minio" || true

echo ""
echo "📋 Step 4: Service endpoints"
check_service "platform-core" "keycloak" 8080 || true
check_service "ml" "mlflow" 5000 || true
check_service "observability" "grafana" 3000 || true
check_service "storage" "minio" 9000 || true

echo ""
echo "📋 Step 5: Node status"
kubectl get nodes -o wide

echo ""
echo "📋 Step 6: Resource usage"
kubectl top nodes 2>/dev/null || echo "⚠️  Metrics server not available"

echo ""
echo "🎉 Verification complete!"
echo "💡 Use 'kubectl get pods -A' to see all pods"
echo "💡 Use 'kubectl get services -A' to see all services"
