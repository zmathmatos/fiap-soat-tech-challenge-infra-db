variable "namespace" {
  description = "Kubernetes namespace"
  type        = string
}

variable "username" {
  description = "RabbitMQ admin username"
  type        = string
}

variable "password" {
  description = "RabbitMQ admin password"
  type        = string
  sensitive   = true
}

variable "vhost" {
  description = "Default virtual host"
  type        = string
  default     = "fiap-soat"
}

variable "image" {
  description = "RabbitMQ image"
  type        = string
  default     = "rabbitmq:3.13-management"
}

variable "storage" {
  description = "Persistent volume size"
  type        = string
  default     = "5Gi"
}

variable "storage_class_name" {
  description = "StorageClass for the persistent volume (EKS default: gp2)"
  type        = string
  default     = "gp2"
}

variable "persistence_enabled" {
  description = "Use a PersistentVolumeClaim for data. Requires a working CSI driver; false falls back to emptyDir"
  type        = bool
  default     = true
}
