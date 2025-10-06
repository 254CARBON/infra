variable "environment" {
  description = "Environment name (local, dev, staging, prod)"
  type        = string
  default     = "local"
}

variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
  default     = "local-254carbon"
}
