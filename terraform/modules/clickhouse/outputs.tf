output "service_name" {
  description = "Name of the ClickHouse service"
  value       = kubernetes_service.clickhouse.metadata[0].name
}

output "service_port" {
  description = "Port of the ClickHouse service"
  value       = kubernetes_service.clickhouse.spec[0].port[0].port
}

output "namespace" {
  description = "Namespace where ClickHouse is deployed"
  value       = var.namespace
}

output "stateful_set_name" {
  description = "Name of the ClickHouse StatefulSet"
  value       = kubernetes_stateful_set.clickhouse.metadata[0].name
}

output "persistent_volume_claim_name" {
  description = "Name of the ClickHouse PVC"
  value       = kubernetes_persistent_volume_claim.clickhouse_storage.metadata[0].name
}
