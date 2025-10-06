# Observability Module
# Deploys Prometheus, Grafana, and OpenTelemetry Collector

terraform {
  required_version = ">= 1.0"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

# Prometheus
resource "kubernetes_deployment" "prometheus" {
  metadata {
    name      = "prometheus"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"    = "prometheus"
      "app.kubernetes.io/part-of" = "254carbon"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        "app.kubernetes.io/name" = "prometheus"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"    = "prometheus"
          "app.kubernetes.io/part-of" = "254carbon"
        }
      }

      spec {
        security_context {
          run_as_non_root = true
          run_as_user     = 65534
          fs_group        = 65534
        }

        container {
          name  = "prometheus"
          image = var.prometheus_image
          image_pull_policy = "IfNotPresent"

          port {
            name           = "web"
            container_port = 9090
          }

          resources {
            requests = {
              cpu    = var.prometheus_cpu_request
              memory = var.prometheus_memory_request
            }
            limits = {
              cpu    = var.prometheus_cpu_limit
              memory = var.prometheus_memory_limit
            }
          }

          liveness_probe {
            http_get {
              path = "/-/healthy"
              port = 9090
            }
            initial_delay_seconds = 30
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/-/ready"
              port = 9090
            }
            initial_delay_seconds = 5
            period_seconds        = 5
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "prometheus" {
  metadata {
    name      = "prometheus"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"    = "prometheus"
      "app.kubernetes.io/part-of" = "254carbon"
    }
  }

  spec {
    selector = {
      "app.kubernetes.io/name" = "prometheus"
    }

    port {
      name        = "web"
      port        = 9090
      target_port = 9090
    }

    type = "ClusterIP"
  }
}

# Grafana
resource "kubernetes_deployment" "grafana" {
  metadata {
    name      = "grafana"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"    = "grafana"
      "app.kubernetes.io/part-of" = "254carbon"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        "app.kubernetes.io/name" = "grafana"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"    = "grafana"
          "app.kubernetes.io/part-of" = "254carbon"
        }
      }

      spec {
        security_context {
          run_as_non_root = true
          run_as_user     = 472
          fs_group        = 472
        }

        container {
          name  = "grafana"
          image = var.grafana_image
          image_pull_policy = "IfNotPresent"

          port {
            name           = "http"
            container_port = 3000
          }

          env {
            name = "GF_SECURITY_ADMIN_PASSWORD"
            value = var.grafana_admin_password
          }

          resources {
            requests = {
              cpu    = var.grafana_cpu_request
              memory = var.grafana_memory_request
            }
            limits = {
              cpu    = var.grafana_cpu_limit
              memory = var.grafana_memory_limit
            }
          }

          liveness_probe {
            http_get {
              path = "/api/health"
              port = 3000
            }
            initial_delay_seconds = 30
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/api/health"
              port = 3000
            }
            initial_delay_seconds = 5
            period_seconds        = 5
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "grafana" {
  metadata {
    name      = "grafana"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"    = "grafana"
      "app.kubernetes.io/part-of" = "254carbon"
    }
  }

  spec {
    selector = {
      "app.kubernetes.io/name" = "grafana"
    }

    port {
      name        = "http"
      port        = 3000
      target_port = 3000
    }

    type = "ClusterIP"
  }
}
