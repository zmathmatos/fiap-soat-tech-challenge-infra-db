output "job_name" {
  description = "Bootstrap Job name"
  value       = kubernetes_job.bootstrap.metadata[0].name
}

output "schemas" {
  description = "Schemas created, keyed by service"
  value       = { for k, v in var.postgres_services : k => v.schema }
}

output "roles" {
  description = "Login roles created, keyed by service"
  value       = { for k, v in var.postgres_services : k => v.role }
}
