output "service_name" {
  description = "Name of the PostgreSQL service"
  value       = kubernetes_service.postgresql.metadata[0].name
}

output "service_port" {
  description = "Port of the PostgreSQL service"
  value       = kubernetes_service.postgresql.spec[0].port[0].port
}

output "namespace" {
  description = "Namespace where PostgreSQL is deployed"
  value       = var.namespace
}

output "database_name" {
  description = "Name of the PostgreSQL database"
  value       = var.database_name
}

output "username" {
  description = "PostgreSQL username"
  value       = var.username
}
