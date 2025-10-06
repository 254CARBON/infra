# Keycloak Module
# Deploys Keycloak for authentication

terraform {
  required_version = ">= 1.0"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

resource "kubernetes_secret" "keycloak_credentials" {
  metadata {
    name      = "keycloak-credentials"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"    = "keycloak"
      "app.kubernetes.io/part-of" = "254carbon"
    }
  }

  data = {
    admin-password = var.admin_password
  }

  type = "Opaque"
}

resource "kubernetes_deployment" "keycloak" {
  metadata {
    name      = "keycloak"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"    = "keycloak"
      "app.kubernetes.io/part-of" = "254carbon"
    }
  }

  spec {
    replicas = var.replicas

    selector {
      match_labels = {
        "app.kubernetes.io/name" = "keycloak"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"    = "keycloak"
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
          name  = "keycloak"
          image = var.image
          image_pull_policy = "IfNotPresent"

          port {
            name           = "http"
            container_port = 8080
          }

          env {
            name = "KEYCLOAK_ADMIN"
            value = "admin"
          }

          env {
            name = "KEYCLOAK_ADMIN_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.keycloak_credentials.metadata[0].name
                key  = "admin-password"
              }
            }
          }

          env {
            name = "KC_DB"
            value = "postgres"
          }

          env {
            name = "KC_DB_URL"
            value = "jdbc:postgresql://postgresql.data-plane.svc.cluster.local:5432/254carbon"
          }

          env {
            name = "KC_DB_USERNAME"
            value = "postgres"
          }

          env {
            name = "KC_DB_PASSWORD"
            value_from {
              secret_key_ref {
                name = "postgres-credentials"
                key  = "password"
              }
            }
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
              path = "/health/live"
              port = 8080
            }
            initial_delay_seconds = 60
            period_seconds        = 30
          }

          readiness_probe {
            http_get {
              path = "/health/ready"
              port = 8080
            }
            initial_delay_seconds = 30
            period_seconds        = 10
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "keycloak" {
  metadata {
    name      = "keycloak"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"    = "keycloak"
      "app.kubernetes.io/part-of" = "254carbon"
    }
  }

  spec {
    selector = {
      "app.kubernetes.io/name" = "keycloak"
    }

    port {
      name        = "http"
      port        = 8080
      target_port = 8080
    }

    type = "ClusterIP"
  }
}
