variable "environment" {
  description = "Environment name"
  type        = string
  default     = "local"
}

variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
  default     = "local-254carbon"
}

variable "postgres_password" {
  description = "PostgreSQL password"
  type        = string
  default     = "postgres123"
  sensitive   = true
}

variable "clickhouse_password" {
  description = "ClickHouse password"
  type        = string
  default     = "clickhouse123"
  sensitive   = true
}

variable "redis_password" {
  description = "Redis password"
  type        = string
  default     = "redis123"
  sensitive   = true
}

variable "kafka_password" {
  description = "Kafka password"
  type        = string
  default     = "kafka123"
  sensitive   = true
}

variable "minio_access_key" {
  description = "MinIO access key"
  type        = string
  default     = "minioadmin"
  sensitive   = true
}

variable "minio_secret_key" {
  description = "MinIO secret key"
  type        = string
  default     = "minioadmin123"
  sensitive   = true
}

variable "keycloak_admin_password" {
  description = "Keycloak admin password"
  type        = string
  default     = "admin123"
  sensitive   = true
}

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  default     = "admin123"
  sensitive   = true
}
