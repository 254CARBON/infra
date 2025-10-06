# Kubernetes Cluster Module
# Base configuration for k8s cluster resources

terraform {
  required_version = ">= 1.0"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

# Local k3d cluster configuration
resource "kubernetes_namespace" "platform_core" {
  metadata {
    name = var.platform_core_namespace
    labels = {
      "app.kubernetes.io/name"    = "platform-core"
      "app.kubernetes.io/part-of" = "254carbon"
    }
  }
}

resource "kubernetes_namespace" "data_plane" {
  metadata {
    name = var.data_plane_namespace
    labels = {
      "app.kubernetes.io/name"    = "data-plane"
      "app.kubernetes.io/part-of" = "254carbon"
    }
  }
}

resource "kubernetes_namespace" "storage" {
  metadata {
    name = var.storage_namespace
    labels = {
      "app.kubernetes.io/name"    = "storage"
      "app.kubernetes.io/part-of" = "254carbon"
    }
  }
}

resource "kubernetes_namespace" "ml" {
  metadata {
    name = var.ml_namespace
    labels = {
      "app.kubernetes.io/name"    = "ml"
      "app.kubernetes.io/part-of" = "254carbon"
    }
  }
}

resource "kubernetes_namespace" "observability" {
  metadata {
    name = var.observability_namespace
    labels = {
      "app.kubernetes.io/name"    = "observability"
      "app.kubernetes.io/part-of" = "254carbon"
    }
  }
}

resource "kubernetes_namespace" "security" {
  metadata {
    name = var.security_namespace
    labels = {
      "app.kubernetes.io/name"    = "security"
      "app.kubernetes.io/part-of" = "254carbon"
    }
  }
}

resource "kubernetes_namespace" "backup" {
  metadata {
    name = var.backup_namespace
    labels = {
      "app.kubernetes.io/name"    = "backup"
      "app.kubernetes.io/part-of" = "254carbon"
    }
  }
}
