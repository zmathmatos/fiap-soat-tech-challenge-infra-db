locals {
  name   = "db-bootstrap"
  labels = { app = "db-bootstrap" }

  sql = join("\n", [
    for key, svc in var.postgres_services : <<-SQL
      ${svc.schema == "public" ? "" : format("CREATE SCHEMA IF NOT EXISTS %q;", svc.schema)}

      DO $do$
      BEGIN
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '${svc.role}') THEN
          ALTER ROLE ${svc.role} WITH LOGIN PASSWORD '${svc.password}';
        ELSE
          CREATE ROLE ${svc.role} WITH LOGIN PASSWORD '${svc.password}';
        END IF;
      END
      $do$;

      GRANT ${svc.role} TO CURRENT_USER;

      REVOKE ALL ON SCHEMA ${format("%q", svc.schema)} FROM PUBLIC;
      GRANT USAGE, CREATE ON SCHEMA ${format("%q", svc.schema)} TO ${svc.role};
      GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA ${format("%q", svc.schema)} TO ${svc.role};
      GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA ${format("%q", svc.schema)} TO ${svc.role};
      ALTER DEFAULT PRIVILEGES IN SCHEMA ${format("%q", svc.schema)} GRANT ALL ON TABLES TO ${svc.role};
      ALTER DEFAULT PRIVILEGES IN SCHEMA ${format("%q", svc.schema)} GRANT ALL ON SEQUENCES TO ${svc.role};
      ALTER ROLE ${svc.role} SET search_path TO ${format("%q", svc.schema)};
    SQL
  ])

  # replace() strips CR so the script survives a Windows (CRLF) checkout —
  # otherwise /bin/sh chokes on "set -eu\r".
  script = replace(<<-EOT
    set -eu
    echo "Waiting for Postgres at $PGHOST:$PGPORT ..."
    until pg_isready -h "$PGHOST" -p "$PGPORT" -U "$PGUSER"; do
      sleep 5
    done
    psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" \
      -v ON_ERROR_STOP=1 -f /sql/bootstrap.sql
    echo "Bootstrap finished"
  EOT
  , "\r\n", "\n")
}

resource "kubernetes_secret" "bootstrap" {
  metadata {
    name      = "db-bootstrap-credentials"
    namespace = var.namespace
    labels    = local.labels
  }

  data = {
    PGUSER          = var.postgres_username
    PGPASSWORD      = var.postgres_password
    "bootstrap.sql" = local.sql
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
          volume_mount {
            name       = "sql"
            mount_path = "/sql"
            read_only  = true
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

        volume {
          name = "sql"
          secret {
            secret_name = kubernetes_secret.bootstrap.metadata[0].name
            items {
              key  = "bootstrap.sql"
              path = "bootstrap.sql"
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
