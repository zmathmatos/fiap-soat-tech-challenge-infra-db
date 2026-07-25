resource "newrelic_one_dashboard" "main" {
  name        = "${local.nr_app_name}-observability"
  permissions = "public_read_only"

  page {
    name = "Ordens de Servico"

    widget_billboard {
      title  = "Volume de OS criadas (24h)"
      row    = 1
      column = 1
      width  = 4
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "FROM ServiceOrderEvent SELECT count(*) WHERE event = 'order.created' AND appName = '${local.nr_app_name}' SINCE 24 hours ago"
      }
    }

    widget_line {
      title  = "Volume de OS criadas por hora (7 dias)"
      row    = 1
      column = 5
      width  = 8
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "FROM ServiceOrderEvent SELECT count(*) WHERE event = 'order.created' AND appName = '${local.nr_app_name}' SINCE 7 days ago TIMESERIES 1 hour"
      }
    }

    widget_bar {
      title  = "Tempo medio por status de OS (segundos)"
      row    = 4
      column = 1
      width  = 6
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "FROM ServiceOrderEvent SELECT average(timeInPreviousStatusMs) / 1000 AS 'segundos' WHERE event = 'order.processed' AND appName = '${local.nr_app_name}' AND previousStatus IN ('RECEBIDO', 'DIAGNOSTICO', 'AGUARDANDO_APROVACAO', 'EXECUCAO', 'FINALIZACAO') FACET previousStatus SINCE 24 hours ago"
      }
    }

    widget_pie {
      title  = "Distribuicao de OS por status (7d)"
      row    = 4
      column = 7
      width  = 6
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "FROM ServiceOrderEvent SELECT count(*) WHERE appName = '${local.nr_app_name}' FACET status SINCE 7 days ago"
      }
    }

    widget_billboard {
      title  = "Falhas no processamento de OS (24h)"
      row    = 7
      column = 1
      width  = 4
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "FROM Metric SELECT sum(newrelic.timeslice.value) AS 'falhas' WHERE metricTimesliceName = 'Custom/ServiceOrder/Failed' AND appName = '${local.nr_app_name}' SINCE 24 hours ago"
      }
    }

    widget_line {
      title  = "Falhas e erros nas integracoes (timeseries)"
      row    = 7
      column = 5
      width  = 8
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "FROM Transaction SELECT count(*) WHERE appName = '${local.nr_app_name}' AND error IS true FACET name SINCE 24 hours ago TIMESERIES"
      }
    }
  }

  page {
    name = "Performance APIs"

    widget_line {
      title  = "Latencia p50 / p95 / p99"
      row    = 1
      column = 1
      width  = 12
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "FROM Transaction SELECT percentile(duration, 50, 95, 99) WHERE appName = '${local.nr_app_name}' FACET name SINCE 1 hour ago TIMESERIES"
      }
    }

    widget_billboard {
      title  = "Error rate (%)"
      row    = 4
      column = 1
      width  = 4
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "FROM Transaction SELECT percentage(count(*), WHERE error IS true) AS 'Error rate %' WHERE appName = '${local.nr_app_name}' SINCE 1 hour ago"
      }
    }

    widget_line {
      title  = "Throughput (req/min)"
      row    = 4
      column = 5
      width  = 8
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "FROM Transaction SELECT rate(count(*), 1 minute) WHERE appName = '${local.nr_app_name}' SINCE 1 hour ago TIMESERIES"
      }
    }

    widget_table {
      title  = "Top endpoints por throughput"
      row    = 7
      column = 1
      width  = 12
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "FROM Transaction SELECT count(*), average(duration) * 1000 AS 'avg ms', percentile(duration, 95) * 1000 AS 'p95 ms' WHERE appName = '${local.nr_app_name}' FACET request.uri SINCE 1 hour ago LIMIT 25"
      }
    }
  }

  page {
    name = "Kubernetes"

    widget_line {
      title  = "CPU por pod (mCores)"
      row    = 1
      column = 1
      width  = 6
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "FROM K8sContainerSample SELECT average(cpuUsedCores * 1000) AS 'mCores' WHERE namespaceName = '${var.app_namespace}' FACET podName SINCE 1 hour ago TIMESERIES"
      }
    }

    widget_line {
      title  = "Memoria por pod (MiB)"
      row    = 1
      column = 7
      width  = 6
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "FROM K8sContainerSample SELECT average(memoryWorkingSetBytes / 1048576) AS 'MiB' WHERE namespaceName = '${var.app_namespace}' FACET podName SINCE 1 hour ago TIMESERIES"
      }
    }

    widget_billboard {
      title  = "Pods Running"
      row    = 4
      column = 1
      width  = 4
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "FROM K8sPodSample SELECT uniqueCount(podName) WHERE namespaceName = '${var.app_namespace}' AND status = 'Running' SINCE 5 minutes ago"
      }
    }

    widget_billboard {
      title  = "Pods Failed"
      row    = 4
      column = 5
      width  = 4
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "FROM K8sPodSample SELECT uniqueCount(podName) WHERE namespaceName = '${var.app_namespace}' AND status = 'Failed' SINCE 5 minutes ago"
      }
    }

    widget_billboard {
      title  = "HPA Replicas"
      row    = 4
      column = 9
      width  = 4
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "FROM K8sHpaSample SELECT latest(currentReplicas) AS 'Current', latest(desiredReplicas) AS 'Desired', latest(maxReplicas) AS 'Max' WHERE namespaceName = '${var.app_namespace}' SINCE 5 minutes ago"
      }
    }
  }
}
