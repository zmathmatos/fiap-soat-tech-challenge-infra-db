locals {
  name   = "mongodb"
  labels = { app = "mongodb" }
}

resource "kubernetes_secret" "mongodb" {
  metadata {
    name      = "mongodb-credentials"
    namespace = var.namespace
    labels    = local.labels
  }

  data = {
    MONGO_INITDB_ROOT_USERNAME = var.root_username
    MONGO_INITDB_ROOT_PASSWORD = var.root_password
    MONGO_INITDB_DATABASE      = var.database
    MONGO_APP_USERNAME         = var.app_username
    MONGO_APP_PASSWORD         = var.app_password
  }

  type = "Opaque"
}

# Init script run by the Mongo entrypoint on first boot.
# Creates the application user and an initial collection (materializes the database).
resource "kubernetes_config_map" "mongodb_init" {
  metadata {
    name      = "mongodb-init"
    namespace = var.namespace
    labels    = local.labels
  }

  data = {
    "01-app-user.js" = <<-EOT
      const dbName = process.env.MONGO_INITDB_DATABASE;
      const appUser = process.env.MONGO_APP_USERNAME;
      const appPass = process.env.MONGO_APP_PASSWORD;
      const appDb = db.getSiblingDB(dbName);
      const exists = appDb.getUser(appUser);
      if (!exists) {
        appDb.createUser({
          user: appUser,
          pwd: appPass,
          roles: [{ role: "readWrite", db: dbName }],
        });
      }
      appDb.createCollection("_init");
    EOT
  }
}

resource "kubernetes_stateful_set" "mongodb" {
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
            name           = "mongodb"
            container_port = 27017
          }

          env {
            name = "MONGO_INITDB_ROOT_USERNAME"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.mongodb.metadata[0].name
                key  = "MONGO_INITDB_ROOT_USERNAME"
              }
            }
          }
          env {
            name = "MONGO_INITDB_ROOT_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.mongodb.metadata[0].name
                key  = "MONGO_INITDB_ROOT_PASSWORD"
              }
            }
          }
          env {
            name = "MONGO_INITDB_DATABASE"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.mongodb.metadata[0].name
                key  = "MONGO_INITDB_DATABASE"
              }
            }
          }
          env {
            name = "MONGO_APP_USERNAME"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.mongodb.metadata[0].name
                key  = "MONGO_APP_USERNAME"
              }
            }
          }
          env {
            name = "MONGO_APP_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.mongodb.metadata[0].name
                key  = "MONGO_APP_PASSWORD"
              }
            }
          }

          volume_mount {
            name       = "data"
            mount_path = "/data/db"
          }

          volume_mount {
            name       = "init"
            mount_path = "/docker-entrypoint-initdb.d"
            read_only  = true
          }

          readiness_probe {
            exec {
              command = ["mongosh", "--quiet", "--eval", "db.adminCommand('ping')"]
            }
            initial_delay_seconds = 20
            period_seconds        = 15
            timeout_seconds       = 10
          }

          liveness_probe {
            exec {
              command = ["mongosh", "--quiet", "--eval", "db.adminCommand('ping')"]
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

        volume {
          name = "init"
          config_map {
            name = kubernetes_config_map.mongodb_init.metadata[0].name
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

resource "kubernetes_service" "mongodb" {
  metadata {
    name      = local.name
    namespace = var.namespace
    labels    = local.labels
  }

  spec {
    selector = local.labels

    port {
      name        = "mongodb"
      port        = 27017
      target_port = 27017
    }

    type = "ClusterIP"
  }
}
