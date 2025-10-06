output "platform_core_namespace" {
  description = "Name of the platform core namespace"
  value       = kubernetes_namespace.platform_core.metadata[0].name
}

output "data_plane_namespace" {
  description = "Name of the data plane namespace"
  value       = kubernetes_namespace.data_plane.metadata[0].name
}

output "storage_namespace" {
  description = "Name of the storage namespace"
  value       = kubernetes_namespace.storage.metadata[0].name
}

output "ml_namespace" {
  description = "Name of the ML namespace"
  value       = kubernetes_namespace.ml.metadata[0].name
}

output "observability_namespace" {
  description = "Name of the observability namespace"
  value       = kubernetes_namespace.observability.metadata[0].name
}

output "security_namespace" {
  description = "Name of the security namespace"
  value       = kubernetes_namespace.security.metadata[0].name
}

output "backup_namespace" {
  description = "Name of the backup namespace"
  value       = kubernetes_namespace.backup.metadata[0].name
}

output "cluster_name" {
  description = "Name of the Kubernetes cluster"
  value       = var.cluster_name
}

output "environment" {
  description = "Environment name"
  value       = var.environment
}
