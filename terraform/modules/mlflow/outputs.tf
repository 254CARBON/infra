output "service_name" {
  description = "Name of the MLflow service"
  value       = kubernetes_service.mlflow.metadata[0].name
}

output "service_port" {
  description = "Port of the MLflow service"
  value       = kubernetes_service.mlflow.spec[0].port[0].port
}

output "namespace" {
  description = "Namespace where MLflow is deployed"
  value       = var.namespace
}
