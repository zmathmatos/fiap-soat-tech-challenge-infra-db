terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    newrelic = {
      source  = "newrelic/newrelic"
      version = "~> 3.30"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Provider config comes straight from the eks module outputs (not data sources
# with depends_on): deferred data reads would leave the provider unconfigured
# ("localhost" errors) whenever module.eks has pending changes. The exec plugin
# fetches a fresh token on every call, avoiding 15-min token expiry on long applies.
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.aws_region]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.aws_region]
    }
  }
}

# The New Relic client rejects an empty api_key even when no resource uses the
# provider (newrelic_enabled = false), so fall back to a syntactically valid dummy.
provider "newrelic" {
  account_id = var.newrelic_account_id != 0 ? var.newrelic_account_id : 1
  api_key    = var.newrelic_api_key != "" ? var.newrelic_api_key : "NRAK-0000000000000000000000000"
  region     = "US"
}
