output "service_name" {
  description = "MongoDB service name"
  value       = kubernetes_service.mongodb.metadata[0].name
}

output "service_host" {
  description = "In-cluster DNS host for MongoDB"
  value       = "${kubernetes_service.mongodb.metadata[0].name}.${var.namespace}.svc.cluster.local"
}

output "app_uri" {
  description = "MongoDB connection URI for the application user"
  value       = "mongodb://${var.app_username}:${var.app_password}@${kubernetes_service.mongodb.metadata[0].name}.${var.namespace}.svc.cluster.local:27017/${var.database}"
  sensitive   = true
}
