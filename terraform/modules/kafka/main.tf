# Kafka Module
# Deploys Kafka for message streaming

terraform {
  required_version = ">= 1.0"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

resource "kubernetes_secret" "kafka_credentials" {
  metadata {
    name      = "kafka-credentials"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"    = "kafka"
      "app.kubernetes.io/part-of" = "254carbon"
    }
  }

  data = {
    password = var.password
  }

  type = "Opaque"
}

resource "kubernetes_persistent_volume_claim" "kafka_storage" {
  metadata {
    name      = "kafka-storage"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"    = "kafka"
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

resource "kubernetes_stateful_set" "kafka" {
  metadata {
    name      = "kafka"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"    = "kafka"
      "app.kubernetes.io/part-of" = "254carbon"
    }
  }

  spec {
    replicas = var.replicas

    selector {
      match_labels = {
        "app.kubernetes.io/name" = "kafka"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"    = "kafka"
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
          name  = "kafka"
          image = var.image
          image_pull_policy = "IfNotPresent"

          port {
            name           = "kafka"
            container_port = 9092
          }

          env {
            name = "KAFKA_BROKER_ID"
            value = "1"
          }

          env {
            name = "KAFKA_ZOOKEEPER_CONNECT"
            value = "localhost:2181"
          }

          env {
            name = "KAFKA_LISTENER_SECURITY_PROTOCOL_MAP"
            value = "PLAINTEXT:PLAINTEXT"
          }

          env {
            name = "KAFKA_ADVERTISED_LISTENERS"
            value = "PLAINTEXT://kafka:9092"
          }

          env {
            name = "KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR"
            value = "1"
          }

          env {
            name = "KAFKA_TRANSACTION_STATE_LOG_MIN_ISR"
            value = "1"
          }

          env {
            name = "KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR"
            value = "1"
          }

          volume_mount {
            name       = "kafka-storage"
            mount_path = "/var/lib/kafka/data"
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
        }

        volume {
          name = "kafka-storage"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.kafka_storage.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "kafka" {
  metadata {
    name      = "kafka"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"    = "kafka"
      "app.kubernetes.io/part-of" = "254carbon"
    }
  }

  spec {
    selector = {
      "app.kubernetes.io/name" = "kafka"
    }

    port {
      name        = "kafka"
      port        = 9092
      target_port = 9092
    }

    type = "ClusterIP"
  }
}
