variable "platform_core_namespace" {
  description = "Name of the platform core namespace"
  type        = string
  default     = "platform-core"
}

variable "data_plane_namespace" {
  description = "Name of the data plane namespace"
  type        = string
  default     = "data-plane"
}

variable "storage_namespace" {
  description = "Name of the storage namespace"
  type        = string
  default     = "storage"
}

variable "ml_namespace" {
  description = "Name of the ML namespace"
  type        = string
  default     = "ml"
}

variable "observability_namespace" {
  description = "Name of the observability namespace"
  type        = string
  default     = "observability"
}

variable "security_namespace" {
  description = "Name of the security namespace"
  type        = string
  default     = "security"
}

variable "backup_namespace" {
  description = "Name of the backup namespace"
  type        = string
  default     = "backup"
}

variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
  default     = "local-254carbon"
}

variable "environment" {
  description = "Environment name (local, dev, staging, prod)"
  type        = string
  default     = "local"
}
