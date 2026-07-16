variable "newrelic_name" {
  description = "New Relic integration name"
  type        = string
  sensitive   = true
}

variable "newrelic_license_key" {
  description = "New Relic ingest license key"
  type        = string
  sensitive   = true
}

variable "newrelic_account_id" {
  description = "New Relic account ID"
  type        = number
}

variable "cluster_name" {
  description = "EKS cluster name displayed in New Relic K8s UI"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace for New Relic agents"
  type        = string
  default     = "newrelic"
}

variable "app_namespace" {
  description = "Kubernetes namespace of the monitored application"
  type        = string
}

variable "app_name" {
  description = "Application name (used in NRQL queries and alert names)"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "alert_email" {
  description = "Email address for alert notifications"
  type        = string
}

variable "synthetics_app_url" {
  description = "External HTTP URL of the app LoadBalancer for uptime check. Empty = skip."
  type        = string
  default     = ""
}
