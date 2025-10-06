variable "namespace" {
  description = "Kubernetes namespace for observability components"
  type        = string
}

variable "prometheus_image" {
  description = "Prometheus Docker image"
  type        = string
  default     = "prom/prometheus:latest"
}

variable "grafana_image" {
  description = "Grafana Docker image"
  type        = string
  default     = "grafana/grafana:latest"
}

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
}

variable "prometheus_cpu_request" {
  description = "CPU request for Prometheus container"
  type        = string
  default     = "500m"
}

variable "prometheus_memory_request" {
  description = "Memory request for Prometheus container"
  type        = string
  default     = "1Gi"
}

variable "prometheus_cpu_limit" {
  description = "CPU limit for Prometheus container"
  type        = string
  default     = "1"
}

variable "prometheus_memory_limit" {
  description = "Memory limit for Prometheus container"
  type        = string
  default     = "2Gi"
}

variable "grafana_cpu_request" {
  description = "CPU request for Grafana container"
  type        = string
  default     = "100m"
}

variable "grafana_memory_request" {
  description = "Memory request for Grafana container"
  type        = string
  default     = "128Mi"
}

variable "grafana_cpu_limit" {
  description = "CPU limit for Grafana container"
  type        = string
  default     = "500m"
}

variable "grafana_memory_limit" {
  description = "Memory limit for Grafana container"
  type        = string
  default     = "512Mi"
}
