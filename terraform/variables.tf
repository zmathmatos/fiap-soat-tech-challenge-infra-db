# ---------------------------------------------------------------------------
# Gerais
# ---------------------------------------------------------------------------
variable "project_name" {
  description = "Project name"
  type        = string
  default     = "fiap-soat"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

# ---------------------------------------------------------------------------
# Rede (VPC)
# ---------------------------------------------------------------------------
variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.20.0/24"]
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway"
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# EKS
# ---------------------------------------------------------------------------
variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.32"
}

variable "eks_cluster_role_arn" {
  description = "EKS cluster IAM role ARN (AWS Academy: LabRole ARN)"
  type        = string
  default     = null
}

variable "eks_node_group_role_arn" {
  description = "EKS node group IAM role ARN (AWS Academy: LabRole ARN)"
  type        = string
  default     = null
}

variable "eks_endpoint_private_access" {
  description = "Enable EKS private endpoint"
  type        = bool
  default     = true
}

variable "eks_endpoint_public_access" {
  description = "Enable EKS public endpoint"
  type        = bool
  default     = true
}

variable "eks_access_principal_arn" {
  description = "IAM principal ARN with EKS cluster access"
  type        = string
  default     = null
}

variable "eks_node_groups" {
  description = "EKS node groups configuration"
  type = map(object({
    instance_types  = list(string)
    capacity_type   = string
    disk_size       = number
    desired_size    = number
    min_size        = number
    max_size        = number
    max_unavailable = number
    labels          = map(string)
  }))
  default = {
    default = {
      instance_types  = ["t3.medium"]
      capacity_type   = "ON_DEMAND"
      disk_size       = 20
      desired_size    = 2
      min_size        = 1
      max_size        = 4
      max_unavailable = 1
      labels = {
        NodeGroup = "default"
      }
    }
  }
}

variable "namespace_name" {
  description = "Kubernetes namespace"
  type        = string
  default     = "fiap-soat"
}

# ---------------------------------------------------------------------------
# Observabilidade (New Relic)
# ---------------------------------------------------------------------------
variable "app_name" {
  description = "Application name (observability NRQL queries / alert names)"
  type        = string
  default     = "fiap-web"
}

variable "newrelic_name" {
  description = "New Relic Helm release name (nri-bundle)"
  type        = string
  default     = "newrelic-bundle"
}

variable "newrelic_enabled" {
  description = "Enable New Relic observability module"
  type        = bool
  default     = false
}

variable "newrelic_license_key" {
  description = "New Relic ingest license key"
  type        = string
  sensitive   = true
  default     = ""
}

variable "newrelic_account_id" {
  description = "New Relic account ID"
  type        = number
  default     = 0
}

variable "newrelic_api_key" {
  description = "New Relic user API key (for provider)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "alert_email" {
  description = "Email for alert notifications"
  type        = string
  default     = ""
}

variable "synthetics_app_url" {
  description = "External URL for Synthetics uptime check. Empty = skip."
  type        = string
  default     = ""
}

# ---------------------------------------------------------------------------
# RDS PostgreSQL
# ---------------------------------------------------------------------------
variable "rds_engine_version" {
  description = "RDS PostgreSQL engine version"
  type        = string
  default     = "17"
}

variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "rds_allocated_storage" {
  description = "RDS allocated storage in GB"
  type        = number
  default     = 20
}

variable "rds_max_allocated_storage" {
  description = "RDS maximum allocated storage"
  type        = number
  default     = 100
}

variable "rds_storage_encrypted" {
  description = "Enable RDS storage encryption"
  type        = bool
  default     = true
}

variable "rds_database_name" {
  description = "RDS initial database name (shared; logical isolation via schemas)"
  type        = string
  default     = "fiap_soat_db"
}

variable "rds_database_port" {
  description = "RDS listening port"
  type        = number
  default     = 5432
}

variable "rds_master_username" {
  description = "RDS master username"
  type        = string
  sensitive   = true
}

variable "rds_master_password" {
  description = "RDS master password"
  type        = string
  sensitive   = true
}

variable "rds_multi_az" {
  description = "Enable RDS Multi-AZ"
  type        = bool
  default     = false
}

variable "rds_backup_retention_period" {
  description = "RDS backup retention period in days"
  type        = number
  default     = 7
}

variable "rds_deletion_protection" {
  description = "Enable RDS deletion protection"
  type        = bool
  default     = false
}

variable "rds_skip_final_snapshot" {
  description = "Skip RDS final snapshot"
  type        = bool
  default     = false
}

variable "postgres_services" {
  description = "SQL microservices: schema + dedicated login role provisioned per service"
  type = map(object({
    schema = string
    role   = string
  }))
  default = {
    os        = { schema = "public", role = "os_svc" }
    execution = { schema = "execution", role = "execution_svc" }
  }
}

# ---------------------------------------------------------------------------
# RabbitMQ (mensageria no EKS)
# ---------------------------------------------------------------------------
variable "rabbitmq_username" {
  description = "RabbitMQ admin username"
  type        = string
  default     = "fiap"
}

variable "rabbitmq_password" {
  description = "RabbitMQ admin password"
  type        = string
  sensitive   = true
}

variable "rabbitmq_vhost" {
  description = "RabbitMQ virtual host for the application"
  type        = string
  default     = "fiap-soat"
}

variable "rabbitmq_storage" {
  description = "RabbitMQ persistent volume size"
  type        = string
  default     = "5Gi"
}

# ---------------------------------------------------------------------------
# MongoDB (banco NoSQL no EKS — billing-service)
# ---------------------------------------------------------------------------
variable "mongodb_root_username" {
  description = "MongoDB root username"
  type        = string
  default     = "root"
}

variable "mongodb_root_password" {
  description = "MongoDB root password"
  type        = string
  sensitive   = true
}

variable "mongodb_database" {
  description = "MongoDB application database (billing-service)"
  type        = string
  default     = "billing"
}

variable "mongodb_app_username" {
  description = "MongoDB application username"
  type        = string
  default     = "billing"
}

variable "mongodb_app_password" {
  description = "MongoDB application password"
  type        = string
  sensitive   = true
}

variable "mongodb_storage" {
  description = "MongoDB persistent volume size"
  type        = string
  default     = "5Gi"
}
