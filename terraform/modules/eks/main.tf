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

# Launch template so pods can reach IMDS (hop limit 2). The default managed
# node group config uses hop limit 1 + IMDSv2, which blocks containers (e.g.
# the EBS CSI controller) from getting node credentials — required in AWS
# Academy, where IRSA/Pod Identity are unavailable.
resource "aws_launch_template" "node" {
  for_each = var.node_groups

  name_prefix = "${var.cluster_name}-${each.key}-"

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = each.value.disk_size
      volume_type = "gp3"
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  tag_specifications {
    resource_type = "instance"
    tags          = merge(var.tags, { Name = "${var.cluster_name}-${each.key}" })
  }
}

resource "aws_eks_node_group" "main" {
  for_each = var.node_groups

  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-${each.key}"
  node_role_arn   = var.node_group_role_arn
  subnet_ids      = var.private_subnet_ids

  instance_types = each.value.instance_types
  capacity_type  = each.value.capacity_type

  launch_template {
    id      = aws_launch_template.node[each.key].id
    version = aws_launch_template.node[each.key].latest_version
  }

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

# EBS CSI driver: required since K8s 1.23 for PVCs (RabbitMQ/MongoDB volumes).
# Without it the gp2 StorageClass cannot provision volumes and pods stay Pending.
# Pods run on the node role (AWS Academy: LabRole), which already has EC2/EBS access.
resource "aws_eks_addon" "ebs_csi" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "aws-ebs-csi-driver"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [aws_eks_node_group.main]
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
