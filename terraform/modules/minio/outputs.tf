output "service_name" {
  description = "Name of the MinIO service"
  value       = kubernetes_service.minio.metadata[0].name
}

output "api_port" {
  description = "API port of the MinIO service"
  value       = kubernetes_service.minio.spec[0].port[0].port
}

output "console_port" {
  description = "Console port of the MinIO service"
  value       = kubernetes_service.minio.spec[0].port[1].port
}

output "namespace" {
  description = "Namespace where MinIO is deployed"
  value       = var.namespace
}
