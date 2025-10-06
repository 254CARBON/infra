# PostgreSQL Module
# Deploys PostgreSQL for transactional metadata

terraform {
  required_version = ">= 1.0"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

resource "kubernetes_secret" "postgres_credentials" {
  metadata {
    name      = "postgres-credentials"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"    = "postgresql"
      "app.kubernetes.io/part-of" = "254carbon"
    }
  }

  data = {
    password = var.password
  }

  type = "Opaque"
}

resource "kubernetes_persistent_volume_claim" "postgres_storage" {
  metadata {
    name      = "postgres-storage"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"    = "postgresql"
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

resource "kubernetes_stateful_set" "postgresql" {
  metadata {
    name      = "postgresql"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"    = "postgresql"
      "app.kubernetes.io/part-of" = "254carbon"
    }
  }

  spec {
    replicas = var.replicas

    selector {
      match_labels = {
        "app.kubernetes.io/name" = "postgresql"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"    = "postgresql"
          "app.kubernetes.io/part-of" = "254carbon"
        }
      }

      spec {
        security_context {
          run_as_non_root = true
          run_as_user     = 999
          fs_group        = 999
        }

        container {
          name  = "postgresql"
          image = var.image
          image_pull_policy = "IfNotPresent"

          port {
            name           = "postgres"
            container_port = 5432
          }

          env {
            name = "POSTGRES_DB"
            value = var.database_name
          }

          env {
            name = "POSTGRES_USER"
            value = var.username
          }

          env {
            name = "POSTGRES_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.postgres_credentials.metadata[0].name
                key  = "password"
              }
            }
          }

          volume_mount {
            name       = "postgres-storage"
            mount_path = "/var/lib/postgresql/data"
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
            exec {
              command = ["pg_isready", "-U", var.username, "-d", var.database_name]
            }
            initial_delay_seconds = 30
            period_seconds        = 10
          }

          readiness_probe {
            exec {
              command = ["pg_isready", "-U", var.username, "-d", var.database_name]
            }
            initial_delay_seconds = 5
            period_seconds        = 5
          }
        }

        volume {
          name = "postgres-storage"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.postgres_storage.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "postgresql" {
  metadata {
    name      = "postgresql"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"    = "postgresql"
      "app.kubernetes.io/part-of" = "254carbon"
    }
  }

  spec {
    selector = {
      "app.kubernetes.io/name" = "postgresql"
    }

    port {
      name        = "postgres"
      port        = 5432
      target_port = 5432
    }

    type = "ClusterIP"
  }
}
