resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = var.cluster_role_arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = concat(var.public_subnet_ids, var.private_subnet_ids)
    endpoint_private_access = var.endpoint_private_access
    endpoint_public_access  = var.endpoint_public_access
    public_access_cidrs     = var.public_access_cidrs
  }

  access_config {
    authentication_mode = "API_AND_CONFIG_MAP"
  }

  enabled_cluster_log_types = var.enabled_cluster_log_types

  tags = merge(var.tags, { Name = var.cluster_name })
}

resource "aws_eks_node_group" "main" {
  for_each = var.node_groups

  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-${each.key}"
  node_role_arn   = var.node_group_role_arn
  subnet_ids      = var.private_subnet_ids

  instance_types = each.value.instance_types
  capacity_type  = each.value.capacity_type
  disk_size      = each.value.disk_size

  scaling_config {
    desired_size = each.value.desired_size
    min_size     = each.value.min_size
    max_size     = each.value.max_size
  }

  update_config {
    max_unavailable = each.value.max_unavailable
  }

  labels = merge(var.tags, each.value.labels)

  tags = merge(var.tags, { Name = "${var.cluster_name}-${each.key}" })

  depends_on = [aws_eks_cluster.main]
}

resource "aws_eks_access_entry" "main" {
  count = var.access_principal_arn != null ? 1 : 0

  cluster_name      = aws_eks_cluster.main.name
  principal_arn     = var.access_principal_arn
  kubernetes_groups = var.access_principal_groups
  type              = "STANDARD"

  depends_on = [aws_eks_cluster.main]
}

resource "aws_eks_access_policy_association" "main" {
  count = var.access_principal_arn != null ? length(var.access_policies) : 0

  cluster_name  = aws_eks_cluster.main.name
  principal_arn = var.access_principal_arn
  policy_arn    = var.access_policies[count.index]

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.main]
}
