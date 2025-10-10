# Local Stack - 254Carbon Infrastructure
# Deploys all components for local k3d cluster

terraform {
  required_version = ">= 1.0"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

# Configure Kubernetes provider
provider "kubernetes" {
  config_path = "~/.kube/config"
}

# Local variables
locals {
  environment = "local"
  cluster_name = "local-254carbon"

  # Generate random passwords for local development
  postgres_password = "postgres123"
  clickhouse_password = "clickhouse123"
  redis_password = "redis123"
  kafka_password = "kafka123"
  minio_access_key = "minioadmin"
  minio_secret_key = "minioadmin123"
  keycloak_admin_password = "admin123"
  grafana_admin_password = "admin123"
}

# Deploy storage classes
module "storage" {
  source = "../../modules/storage"

  environment = local.environment
  cluster_name = local.cluster_name
}

# Deploy Kubernetes cluster resources
module "k8s_cluster" {
  source = "../../modules/k8s_cluster"

  environment = local.environment
  cluster_name = local.cluster_name
}

# Deploy PostgreSQL
module "postgresql" {
  source = "../../modules/postgresql"

  namespace = module.k8s_cluster.data_plane_namespace
  password = local.postgres_password
}

# Deploy ClickHouse
module "clickhouse" {
  source = "../../modules/clickhouse"

  namespace = module.k8s_cluster.data_plane_namespace
  password = local.clickhouse_password
}

# Deploy Redis
module "redis" {
  source = "../../modules/redis"

  namespace = module.k8s_cluster.data_plane_namespace
  password = local.redis_password
}

# Deploy Kafka
module "kafka" {
  source = "../../modules/kafka"

  namespace = module.k8s_cluster.data_plane_namespace
  password = local.kafka_password
}

# Deploy MinIO
module "minio" {
  source = "../../modules/minio"

  namespace = module.k8s_cluster.storage_namespace
  access_key = local.minio_access_key
  secret_key = local.minio_secret_key
}

# Deploy Keycloak
module "keycloak" {
  source = "../../modules/keycloak"

  namespace = module.k8s_cluster.platform_core_namespace
  admin_password = local.keycloak_admin_password
}


# Deploy Observability Stack
module "observability" {
  source = "../../modules/observability"

  namespace = module.k8s_cluster.observability_namespace
  grafana_admin_password = local.grafana_admin_password
}
