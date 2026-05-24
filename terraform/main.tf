terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "terraform_remote_state" "infra_k8s" {
  backend = "s3"
  config = {
    bucket = var.state_bucket
    key    = "infra-k8s/terraform.tfstate"
    region = "us-east-1"
  }
}

locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

module "rds" {
  source                  = "./modules/rds"
  identifier              = "${var.project_name}-${var.environment}-db"
  engine_version          = var.rds_engine_version
  instance_class          = var.rds_instance_class
  allocated_storage       = var.rds_allocated_storage
  max_allocated_storage   = var.rds_max_allocated_storage
  storage_encrypted       = var.rds_storage_encrypted
  database_name           = var.rds_database_name
  port                    = var.rds_database_port
  master_username         = var.rds_master_username
  master_password         = var.rds_master_password
  vpc_id                  = data.terraform_remote_state.infra_k8s.outputs.vpc_id
  subnet_ids              = data.terraform_remote_state.infra_k8s.outputs.private_subnet_ids
  allowed_security_groups = [data.terraform_remote_state.infra_k8s.outputs.eks_cluster_security_group_id]
  multi_az                = var.rds_multi_az
  backup_retention_period = var.rds_backup_retention_period
  deletion_protection     = var.rds_deletion_protection
  skip_final_snapshot     = var.rds_skip_final_snapshot
  tags                    = local.common_tags
}
