# MinIO Module
# Deploys MinIO for object storage

terraform {
  required_version = ">= 1.0"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

resource "kubernetes_secret" "minio_credentials" {
  metadata {
    name      = "minio-credentials"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"    = "minio"
      "app.kubernetes.io/part-of" = "254carbon"
    }
  }

  data = {
    access-key = var.access_key
    secret-key = var.secret_key
  }

  type = "Opaque"
}

resource "kubernetes_persistent_volume_claim" "minio_storage" {
  metadata {
    name      = "minio-storage"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"    = "minio"
      "app.kubernetes.io/part-of" = "254carbon"
    }
  }

  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = var.storage_size
      }
    }
    storage_class_name = var.storage_class
  }
}

resource "kubernetes_stateful_set" "minio" {
  metadata {
    name      = "minio"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"    = "minio"
      "app.kubernetes.io/part-of" = "254carbon"
    }
  }

  spec {
    replicas = var.replicas

    selector {
      match_labels = {
        "app.kubernetes.io/name" = "minio"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"    = "minio"
          "app.kubernetes.io/part-of" = "254carbon"
        }
      }

      spec {
        security_context {
          run_as_non_root = true
          run_as_user     = 1000
          fs_group        = 1000
        }

        container {
          name  = "minio"
          image = var.image
          image_pull_policy = "IfNotPresent"

          port {
            name           = "api"
            container_port = 9000
          }

          port {
            name           = "console"
            container_port = 9001
          }

          env {
            name = "MINIO_ROOT_USER"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.minio_credentials.metadata[0].name
                key  = "access-key"
              }
            }
          }

          env {
            name = "MINIO_ROOT_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.minio_credentials.metadata[0].name
                key  = "secret-key"
              }
            }
          }

          volume_mount {
            name       = "minio-storage"
            mount_path = "/data"
          }

          resources {
            requests = {
              cpu    = var.cpu_request
              memory = var.memory_request
            }
            limits = {
              cpu    = var.cpu_limit
              memory = var.memory_limit
            }
          }

          liveness_probe {
            http_get {
              path = "/minio/health/live"
              port = 9000
            }
            initial_delay_seconds = 30
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/minio/health/ready"
              port = 9000
            }
            initial_delay_seconds = 5
            period_seconds        = 5
          }
        }

        volume {
          name = "minio-storage"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.minio_storage.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "minio" {
  metadata {
    name      = "minio"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"    = "minio"
      "app.kubernetes.io/part-of" = "254carbon"
    }
  }

  spec {
    selector = {
      "app.kubernetes.io/name" = "minio"
    }

    port {
      name        = "api"
      port        = 9000
      target_port = 9000
    }

    port {
      name        = "console"
      port        = 9001
      target_port = 9001
    }

    type = "ClusterIP"
  }
}
