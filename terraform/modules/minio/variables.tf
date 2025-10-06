variable "namespace" {
  description = "Kubernetes namespace for MinIO"
  type        = string
}

variable "storage_size" {
  description = "Size of the persistent volume for MinIO"
  type        = string
  default     = "100Gi"
}

variable "storage_class" {
  description = "Storage class for MinIO persistent volume"
  type        = string
  default     = "standard-local"
}

variable "replicas" {
  description = "Number of MinIO replicas"
  type        = number
  default     = 1
}

variable "image" {
  description = "MinIO Docker image"
  type        = string
  default     = "minio/minio:latest"
}

variable "access_key" {
  description = "MinIO access key"
  type        = string
  sensitive   = true
}

variable "secret_key" {
  description = "MinIO secret key"
  type        = string
  sensitive   = true
}

variable "cpu_request" {
  description = "CPU request for MinIO container"
  type        = string
  default     = "500m"
}

variable "memory_request" {
  description = "Memory request for MinIO container"
  type        = string
  default     = "512Mi"
}

variable "cpu_limit" {
  description = "CPU limit for MinIO container"
  type        = string
  default     = "1"
}

variable "memory_limit" {
  description = "Memory limit for MinIO container"
  type        = string
  default     = "1Gi"
}
