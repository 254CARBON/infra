#!/usr/bin/env bash
set -euo pipefail

# Secret Rotation Script for 254Carbon Infrastructure
# Rotates secrets and updates deployments

echo "🔐 Rotating secrets for 254Carbon infrastructure..."

# Function to generate random string
generate_secret() {
    local length=${1:-32}
    openssl rand -base64 "$length" | tr -d "=+/" | cut -c1-"$length"
}

# Function to update secret
update_secret() {
    local namespace=$1
    local secret_name=$2
    local key=$3
    local value=$4

    echo "🔄 Updating secret $secret_name in namespace $namespace"
    kubectl create secret generic "$secret_name" \
        --from-literal="$key=$value" \
        -n "$namespace" \
        --dry-run=client -o yaml | \
    kubectl apply -f -
}

# Function to restart deployment
restart_deployment() {
    local namespace=$1
    local deployment=$2

    echo "🔄 Restarting deployment $deployment in namespace $namespace"
    kubectl rollout restart deployment "$deployment" -n "$namespace"
}

# Rotate database passwords
echo "📋 Step 1: Rotating database passwords"

# PostgreSQL
POSTGRES_PASSWORD=$(generate_secret 24)
update_secret "data-plane" "postgres-credentials" "password" "$POSTGRES_PASSWORD"
restart_deployment "data-plane" "postgresql"

# ClickHouse
CLICKHOUSE_PASSWORD=$(generate_secret 24)
update_secret "data-plane" "clickhouse-credentials" "password" "$CLICKHOUSE_PASSWORD"
restart_deployment "data-plane" "clickhouse"

# Redis
REDIS_PASSWORD=$(generate_secret 24)
update_secret "data-plane" "redis-credentials" "password" "$REDIS_PASSWORD"
restart_deployment "data-plane" "redis"

# MinIO
echo "📋 Step 2: Rotating MinIO credentials"
MINIO_ACCESS_KEY=$(generate_secret 20)
MINIO_SECRET_KEY=$(generate_secret 40)
update_secret "storage" "minio-credentials" "access-key" "$MINIO_ACCESS_KEY"
update_secret "storage" "minio-credentials" "secret-key" "$MINIO_SECRET_KEY"
restart_deployment "storage" "minio"

# Keycloak
echo "📋 Step 3: Rotating Keycloak admin password"
KEYCLOAK_ADMIN_PASSWORD=$(generate_secret 24)
update_secret "platform-core" "keycloak-credentials" "admin-password" "$KEYCLOAK_ADMIN_PASSWORD"
restart_deployment "platform-core" "keycloak"

# Kafka
echo "📋 Step 4: Rotating Kafka credentials"
KAFKA_PASSWORD=$(generate_secret 24)
update_secret "data-plane" "kafka-credentials" "password" "$KAFKA_PASSWORD"
restart_deployment "data-plane" "kafka"

# Wait for deployments to be ready
echo "⏳ Waiting for deployments to be ready..."
kubectl wait --for=condition=Available deployment/postgresql -n data-plane --timeout=300s || true
kubectl wait --for=condition=Available deployment/clickhouse -n data-plane --timeout=300s || true
kubectl wait --for=condition=Available deployment/redis -n data-plane --timeout=300s || true
kubectl wait --for=condition=Available deployment/minio -n storage --timeout=300s || true
kubectl wait --for=condition=Available deployment/keycloak -n platform-core --timeout=300s || true
kubectl wait --for=condition=Available deployment/kafka -n data-plane --timeout=300s || true

echo "✅ Secret rotation complete!"
echo "💡 New credentials have been generated and applied"
echo "💡 Deployments have been restarted with new secrets"
echo "⚠️  Note: Update application configurations if they reference these secrets"
