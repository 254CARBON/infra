# MLflow Module
# Deploys MLflow for ML experiment tracking

terraform {
  required_version = ">= 1.0"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

resource "kubernetes_deployment" "mlflow" {
  metadata {
    name      = "mlflow"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"    = "mlflow"
      "app.kubernetes.io/part-of" = "254carbon"
    }
  }

  spec {
    replicas = var.replicas

    selector {
      match_labels = {
        "app.kubernetes.io/name" = "mlflow"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"    = "mlflow"
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
          name  = "mlflow"
          image = var.image
          image_pull_policy = "IfNotPresent"

          port {
            name           = "http"
            container_port = 5000
          }

          env {
            name = "MLFLOW_BACKEND_STORE_URI"
            value = "postgresql://postgres:${var.postgres_password}@postgresql.data-plane.svc.cluster.local:5432/254carbon"
          }

          env {
            name = "MLFLOW_DEFAULT_ARTIFACT_ROOT"
            value = "s3://mlflow-artifacts"
          }

          env {
            name = "AWS_ACCESS_KEY_ID"
            value_from {
              secret_key_ref {
                name = "minio-credentials"
                key  = "access-key"
              }
            }
          }

          env {
            name = "AWS_SECRET_ACCESS_KEY"
            value_from {
              secret_key_ref {
                name = "minio-credentials"
                key  = "secret-key"
              }
            }
          }

          env {
            name = "MLFLOW_S3_ENDPOINT_URL"
            value = "http://minio.storage.svc.cluster.local:9000"
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
              path = "/health"
              port = 5000
            }
            initial_delay_seconds = 30
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = 5000
            }
            initial_delay_seconds = 5
            period_seconds        = 5
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "mlflow" {
  metadata {
    name      = "mlflow"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"    = "mlflow"
      "app.kubernetes.io/part-of" = "254carbon"
    }
  }

  spec {
    selector = {
      "app.kubernetes.io/name" = "mlflow"
    }

    port {
      name        = "http"
      port        = 5000
      target_port = 5000
    }

    type = "ClusterIP"
  }
}
