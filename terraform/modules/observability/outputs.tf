output "prometheus_service_name" {
  description = "Name of the Prometheus service"
  value       = kubernetes_service.prometheus.metadata[0].name
}

output "prometheus_service_port" {
  description = "Port of the Prometheus service"
  value       = kubernetes_service.prometheus.spec[0].port[0].port
}

output "grafana_service_name" {
  description = "Name of the Grafana service"
  value       = kubernetes_service.grafana.metadata[0].name
}

output "grafana_service_port" {
  description = "Port of the Grafana service"
  value       = kubernetes_service.grafana.spec[0].port[0].port
}

output "namespace" {
  description = "Namespace where observability components are deployed"
  value       = var.namespace
}
