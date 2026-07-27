# ---------------------------------------------------------------------------
# Rede / EKS
# ---------------------------------------------------------------------------
output "vpc_id" {
  description = "VPC ID"
  value       = module.network.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.network.private_subnet_ids
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_security_group_id" {
  description = "EKS cluster security group ID"
  value       = module.eks.cluster_security_group_id
}

output "eks_configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "namespace" {
  description = "Kubernetes namespace"
  value       = module.namespace.name
}

output "newrelic_dashboard_url" {
  description = "New Relic dashboard permalink (only when newrelic_enabled = true)"
  value       = length(module.observability) > 0 ? module.observability[0].dashboard_permalink : "New Relic disabled"
}

# ---------------------------------------------------------------------------
# RDS PostgreSQL
# ---------------------------------------------------------------------------
output "rds_endpoint" {
  description = "RDS endpoint (host:port)"
  value       = module.rds.endpoint
}

output "rds_address" {
  description = "RDS address (host)"
  value       = module.rds.address
}

output "rds_port" {
  description = "RDS port"
  value       = module.rds.port
}

output "rds_database_name" {
  description = "RDS database name"
  value       = module.rds.database_name
}

output "rds_security_group_id" {
  description = "RDS security group ID"
  value       = module.rds.security_group_id
}

output "postgres_schemas" {
  description = "Postgres schema per SQL microservice"
  value       = module.db_bootstrap.schemas
}

output "postgres_roles" {
  description = "Dedicated Postgres login role per SQL microservice"
  value       = module.db_bootstrap.roles
}

output "postgres_service_credentials" {
  description = "DB_USER / DB_PASSWORD / DB_SCHEMA per SQL microservice (feed into each repo's GitHub Secrets)"
  sensitive   = true
  value = {
    for key, svc in var.postgres_services : key => {
      DB_HOST     = module.rds.address
      DB_PORT     = module.rds.port
      DB_NAME     = module.rds.database_name
      DB_SCHEMA   = svc.schema
      DB_USER     = svc.role
      DB_PASSWORD = random_password.db_service[key].result
    }
  }
}

# ---------------------------------------------------------------------------
# RabbitMQ
# ---------------------------------------------------------------------------
output "rabbitmq_service" {
  description = "RabbitMQ in-cluster service host (AMQP 5672)"
  value       = module.rabbitmq.service_host
}

output "rabbitmq_vhost" {
  description = "RabbitMQ virtual host"
  value       = var.rabbitmq_vhost
}

output "rabbitmq_amqp_url" {
  description = "RabbitMQ AMQP connection URL (in-cluster)"
  value       = module.rabbitmq.amqp_url
  sensitive   = true
}

# ---------------------------------------------------------------------------
# MongoDB
# ---------------------------------------------------------------------------
output "mongodb_service" {
  description = "MongoDB in-cluster service host"
  value       = module.mongodb.service_host
}

output "mongodb_database" {
  description = "MongoDB application database"
  value       = var.mongodb_database
}

output "mongodb_uri" {
  description = "MongoDB connection URI (in-cluster, app user)"
  value       = module.mongodb.app_uri
  sensitive   = true
}
