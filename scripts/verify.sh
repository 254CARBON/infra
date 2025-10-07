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

# Container image to use for in-cluster HTTP checks
CURL_IMAGE="${CURL_IMAGE:-curlimages/curl:8.00.1}"

# Function to check if kubectl is available and cluster is reachable
check_cluster() {
    if ! kubectl cluster-info &> /dev/null; then
        echo -e "${RED}❌ Kubernetes cluster is not reachable${NC}"
        return 1
    fi
    echo -e "${GREEN}✅ Cluster is reachable${NC}"
    return 0
}

# Function to validate storage class provisioner and binding mode
check_storage_class() {
    local sc_name=$1
    local expected_provisioner=$2

    if ! kubectl get storageclass "${sc_name}" >/dev/null 2>&1; then
        echo -e "${RED}❌ StorageClass ${sc_name} not found${NC}"
        return 1
    fi

    local provisioner
    provisioner=$(kubectl get storageclass "${sc_name}" -o jsonpath='{.provisioner}')
    local binding_mode
    binding_mode=$(kubectl get storageclass "${sc_name}" -o jsonpath='{.volumeBindingMode}')

    local status=0
    if [ "${provisioner}" != "${expected_provisioner}" ]; then
        echo -e "${RED}❌ ${sc_name}: expected provisioner ${expected_provisioner}, found ${provisioner}${NC}"
        status=1
    fi

    if [ "${binding_mode}" != "WaitForFirstConsumer" ]; then
        echo -e "${YELLOW}⚠️  ${sc_name}: volumeBindingMode is ${binding_mode}, expected WaitForFirstConsumer${NC}"
        status=1
    fi

    if [ "${status}" -eq 0 ]; then
        echo -e "${GREEN}✅ ${sc_name}: provisioner ${provisioner}, binding ${binding_mode}${NC}"
    fi

    return "${status}"
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
    local get_args=()
    local wait_args=()
    local descriptor="$namespace"

    if [ -n "$app_label" ]; then
        get_args=(-l "app.kubernetes.io/name=${app_label}")
        wait_args=(-l "app.kubernetes.io/name=${app_label}")
        descriptor="$namespace (app=${app_label})"
    else
        wait_args=(--all)
    fi

    local pod_table
    if ! pod_table=$(kubectl get pods -n "$namespace" "${get_args[@]}" --no-headers 2>/dev/null); then
        echo -e "${RED}❌ Unable to list pods in ${descriptor}${NC}"
        return 1
    fi

    pod_table=$(printf "%s\n" "$pod_table" | sed '/^$/d')
    local pods
    if [ -n "$pod_table" ]; then
        pods=$(printf "%s\n" "$pod_table" | wc -l | tr -d ' ')
    else
        pods=0
    fi

    if [ "$pods" -eq 0 ]; then
        echo -e "${YELLOW}⚠️  No pods found in ${descriptor}${NC}"
        return 1
    fi

    if kubectl wait --for=condition=Ready pod -n "$namespace" "${wait_args[@]}" --timeout=30s >/dev/null 2>&1; then
        echo -e "${GREEN}✅ All pods Ready in ${descriptor} (${pods}/${pods})${NC}"
        return 0
    fi

    local ready_pods
    ready_pods=$(printf "%s\n" "$pod_table" | awk '{split($2, parts, "/"); if (parts[1]==parts[2]) ready++} END {print ready+0}')
    ready_pods=${ready_pods:-0}
    echo -e "${YELLOW}⚠️  Some pods not Ready in ${descriptor} (${ready_pods}/${pods})${NC}"
    return 1
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

check_http_endpoint() {
    local namespace=$1
    local service=$2
    local path=${3:-/}
    local port=${4:-80}
    local scheme=${5:-http}
    local expected=${6:-2xx}

    if [[ "$path" != /* ]]; then
        path="/${path}"
    fi

    local fqdn="${service}.${namespace}.svc.cluster.local"
    local url="${scheme}://${fqdn}:${port}${path}"
    local job_name="http-check-${service}-$(date +%s)-$RANDOM"

    local output
    local run_status

    set +e
    output=$(kubectl run "${job_name}" --rm -i --restart=Never -n "$namespace" \
        --image="${CURL_IMAGE}" --image-pull-policy=IfNotPresent --quiet --command -- /bin/sh -c \
        "code=\$(curl -sk -o /dev/null -w \"%{http_code}\" --max-time 15 \"${url}\"); status=\$?; if [ \$status -ne 0 ]; then code=000; fi; printf 'HTTP_CODE:%s\n' \"\$code\"") 2>&1
    run_status=$?
    set -e

    local code
    code=$(printf "%s\n" "$output" | sed -n 's/.*HTTP_CODE:\([0-9]\{3\}\).*/\1/p' | tail -n1)
    if [ -z "$code" ]; then
        code="000"
    fi

    local success=1
    case "$expected" in
        2xx)
            [[ "$code" =~ ^2[0-9]{2}$ ]] && success=0
            ;;
        3xx)
            [[ "$code" =~ ^3[0-9]{2}$ ]] && success=0
            ;;
        4xx)
            [[ "$code" =~ ^4[0-9]{2}$ ]] && success=0
            ;;
        5xx)
            [[ "$code" =~ ^5[0-9]{2}$ ]] && success=0
            ;;
        *)
            [[ "$code" == "$expected" ]] && success=0
            ;;
    esac

    local target="${scheme}://${fqdn}:${port}${path}"

    if [ "$run_status" -eq 0 ] && [ "$success" -eq 0 ]; then
        echo -e "${GREEN}✅ HTTP check OK for ${target} (${code})${NC}"
        return 0
    fi

    if [ "$run_status" -ne 0 ]; then
        echo -e "${RED}❌ HTTP check failed for ${target} (kubectl run error)${NC}"
    else
        echo -e "${RED}❌ HTTP check failed for ${target} (expected ${expected}, got ${code})${NC}"
    fi

    if [ -n "$output" ]; then
        echo "    ↳ $(echo "$output" | tail -n1)"
    fi

    return 1
}

