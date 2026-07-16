output "job_name" {
  description = "Bootstrap Job name"
  value       = kubernetes_job.bootstrap.metadata[0].name
}

output "schemas" {
  description = "Schemas created"
  value       = var.postgres_schemas
}
