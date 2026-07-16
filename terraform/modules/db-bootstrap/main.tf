locals {
  name    = "db-bootstrap"
  labels  = { app = "db-bootstrap" }
  schemas = join(" ", var.postgres_schemas)

  script = <<-EOT
    set -eu
    echo "Waiting for Postgres at $PGHOST:$PGPORT ..."
    until pg_isready -h "$PGHOST" -p "$PGPORT" -U "$PGUSER"; do
      sleep 5
    done
    for schema in $SCHEMAS; do
      echo "Creating schema '$schema' (if not exists)"
      psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" \
        -v ON_ERROR_STOP=1 \
        -c "CREATE SCHEMA IF NOT EXISTS \"$schema\";"
    done
    echo "Provisioned schemas: $SCHEMAS"
  EOT
}

resource "kubernetes_secret" "bootstrap" {
  metadata {
    name      = "db-bootstrap-credentials"
    namespace = var.namespace
    labels    = local.labels
  }

  data = {
    PGUSER     = var.postgres_username
    PGPASSWORD = var.postgres_password
  }

  type = "Opaque"
}

resource "kubernetes_job" "bootstrap" {
  metadata {
    name      = local.name
    namespace = var.namespace
    labels    = local.labels
  }

  spec {
    backoff_limit              = 6
    ttl_seconds_after_finished = 600

    template {
      metadata {
        labels = local.labels
      }

      spec {
        restart_policy = "OnFailure"

        container {
          name    = local.name
          image   = var.image
          command = ["/bin/sh", "-c", local.script]

          env {
            name  = "PGHOST"
            value = var.postgres_host
          }
          env {
            name  = "PGPORT"
            value = tostring(var.postgres_port)
          }
          env {
            name  = "PGDATABASE"
            value = var.postgres_database
          }
          env {
            name  = "SCHEMAS"
            value = local.schemas
          }
          env {
            name = "PGUSER"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.bootstrap.metadata[0].name
                key  = "PGUSER"
              }
            }
          }
          env {
            name = "PGPASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.bootstrap.metadata[0].name
                key  = "PGPASSWORD"
              }
            }
          }
        }
      }
    }
  }

  wait_for_completion = true

  timeouts {
    create = "15m"
  }
}
