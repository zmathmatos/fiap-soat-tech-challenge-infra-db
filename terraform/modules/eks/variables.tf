variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.32"
}

variable "cluster_role_arn" {
  description = "EKS cluster IAM role ARN"
  type        = string
}

variable "node_group_role_arn" {
  description = "EKS node group IAM role ARN"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "Private subnet IDs"
  type        = list(string)
}

variable "endpoint_private_access" {
  description = "Enable private API endpoint"
  type        = bool
  default     = true
}

variable "endpoint_public_access" {
  description = "Enable public API endpoint"
  type        = bool
  default     = true
}

variable "public_access_cidrs" {
  description = "CIDR blocks allowed to access public endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enabled_cluster_log_types" {
  description = "Cluster log types to enable"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "node_groups" {
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
      labels          = {}
    }
  }
}

variable "access_principal_arn" {
  description = "IAM principal ARN for cluster access"
  type        = string
  default     = null
}

variable "access_principal_groups" {
  description = "Kubernetes groups for principal"
  type        = list(string)
  default     = []
}

variable "access_policies" {
  description = "EKS access policies for principal"
  type        = list(string)
  default = [
    "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy",
    "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminPolicy"
  ]
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}

variable "ebs_csi_enabled" {
  description = "Install the aws-ebs-csi-driver addon. Requires EBS permissions on the node role"
  type        = bool
  default     = true
}
