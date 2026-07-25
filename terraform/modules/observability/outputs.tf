output "alert_policy_id" {
  description = "New Relic alert policy ID"
  value       = newrelic_alert_policy.main.id
}

output "dashboard_permalink" {
  description = "New Relic dashboard permalink"
  value       = newrelic_one_dashboard.main.permalink
}

output "newrelic_namespace" {
  description = "Kubernetes namespace for New Relic agents"
  value       = kubernetes_namespace.newrelic.metadata[0].name
}
