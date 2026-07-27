variable "namespace" {
  description = "Kubernetes namespace"
  type        = string
}

variable "root_username" {
  description = "MongoDB root username"
  type        = string
}

variable "root_password" {
  description = "MongoDB root password"
  type        = string
  sensitive   = true
}

variable "database" {
  description = "Application database name"
  type        = string
}

variable "app_username" {
  description = "Application username"
  type        = string
}

variable "app_password" {
  description = "Application password"
  type        = string
  sensitive   = true
}

variable "image" {
  description = "MongoDB image"
  type        = string
  default     = "mongo:7"
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
