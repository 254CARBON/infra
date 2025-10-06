variable "namespace" {
  description = "Kubernetes namespace for PostgreSQL"
  type        = string
}

variable "storage_size" {
  description = "Size of the persistent volume for PostgreSQL"
  type        = string
  default     = "20Gi"
}

variable "storage_class" {
  description = "Storage class for PostgreSQL persistent volume"
  type        = string
  default     = "standard-local"
}

variable "replicas" {
  description = "Number of PostgreSQL replicas"
  type        = number
  default     = 1
}

variable "image" {
  description = "PostgreSQL Docker image"
  type        = string
  default     = "postgres:15"
}

variable "database_name" {
  description = "Name of the PostgreSQL database"
  type        = string
  default     = "254carbon"
}

variable "username" {
  description = "PostgreSQL username"
  type        = string
  default     = "postgres"
}

variable "password" {
  description = "PostgreSQL password"
  type        = string
  sensitive   = true
}

variable "cpu_request" {
  description = "CPU request for PostgreSQL container"
  type        = string
  default     = "500m"
}

variable "memory_request" {
  description = "Memory request for PostgreSQL container"
  type        = string
  default     = "1Gi"
}

variable "cpu_limit" {
  description = "CPU limit for PostgreSQL container"
  type        = string
  default     = "1"
}

variable "memory_limit" {
  description = "Memory limit for PostgreSQL container"
  type        = string
  default     = "2Gi"
}
