terraform {
  required_providers {
    newrelic = {
      source  = "newrelic/newrelic"
      version = "~> 3.30"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
}

resource "kubernetes_namespace" "newrelic" {
  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

resource "helm_release" "newrelic_bundle" {
  name       = var.newrelic_name
  repository = "https://helm-charts.newrelic.com"
  chart      = "nri-bundle"
  version    = "5.0.109"
  namespace  = kubernetes_namespace.newrelic.metadata[0].name

  wait    = false
  timeout = 300

  set {
    name  = "global.licenseKey"
    value = var.newrelic_license_key
  }

  set {
    name  = "global.cluster"
    value = var.cluster_name
  }

  set {
    name  = "newrelic-infrastructure.enabled"
    value = "true"
  }

  set {
    name  = "kube-state-metrics.enabled"
    value = "true"
  }

  set {
    name  = "nri-kube-events.enabled"
    value = "true"
  }

  set {
    name  = "newrelic-logging.enabled"
    value = "true"
  }

  set {
    name  = "newrelic-prometheus-agent.enabled"
    value = "true"
  }

  # Pixie desligado: consome CPU extra, desnecessário para este lab
  set {
    name  = "pixie.enabled"
    value = "false"
  }

  depends_on = [kubernetes_namespace.newrelic]
}
