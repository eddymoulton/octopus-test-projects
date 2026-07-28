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
#
# Monitors (bottom of this file) sit behind a second gate: they need a Datadog
# APP key as well, so an API-key-only setup still gets metrics without them.

locals {
  datadog_enabled = var.datadog_api_key != ""

  # Monitors go through the Datadog API, which needs an APP key on top of the
  # API key the Agent uses. Gated separately so an API-key-only setup still
  # gets the Agent (metrics flow, no monitors) rather than failing the plan.
  datadog_monitors_enabled = local.datadog_enabled && var.datadog_app_key != ""
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

# --------------------------------------------------------------------------
# Monitors — the Datadog counterpart to the alerting_rules.yml in prometheus.tf.
# --------------------------------------------------------------------------

# Mirrors the AppSuccessRateLow / AppSuccessRateCritical pair as one monitor:
# Datadog escalates warning -> critical on its own, so it needs no equivalent of
# the PromQL rules' explicit `< 0.95 >= 0.8` band to keep the tiers exclusive.
#
# Grouping deliberately diverges from the PromQL `by (service, env, tenant)`.
# Datadog drops any series missing a group-by tag, and the app omits `tenant`
# entirely when unset (the PET contract), so grouping by it would silently
# monitor only the two tenanted payments instances. kube_deployment is always
# present and is one-per-instance, so it restores full coverage while keeping
# the tenants apart — its value already encodes the tenant
# (payments-production-globex).
resource "datadog_monitor" "app_success_rate" {
  count = local.datadog_monitors_enabled ? 1 : 0

  name = "[live-status ${terraform.workspace}] Synthetic app success rate"
  type = "query alert"

  # last_1m carries both roles the PromQL rules split between avg_over_time[20s]
  # and `for: 1m` — Datadog has no separate sustain duration, the window is it.
  query = "avg(last_1m):avg:app_request_success_rate{*} by {service,env,kube_deployment} < 0.8"

  monitor_thresholds {
    warning  = 0.95
    critical = 0.8
  }

  message = <<-EOT
    {{#is_alert}}Success rate critical for {{service.name}}/{{env.name}} ({{kube_deployment.name}}): 1m-averaged app_request_success_rate is {{value}} (< 0.8).{{/is_alert}}
    {{#is_warning}}Success rate low for {{service.name}}/{{env.name}} ({{kube_deployment.name}}): 1m-averaged app_request_success_rate is {{value}} (in [0.8, 0.95)).{{/is_warning}}
    {{#is_no_data}}No success-rate data for {{kube_deployment.name}} — the instance is in absent/down mode or its pod is gone. This is the Unknown state, which is distinct from Unhealthy.{{/is_no_data}}
    {{#is_recovery}}Success rate recovered for {{service.name}}/{{env.name}} ({{kube_deployment.name}}): now {{value}}.{{/is_recovery}}
  EOT

  # The app's absent/down modes stop app_request_success_rate entirely, which is
  # the connector's first-class Unknown state rather than a failure — so it gets
  # its own notification branch above instead of being left silent.
  notify_no_data    = true
  no_data_timeframe = 10

  # The Agent flushes every ~15s and ingestion lags behind that, so the most
  # recent minute is usually still filling. Evaluating a minute back avoids
  # false dips and no-data flaps on a 1m window.
  evaluation_delay = 60

  include_tags = true

  tags = [
    "managed-by:terraform",
    "app:synthetic-service",
    "workspace:${terraform.workspace}",
  ]
}
