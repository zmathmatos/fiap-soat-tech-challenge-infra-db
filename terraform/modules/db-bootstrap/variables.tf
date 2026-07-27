variable "namespace" {
  description = "Kubernetes namespace"
  type        = string
}

variable "postgres_host" {
  description = "RDS Postgres host"
  type        = string
}

variable "postgres_port" {
  description = "RDS Postgres port"
  type        = number
  default     = 5432
}

variable "postgres_database" {
  description = "Postgres database to create schemas in"
  type        = string
}

variable "postgres_username" {
  description = "Postgres master username"
  type        = string
  sensitive   = true
}

variable "postgres_password" {
  description = "Postgres master password"
  type        = string
  sensitive   = true
}

variable "postgres_services" {
  description = "SQL microservices to provision (schema + dedicated login role)"
  type = map(object({
    schema = string
    role   = string
  }))
}

variable "postgres_passwords" {
  description = "Generated password per service key"
  type        = map(string)
  sensitive   = true
}

variable "image" {
  description = "Image with psql client"
  type        = string
  default     = "postgres:17-alpine"
}
