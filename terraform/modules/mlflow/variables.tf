variable "namespace" {
  description = "Kubernetes namespace for MLflow"
  type        = string
}

variable "replicas" {
  description = "Number of MLflow replicas"
  type        = number
  default     = 1
}

variable "image" {
  description = "MLflow Docker image"
  type        = string
  default     = "python:3.9-slim"
}

variable "postgres_password" {
  description = "PostgreSQL password for MLflow backend"
  type        = string
  sensitive   = true
}

variable "cpu_request" {
  description = "CPU request for MLflow container"
  type        = string
  default     = "250m"
}

variable "memory_request" {
  description = "Memory request for MLflow container"
  type        = string
  default     = "256Mi"
}

variable "cpu_limit" {
  description = "CPU limit for MLflow container"
  type        = string
  default     = "500m"
}

variable "memory_limit" {
  description = "Memory limit for MLflow container"
  type        = string
  default     = "512Mi"
}
