resource "newrelic_synthetics_monitor" "app_uptime" {
  count = var.synthetics_app_url != "" ? 1 : 0

  name   = "${local.nr_app_name}-uptime"
  type   = "SIMPLE"
  period = "EVERY_MINUTE"
  status = "ENABLED"

  locations_public = ["AWS_US_EAST_1", "AWS_US_WEST_1", "AWS_EU_WEST_1"]

  uri        = "${var.synthetics_app_url}/health"
  verify_ssl = false
}

resource "newrelic_nrql_alert_condition" "synthetics_down" {
  count = var.synthetics_app_url != "" ? 1 : 0

  policy_id = newrelic_alert_policy.main.id
  name      = "Uptime check failing"
  type      = "static"
  enabled   = true

  nrql {
    query = "SELECT count(*) FROM SyntheticCheck WHERE monitorName = '${local.nr_app_name}-uptime' AND result = 'FAILED'"
  }

  critical {
    operator              = "above"
    threshold             = 1
    threshold_duration    = 300
    threshold_occurrences = "all"
  }
}
