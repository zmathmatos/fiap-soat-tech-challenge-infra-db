output "name" {
  description = "The name of the created namespace"
  value       = kubernetes_namespace.this.metadata[0].name
}

output "id" {
  description = "The ID of the created namespace"
  value       = kubernetes_namespace.this.id
}
