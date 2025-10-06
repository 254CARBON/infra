# ClickHouse Module
# Deploys ClickHouse for time-series and analytics data

terraform {
  required_version = ">= 1.0"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

resource "kubernetes_config_map" "clickhouse_config" {
  metadata {
    name      = "clickhouse-config"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"    = "clickhouse"
      "app.kubernetes.io/part-of" = "254carbon"
    }
  }

  data = {
    "config.xml" = templatefile("${path.module}/config.xml.tpl", {
      namespace = var.namespace
    })
  }
}

resource "kubernetes_secret" "clickhouse_credentials" {
  metadata {
    name      = "clickhouse-credentials"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"    = "clickhouse"
      "app.kubernetes.io/part-of" = "254carbon"
    }
  }

  data = {
    password = var.password
  }

  type = "Opaque"
}

resource "kubernetes_persistent_volume_claim" "clickhouse_storage" {
  metadata {
    name      = "clickhouse-storage"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"    = "clickhouse"
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

resource "kubernetes_stateful_set" "clickhouse" {
  metadata {
    name      = "clickhouse"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"    = "clickhouse"
      "app.kubernetes.io/part-of" = "254carbon"
    }
  }

  spec {
    replicas = var.replicas

    selector {
      match_labels = {
        "app.kubernetes.io/name" = "clickhouse"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"    = "clickhouse"
          "app.kubernetes.io/part-of" = "254carbon"
        }
      }

      spec {
        security_context {
          run_as_non_root = true
          run_as_user     = 101
          fs_group        = 101
        }

        container {
          name  = "clickhouse"
          image = var.image
          image_pull_policy = "IfNotPresent"

          port {
            name           = "http"
            container_port = 8123
          }

          port {
            name           = "native"
            container_port = 9000
          }

          env {
            name = "CLICKHOUSE_DB"
            value = "default"
          }

          env {
            name = "CLICKHOUSE_USER"
            value = "default"
          }

          env {
            name = "CLICKHOUSE_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.clickhouse_credentials.metadata[0].name
                key  = "password"
              }
            }
          }

          volume_mount {
            name       = "clickhouse-storage"
            mount_path = "/var/lib/clickhouse"
          }

          volume_mount {
            name       = "clickhouse-config"
            mount_path = "/etc/clickhouse-server/config.d"
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
              path = "/ping"
              port = 8123
            }
            initial_delay_seconds = 30
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/ping"
              port = 8123
            }
            initial_delay_seconds = 5
            period_seconds        = 5
          }
        }

        volume {
          name = "clickhouse-storage"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.clickhouse_storage.metadata[0].name
          }
        }

        volume {
          name = "clickhouse-config"
          config_map {
            name = kubernetes_config_map.clickhouse_config.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "clickhouse" {
  metadata {
    name      = "clickhouse"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"    = "clickhouse"
      "app.kubernetes.io/part-of" = "254carbon"
    }
  }

  spec {
    selector = {
      "app.kubernetes.io/name" = "clickhouse"
    }

    port {
      name        = "http"
      port        = 8123
      target_port = 8123
    }

    port {
      name        = "native"
      port        = 9000
      target_port = 9000
    }

    type = "ClusterIP"
  }
}
