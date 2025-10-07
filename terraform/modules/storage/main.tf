# Storage Module
# Defines storage classes and persistent volume configurations

terraform {
  required_version = ">= 1.0"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

# Fast local storage class (for ClickHouse)
resource "kubernetes_storage_class" "fast_local" {
  metadata {
    name = "fast-local"
    labels = {
      "app.kubernetes.io/name"    = "fast-local"
      "app.kubernetes.io/part-of" = "254carbon"
    }
  }

  storage_provisioner    = "rancher.io/local-path"
  reclaim_policy         = "Delete"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true
}

# Standard local storage class (for general use)
resource "kubernetes_storage_class" "standard_local" {
  metadata {
    name = "standard-local"
    labels = {
      "app.kubernetes.io/name"    = "standard-local"
      "app.kubernetes.io/part-of" = "254carbon"
    }
  }

  storage_provisioner    = "rancher.io/local-path"
  reclaim_policy         = "Delete"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true
}

# Backup storage class (for MinIO)
resource "kubernetes_storage_class" "backup_storage" {
  metadata {
    name = "backup-storage"
    labels = {
      "app.kubernetes.io/name"    = "backup-storage"
      "app.kubernetes.io/part-of" = "254carbon"
    }
  }

  storage_provisioner    = "rancher.io/local-path"
  reclaim_policy         = "Retain"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true
}
