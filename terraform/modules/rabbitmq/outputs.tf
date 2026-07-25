output "service_name" {
  description = "RabbitMQ service name"
  value       = kubernetes_service.rabbitmq.metadata[0].name
}

output "service_host" {
  description = "In-cluster DNS host for RabbitMQ"
  value       = "${kubernetes_service.rabbitmq.metadata[0].name}.${var.namespace}.svc.cluster.local"
}

output "amqp_url" {
  description = "AMQP connection URL (in-cluster)"
  value       = "amqp://${var.username}:${var.password}@${kubernetes_service.rabbitmq.metadata[0].name}.${var.namespace}.svc.cluster.local:5672/${var.vhost}"
  sensitive   = true
}
