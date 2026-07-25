variable "namespace_name" {
  description = "Name of the Kubernetes namespace"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "labels" {
  description = "Additional labels for the namespace"
  type        = map(string)
  default     = {}
}
