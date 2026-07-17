# Optional Datadog Agent. Deployed into the Colima cluster only when a Datadog
# API key is provided (var.datadog_api_key). It uses Datadog's Prometheus
# autodiscovery (datadog.prometheusScrape.enabled) to scrape every pod annotated
# prometheus.io/scrape: "true" — the same annotations the synthetic-service pods
# already carry (see ../deployment_processes/synthetic_service_process/
# synthetic-service.tf) and that Prometheus already scrapes. So Datadog receives
# the same app_* metric surface with no app or manifest changes.
#
# With no key, local.datadog_enabled is false, every resource here is count 0,
# and the plan is identical to the Prometheus-only setup.

locals {
  datadog_enabled = var.datadog_api_key != ""
}

resource "kubernetes_namespace_v1" "datadog" {
  count = local.datadog_enabled ? 1 : 0

  metadata {
    name = "datadog-${replace(terraform.workspace, ".", "-")}"
  }
}

resource "helm_release" "datadog" {
  count = local.datadog_enabled ? 1 : 0

  name       = "datadog-${replace(terraform.workspace, ".", "-")}"
  repository = "https://helm.datadoghq.com"
  chart      = "datadog"
  version    = "3.231.4"
  namespace  = kubernetes_namespace_v1.datadog[0].metadata[0].name
  atomic     = true
  timeout    = 300

  set = [
    {
      name  = "datadog.site"
      value = var.datadog_site
    },
    {
      name  = "datadog.clusterName"
      value = "live-status-${replace(terraform.workspace, ".", "-")}"
    },
    # Reuse the pods' prometheus.io/* annotations; collects all exposed metrics.
    {
      name  = "datadog.prometheusScrape.enabled"
      value = "true"
    },
    # Lean, metrics-only footprint for a local single-node cluster.
    {
      name  = "datadog.logs.enabled"
      value = "false"
    },
    {
      name  = "datadog.apm.portEnabled"
      value = "false"
    },
    {
      name  = "datadog.apm.socketEnabled"
      value = "false"
    },
    {
      name  = "datadog.processAgent.enabled"
      value = "false"
    },
    {
      name  = "datadog.orchestratorExplorer.enabled"
      value = "false"
    },
    # Node-based prometheusScrape runs entirely in the node Agent DaemonSet, so
    # the Cluster Agent Deployment isn't needed on this single-node cluster.
    # (clusterAgent.* is a top-level chart key, not under datadog.*)
    {
      name  = "clusterAgent.enabled"
      value = "false"
    },
  ]

  set_sensitive = [
    {
      name  = "datadog.apiKey"
      value = var.datadog_api_key
    },
  ]
}
