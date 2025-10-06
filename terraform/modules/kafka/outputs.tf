output "service_name" {
  description = "Name of the Kafka service"
  value       = kubernetes_service.kafka.metadata[0].name
}

output "service_port" {
  description = "Port of the Kafka service"
  value       = kubernetes_service.kafka.spec[0].port[0].port
}

output "namespace" {
  description = "Namespace where Kafka is deployed"
  value       = var.namespace
}
