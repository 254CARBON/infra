output "service_name" {
  description = "Name of the Redis service"
  value       = kubernetes_service.redis.metadata[0].name
}

output "service_port" {
  description = "Port of the Redis service"
  value       = kubernetes_service.redis.spec[0].port[0].port
}

output "namespace" {
  description = "Namespace where Redis is deployed"
  value       = var.namespace
}
