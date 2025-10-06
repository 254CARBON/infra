variable "namespace" {
  description = "Kubernetes namespace for ClickHouse"
  type        = string
}

variable "storage_size" {
  description = "Size of the persistent volume for ClickHouse"
  type        = string
  default     = "50Gi"
}

variable "storage_class" {
  description = "Storage class for ClickHouse persistent volume"
  type        = string
  default     = "fast-local"
}

variable "replicas" {
  description = "Number of ClickHouse replicas"
  type        = number
  default     = 1
}

variable "image" {
  description = "ClickHouse Docker image"
  type        = string
  default     = "clickhouse/clickhouse-server:latest"
}

variable "password" {
  description = "ClickHouse password"
  type        = string
  sensitive   = true
}

variable "cpu_request" {
  description = "CPU request for ClickHouse container"
  type        = string
  default     = "1"
}

variable "memory_request" {
  description = "Memory request for ClickHouse container"
  type        = string
  default     = "2Gi"
}

variable "cpu_limit" {
  description = "CPU limit for ClickHouse container"
  type        = string
  default     = "2"
}

variable "memory_limit" {
  description = "Memory limit for ClickHouse container"
  type        = string
  default     = "4Gi"
}
