variable "namespace" {
  description = "Kubernetes namespace for Kafka"
  type        = string
}

variable "storage_size" {
  description = "Size of the persistent volume for Kafka"
  type        = string
  default     = "10Gi"
}

variable "storage_class" {
  description = "Storage class for Kafka persistent volume"
  type        = string
  default     = "standard-local"
}

variable "replicas" {
  description = "Number of Kafka replicas"
  type        = number
  default     = 1
}

variable "image" {
  description = "Kafka Docker image"
  type        = string
  default     = "confluentinc/cp-kafka:latest"
}

variable "password" {
  description = "Kafka password"
  type        = string
  sensitive   = true
}

variable "cpu_request" {
  description = "CPU request for Kafka container"
  type        = string
  default     = "1"
}

variable "memory_request" {
  description = "Memory request for Kafka container"
  type        = string
  default     = "1Gi"
}

variable "cpu_limit" {
  description = "CPU limit for Kafka container"
  type        = string
  default     = "2"
}

variable "memory_limit" {
  description = "Memory limit for Kafka container"
  type        = string
  default     = "2Gi"
}
