output "cluster_name" {
  description = "Name of the Kubernetes cluster"
  value       = module.k8s_cluster.cluster_name
}

output "environment" {
  description = "Environment name"
  value       = module.k8s_cluster.environment
}

output "namespaces" {
  description = "Created namespaces"
  value = {
    platform_core = module.k8s_cluster.platform_core_namespace
    data_plane    = module.k8s_cluster.data_plane_namespace
    storage       = module.k8s_cluster.storage_namespace
    ml            = module.k8s_cluster.ml_namespace
    observability = module.k8s_cluster.observability_namespace
    security      = module.k8s_cluster.security_namespace
    backup        = module.k8s_cluster.backup_namespace
  }
}

output "storage_classes" {
  description = "Created storage classes"
  value = {
    fast_local     = module.storage.fast_local_storage_class
    standard_local = module.storage.standard_local_storage_class
    backup_storage = module.storage.backup_storage_class
  }
}

output "services" {
  description = "Service endpoints"
  value = {
    postgresql = {
      name = module.postgresql.service_name
      port = module.postgresql.service_port
      namespace = module.postgresql.namespace
    }
    clickhouse = {
      name = module.clickhouse.service_name
      port = module.clickhouse.service_port
      namespace = module.clickhouse.namespace
    }
    redis = {
      name = module.redis.service_name
      port = module.redis.service_port
      namespace = module.redis.namespace
    }
    kafka = {
      name = module.kafka.service_name
      port = module.kafka.service_port
      namespace = module.kafka.namespace
    }
    minio = {
      name = module.minio.service_name
      api_port = module.minio.api_port
      console_port = module.minio.console_port
      namespace = module.minio.namespace
    }
    keycloak = {
      name = module.keycloak.service_name
      port = module.keycloak.service_port
      namespace = module.keycloak.namespace
    }
    mlflow = {
      name = module.mlflow.service_name
      port = module.mlflow.service_port
      namespace = module.mlflow.namespace
    }
    prometheus = {
      name = module.observability.prometheus_service_name
      port = module.observability.prometheus_service_port
      namespace = module.observability.namespace
    }
    grafana = {
      name = module.observability.grafana_service_name
      port = module.observability.grafana_service_port
      namespace = module.observability.namespace
    }
  }
}
