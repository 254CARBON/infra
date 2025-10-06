variable "namespace" {
  description = "Kubernetes namespace for Redis"
  type        = string
}

variable "replicas" {
  description = "Number of Redis replicas"
  type        = number
  default     = 1
}

variable "image" {
  description = "Redis Docker image"
  type        = string
  default     = "redis:7-alpine"
}

variable "password" {
  description = "Redis password"
  type        = string
  sensitive   = true
}

variable "cpu_request" {
  description = "CPU request for Redis container"
  type        = string
  default     = "100m"
}

variable "memory_request" {
  description = "Memory request for Redis container"
  type        = string
  default     = "256Mi"
}

variable "cpu_limit" {
  description = "CPU limit for Redis container"
  type        = string
  default     = "500m"
}

variable "memory_limit" {
  description = "Memory limit for Redis container"
  type        = string
  default     = "512Mi"
}
