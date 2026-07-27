locals {
  base_name    = "${var.project_name}-${var.environment}"
  cluster_name = "${local.base_name}-eks"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }

  resolved_cluster_role_arn = var.eks_cluster_role_arn
  resolved_node_role_arn    = var.eks_node_group_role_arn
  resolved_principal_arn    = var.eks_access_principal_arn
}

# ---------------------------------------------------------------------------
# Network (VPC, public/private subnets, NAT) — foundation for EKS and RDS
# ---------------------------------------------------------------------------
module "network" {
  source               = "./modules/network"
  name                 = local.base_name
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  enable_nat_gateway   = var.enable_nat_gateway
  cluster_name         = local.cluster_name
  tags                 = local.common_tags
}

# ---------------------------------------------------------------------------
# EKS cluster (hosts microservices + RabbitMQ + MongoDB)
# ---------------------------------------------------------------------------
module "eks" {
  source                  = "./modules/eks"
  ebs_csi_enabled         = var.storage_persistence_enabled
  cluster_name            = local.cluster_name
  kubernetes_version      = var.kubernetes_version
  cluster_role_arn        = local.resolved_cluster_role_arn
  node_group_role_arn     = local.resolved_node_role_arn
  public_subnet_ids       = module.network.public_subnet_ids
  private_subnet_ids      = module.network.private_subnet_ids
  endpoint_private_access = var.eks_endpoint_private_access
  endpoint_public_access  = var.eks_endpoint_public_access
  access_principal_arn    = local.resolved_principal_arn
  node_groups             = var.eks_node_groups
  tags                    = local.common_tags
  depends_on              = [module.network]
}

# ---------------------------------------------------------------------------
# Application namespace
# ---------------------------------------------------------------------------
module "namespace" {
  source         = "./modules/kubernetes-namespace"
  namespace_name = var.namespace_name
  environment    = var.environment
  labels         = local.common_tags
  depends_on     = [module.eks]
}

# ---------------------------------------------------------------------------
# Observability (New Relic) — optional
# ---------------------------------------------------------------------------
module "observability" {
  count  = var.newrelic_enabled ? 1 : 0
  source = "./modules/observability"

  newrelic_name        = var.newrelic_name
  newrelic_license_key = var.newrelic_license_key
  newrelic_account_id  = var.newrelic_account_id
  cluster_name         = local.cluster_name
  app_namespace        = module.namespace.name
  app_name             = var.app_name
  environment          = var.environment
  alert_email          = var.alert_email
  synthetics_app_url   = var.synthetics_app_url

  depends_on = [module.eks]
}

# ---------------------------------------------------------------------------
# Relational database (RDS PostgreSQL) — shared, logical isolation per schema
# ---------------------------------------------------------------------------
module "rds" {
  source                  = "./modules/rds"
  identifier              = "${local.base_name}-db"
  engine_version          = var.rds_engine_version
  instance_class          = var.rds_instance_class
  allocated_storage       = var.rds_allocated_storage
  max_allocated_storage   = var.rds_max_allocated_storage
  storage_encrypted       = var.rds_storage_encrypted
  database_name           = var.rds_database_name
  port                    = var.rds_database_port
  master_username         = var.rds_master_username
  master_password         = var.rds_master_password
  vpc_id                  = module.network.vpc_id
  subnet_ids              = module.network.private_subnet_ids
  allowed_security_groups = [module.eks.cluster_security_group_id]
  multi_az                = var.rds_multi_az
  backup_retention_period = var.rds_backup_retention_period
  deletion_protection     = var.rds_deletion_protection
  skip_final_snapshot     = var.rds_skip_final_snapshot
  tags                    = local.common_tags

  depends_on = [module.eks]
}

# ---------------------------------------------------------------------------
# Messaging (RabbitMQ) — deployed on EKS
# ---------------------------------------------------------------------------
module "rabbitmq" {
  source    = "./modules/rabbitmq"
  namespace = module.namespace.name
  username  = var.rabbitmq_username
  password  = var.rabbitmq_password
  vhost     = var.rabbitmq_vhost
  storage   = var.rabbitmq_storage

  persistence_enabled = var.storage_persistence_enabled

  depends_on = [module.namespace]
}

# ---------------------------------------------------------------------------
# NoSQL database (MongoDB) — deployed on EKS (used by billing-service)
# ---------------------------------------------------------------------------
module "mongodb" {
  source        = "./modules/mongodb"
  namespace     = module.namespace.name
  root_username = var.mongodb_root_username
  root_password = var.mongodb_root_password
  database      = var.mongodb_database
  app_username  = var.mongodb_app_username
  app_password  = var.mongodb_app_password
  storage       = var.mongodb_storage

  persistence_enabled = var.storage_persistence_enabled

  depends_on = [module.namespace]
}

# ---------------------------------------------------------------------------
# Bootstrap: create Postgres schemas (os, execution) at provisioning time.
# Runs as a Job inside the cluster (within the VPC -> reaches the private RDS).
# Mongo (app DB + user) and the Rabbit vhost are created by their own modules
# via init-script / env — see modules/mongodb and modules/rabbitmq.
# ---------------------------------------------------------------------------
resource "random_password" "db_service" {
  for_each = var.postgres_services

  length  = 24
  special = false
}

module "db_bootstrap" {
  source    = "./modules/db-bootstrap"
  namespace = module.namespace.name

  postgres_host     = module.rds.address
  postgres_port     = var.rds_database_port
  postgres_database = var.rds_database_name
  postgres_username = var.rds_master_username
  postgres_password = var.rds_master_password

  postgres_services  = var.postgres_services
  postgres_passwords = { for key, _ in var.postgres_services : key => random_password.db_service[key].result }

  depends_on = [module.rds, module.mongodb, module.rabbitmq]
}
