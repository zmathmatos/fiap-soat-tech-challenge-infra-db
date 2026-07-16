locals {
  name   = "rabbitmq"
  labels = { app = "rabbitmq" }
}

resource "kubernetes_secret" "rabbitmq" {
  metadata {
    name      = "rabbitmq-credentials"
    namespace = var.namespace
    labels    = local.labels
  }

  data = {
    RABBITMQ_DEFAULT_USER  = var.username
    RABBITMQ_DEFAULT_PASS  = var.password
    RABBITMQ_DEFAULT_VHOST = var.vhost
  }

  type = "Opaque"
}

resource "kubernetes_stateful_set" "rabbitmq" {
  metadata {
    name      = local.name
    namespace = var.namespace
    labels    = local.labels
  }

  spec {
    service_name = local.name
    replicas     = 1

    selector {
      match_labels = local.labels
    }

    template {
      metadata {
        labels = local.labels
      }

      spec {
        container {
          name  = local.name
          image = var.image

          port {
            name           = "amqp"
            container_port = 5672
          }
          port {
            name           = "management"
            container_port = 15672
          }

          env_from {
            secret_ref {
              name = kubernetes_secret.rabbitmq.metadata[0].name
            }
          }

          volume_mount {
            name       = "data"
            mount_path = "/var/lib/rabbitmq"
          }

          readiness_probe {
            exec {
              command = ["rabbitmq-diagnostics", "-q", "ping"]
            }
            initial_delay_seconds = 20
            period_seconds        = 15
            timeout_seconds       = 10
          }

          liveness_probe {
            exec {
              command = ["rabbitmq-diagnostics", "-q", "ping"]
            }
            initial_delay_seconds = 40
            period_seconds        = 30
            timeout_seconds       = 10
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "256Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }
        }
      }
    }

    volume_claim_template {
      metadata {
        name = "data"
      }
      spec {
        access_modes = ["ReadWriteOnce"]
        resources {
          requests = {
            storage = var.storage
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "rabbitmq" {
  metadata {
    name      = local.name
    namespace = var.namespace
    labels    = local.labels
  }

  spec {
    selector = local.labels

    port {
      name        = "amqp"
      port        = 5672
      target_port = 5672
    }
    port {
      name        = "management"
      port        = 15672
      target_port = 15672
    }

    type = "ClusterIP"
  }
}
