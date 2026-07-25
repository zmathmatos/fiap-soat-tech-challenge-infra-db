locals {
  nr_app_name = "${var.app_name}-${var.environment}"
}

resource "newrelic_alert_policy" "main" {
  name                = "${local.nr_app_name}-alerts"
  incident_preference = "PER_CONDITION"
}

resource "newrelic_nrql_alert_condition" "api_latency_high" {
  policy_id = newrelic_alert_policy.main.id
  name      = "API p95 latency > 1s"
  type      = "static"
  enabled   = true

  nrql {
    query = "SELECT percentile(duration, 95) FROM Transaction WHERE appName = '${local.nr_app_name}'"
  }

  warning {
    operator              = "above"
    threshold             = 0.5
    threshold_duration    = 300
    threshold_occurrences = "all"
  }

  critical {
    operator              = "above"
    threshold             = 1
    threshold_duration    = 300
    threshold_occurrences = "all"
  }
}

resource "newrelic_nrql_alert_condition" "api_error_rate" {
  policy_id = newrelic_alert_policy.main.id
  name      = "API error rate > 5%"
  type      = "static"
  enabled   = true

  nrql {
    query = "SELECT percentage(count(*), WHERE error IS true) FROM Transaction WHERE appName = '${local.nr_app_name}'"
  }

  critical {
    operator              = "above"
    threshold             = 5
    threshold_duration    = 300
    threshold_occurrences = "all"
  }
}

resource "newrelic_nrql_alert_condition" "pod_cpu_high" {
  policy_id = newrelic_alert_policy.main.id
  name      = "Pod CPU > 85%"
  type      = "static"
  enabled   = true

  nrql {
    query = "SELECT average(cpuUsedCores / cpuLimitCores) * 100 FROM K8sContainerSample WHERE namespaceName = '${var.app_namespace}' AND cpuLimitCores > 0"
  }

  warning {
    operator              = "above"
    threshold             = 85
    threshold_duration    = 600
    threshold_occurrences = "all"
  }
}

resource "newrelic_nrql_alert_condition" "pod_memory_high" {
  policy_id = newrelic_alert_policy.main.id
  name      = "Pod memory > 85%"
  type      = "static"
  enabled   = true

  nrql {
    query = "SELECT average(memoryWorkingSetBytes / memoryLimitBytes) * 100 FROM K8sContainerSample WHERE namespaceName = '${var.app_namespace}' AND memoryLimitBytes > 0"
  }

  warning {
    operator              = "above"
    threshold             = 85
    threshold_duration    = 600
    threshold_occurrences = "all"
  }
}

resource "newrelic_nrql_alert_condition" "pod_crash_loop" {
  policy_id = newrelic_alert_policy.main.id
  name      = "Pod CrashLoopBackOff"
  type      = "static"
  enabled   = true

  nrql {
    query = "FROM K8sPodSample SELECT count(*) WHERE namespaceName = '${var.app_namespace}' AND status = 'Failed'"
  }

  critical {
    operator              = "above"
    threshold             = 0
    threshold_duration    = 60
    threshold_occurrences = "at_least_once"
  }
}

resource "newrelic_nrql_alert_condition" "order_processing_errors" {
  policy_id = newrelic_alert_policy.main.id
  name      = "Order processing failures > 0 in 5min"
  type      = "static"
  enabled   = true

  nrql {
    query = "FROM Metric SELECT sum(newrelic.timeslice.value) WHERE metricTimesliceName = 'Custom/ServiceOrder/Failed' AND appName = '${local.nr_app_name}'"
  }

  critical {
    operator              = "above"
    threshold             = 0
    threshold_duration    = 300
    threshold_occurrences = "at_least_once"
  }
}

resource "newrelic_nrql_alert_condition" "external_integration_errors" {
  policy_id = newrelic_alert_policy.main.id
  name      = "External integration errors > 3 in 5min"
  type      = "static"
  enabled   = true

  nrql {
    query = "FROM Transaction SELECT count(*) WHERE appName = '${local.nr_app_name}' AND name LIKE '%external%' AND error IS true"
  }

  warning {
    operator              = "above"
    threshold             = 3
    threshold_duration    = 300
    threshold_occurrences = "all"
  }
}

resource "newrelic_notification_destination" "email" {
  name = "${local.nr_app_name}-email"
  type = "EMAIL"

  property {
    key   = "email"
    value = var.alert_email
  }
}

resource "newrelic_notification_channel" "email" {
  name           = "${local.nr_app_name}-email-channel"
  type           = "EMAIL"
  destination_id = newrelic_notification_destination.email.id
  product        = "IINT"

  property {
    key   = "subject"
    value = "[${local.nr_app_name}] Alert: {{ issueTitle }}"
  }
}

resource "newrelic_workflow" "main" {
  name                  = "${local.nr_app_name}-workflow"
  muting_rules_handling = "DONT_NOTIFY_FULLY_MUTED_ISSUES"
  enabled               = true

  issues_filter {
    name = "policy-filter"
    type = "FILTER"

    predicate {
      attribute = "labels.policyIds"
      operator  = "EXACTLY_MATCHES"
      values    = [tostring(newrelic_alert_policy.main.id)]
    }
  }

  destination {
    channel_id            = newrelic_notification_channel.email.id
    notification_triggers = ["ACTIVATED", "ACKNOWLEDGED", "CLOSED"]
  }
}
