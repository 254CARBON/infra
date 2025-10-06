output "service_name" {
  description = "Name of the Keycloak service"
  value       = kubernetes_service.keycloak.metadata[0].name
}

output "service_port" {
  description = "Port of the Keycloak service"
  value       = kubernetes_service.keycloak.spec[0].port[0].port
}

output "namespace" {
  description = "Namespace where Keycloak is deployed"
  value       = var.namespace
}