verify_otel_pipeline() {
    local namespace="observability"
    if ! kubectl get deployment otel-collector -n "$namespace" >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  OTel Collector deployment not found${NC}"
        return 1
    fi

    echo "  • Generating synthetic OTLP traffic (telemetrygen)"
    if ! kubectl run otel-telemetrygen --rm -i --restart=Never -n "$namespace" \
        --image=ghcr.io/open-telemetry/opentelemetry-collector-contrib/telemetrygen:latest \
        -- --traces --metrics --otlp-endpoint=otel-collector.${namespace}.svc.cluster.local:4317 \
        --otlp-insecure --duration=10s >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  Unable to generate OTLP test traffic (telemetrygen image unavailable)${NC}"
    else
        echo -e "${GREEN}✅ OTLP test traffic sent${NC}"
    fi

    echo "  • Scraping collector Prometheus exporter"
    local metrics
    metrics=$(kubectl run otel-metrics-sampler --rm -i --restart=Never -n "$namespace" \
        --image="${CURL_IMAGE}" --command -- \
        curl -s http://otel-collector.${namespace}.svc.cluster.local:9464/metrics 2>/dev/null || true)

    if [[ -z "$metrics" ]]; then
        echo -e "${RED}❌ Unable to scrape OTel collector metrics endpoint${NC}"
        return 1
    fi

    local accepted
    accepted=$(echo "$metrics" | awk '/otelcol_receiver_accepted_spans(_total)?/{print $2}' | tail -n1)
    if [[ -z "$accepted" ]]; then
        echo -e "${YELLOW}⚠️  OTel metrics present but no spans observed yet${NC}"
        return 1
    fi

    if awk -v val="$accepted" 'BEGIN { exit !(val > 0) }'; then
        echo -e "${GREEN}✅ OTel pipelines accepting spans (total: $accepted)${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠️  OTel pipelines active but no spans accepted${NC}"
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
echo "📋 Step 3: Storage class verification"
check_storage_class "standard-local" "rancher.io/local-path" || true
check_storage_class "fast-local" "rancher.io/local-path" || true
check_storage_class "backup-storage" "rancher.io/local-path" || true

echo ""
echo "📋 Step 4: Component health checks"

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
echo "📋 Step 5: Service endpoints"
check_service "platform-core" "keycloak" 8080 || true
check_service "ml" "mlflow" 5000 || true
check_service "observability" "grafana" 3000 || true
check_service "storage" "minio" 9000 || true

echo ""
echo "📋 Step 6: HTTP readiness endpoints"
check_http_endpoint "platform-core" "keycloak" "/health/ready" 8080 || true
check_http_endpoint "ml" "mlflow" "/health" 5000 || true
check_http_endpoint "observability" "prometheus" "/-/ready" 9090 || true
check_http_endpoint "observability" "grafana" "/api/health" 3000 || true
check_http_endpoint "storage" "minio" "/minio/health/ready" 9000 || true

echo ""
echo "📋 Step 7: OpenTelemetry pipeline verification"
verify_otel_pipeline || true

echo ""
echo "📋 Step 8: Node status"
kubectl get nodes -o wide

echo ""
echo "📋 Step 9: Resource usage"
kubectl top nodes 2>/dev/null || echo "⚠️  Metrics server not available"

echo ""
echo "🎉 Verification complete!"
echo "💡 Use 'kubectl get pods -A' to see all pods"
echo "💡 Use 'kubectl get services -A' to see all services"
