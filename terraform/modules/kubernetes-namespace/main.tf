resource "kubernetes_namespace" "this" {
  metadata {
    name = var.namespace_name
    labels = merge(
      var.labels,
      {
        name        = var.namespace_name
        environment = var.environment
      }
    )
  }
}
