variable "namespace" {
  description = "Kubernetes namespace for Keycloak"
  type        = string
}

variable "replicas" {
  description = "Number of Keycloak replicas"
  type        = number
  default     = 1
}

variable "image" {
  description = "Keycloak Docker image"
  type        = string
  default     = "quay.io/keycloak/keycloak:latest"
}

variable "admin_password" {
  description = "Keycloak admin password"
  type        = string
  sensitive   = true
}

variable "cpu_request" {
  description = "CPU request for Keycloak container"
  type        = string
  default     = "500m"
}

variable "memory_request" {
  description = "Memory request for Keycloak container"
  type        = string
  default     = "512Mi"
}

variable "cpu_limit" {
  description = "CPU limit for Keycloak container"
  type        = string
  default     = "1"
}

variable "memory_limit" {
  description = "Memory limit for Keycloak container"
  type        = string
  default     = "1Gi"
}
