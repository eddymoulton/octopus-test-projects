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

  # Webhooks are org-global in Datadog, not scoped to a cluster or a space, and
  # the name is the addressing key the monitor uses (@webhook-<name>) — so it
  # carries the owner as well as the workspace. Two teammates sharing a name
  # would silently repoint each other's alerts at the wrong tunnel. The handle
  # is built from the same local rather than from the resource, so the monitor's
  # message doesn't depend on the webhook's computed attributes.
  datadog_webhook_enabled = local.datadog_monitors_enabled && var.public_webhook_url != ""
  datadog_webhook_name    = "octopus-live-status-health-${var.owner}-${replace(terraform.workspace, ".", "-")}"

  # The no-tenant monitor gets its own webhook pointing at the same URL. It
  # exists only to carry a different constant alertname: payload templates have
  # no branching, so one webhook per monitor is the only way the receiver can
  # tell which grouping produced an event.
  datadog_webhook_no_tenant_name = "${local.datadog_webhook_name}-no-tenant"

  # nonsensitive() because the enable flag derives from the (sensitive) key
  # variables, and without it that taint spreads into the monitor's message and
  # redacts the whole thing in plan output. The handle is only a name.
  datadog_webhook_handle           = nonsensitive(local.datadog_webhook_enabled) ? "@webhook-${local.datadog_webhook_name}" : ""
  datadog_webhook_no_tenant_handle = nonsensitive(local.datadog_webhook_enabled) ? "@webhook-${local.datadog_webhook_no_tenant_name}" : ""
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
      name = "datadog.clusterName"
      # Owner-scoped too: teammates share a Datadog org, and two clusters with
      # the same name make Datadog's Kubernetes views ambiguous even though the
      # owner tag below is what the monitor actually filters on.
      value = "live-status-${var.owner}-${replace(terraform.workspace, ".", "-")}"
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

  # Global tag stamped on every metric this Agent ships. This is what makes a
  # shared Datadog org workable: without it every teammate's app_* series are
  # indistinguishable, and a monitor querying {*} alerts on everyone's pods.
  # set_list rather than set because datadog.tags is a list.
  set_list = [
    {
      name  = "datadog.tags"
      value = ["owner:${var.owner}"]
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
# Monitors and notifications — the Datadog counterpart to the
# alerting_rules.yml / alertmanager route in prometheus.tf.
# --------------------------------------------------------------------------

# Datadog POSTs here from its own servers, so unlike the Alertmanager webhook
# (which posts from inside the cluster to host.lima.internal) this URL has to be
# publicly reachable — a tunnel, for a local rig.
#
# The body deliberately mirrors the Alertmanager webhook's flat shape so one
# endpoint can handle both. $TAGS[key] pulls a single tag out by name; per the
# docs it yields an empty string when the tag is absent or valueless.
#
# Three values can't be reproduced exactly on this side — see the README for the
# reasoning and the options:
#   alertname  one Datadog monitor spans both tiers, so there is no per-tier
#              name to emit; it is a constant here.
#   status     Datadog's vocabulary is Triggered/Warn/Recovered/No Data, not
#              Alertmanager's firing/resolved. No branching in a payload
#              template, so the mapping belongs in the receiver.
#   tenant     in this monitor's group_by, so it resolves. Untenanted instances
#              don't reach this webhook at all — grouping on tenant excludes
#              them, which is what the sibling no-tenant monitor below covers.
resource "datadog_webhook" "health_events" {
  count = local.datadog_webhook_enabled ? 1 : 0

  name      = local.datadog_webhook_name
  url       = var.public_webhook_url
  encode_as = "json"

  # No `value` key: Datadog has no webhook variable for the evaluated number —
  # it reaches the body only inside the rendered message ($EVENT_MSG), as prose.
  # Left out rather than shipped as a sentence the receiver would have to parse.
  #
  # $LINK is the event that triggered the webhook. origin is a constant for the
  # same reason as the other two providers; $ORG_NAME is available if the Datadog
  # org itself ever needs identifying, but that is what the connection knows.
  payload = jsonencode({
    alertname   = "AppSuccessRate"
    environment = "$TAGS[environment]"
    project     = "$TAGS[project]"
    status      = "$ALERT_TRANSITION"
    tenant      = "$TAGS[tenant]"
    provider    = "datadog"
    origin      = local.rig_instance
    link        = "$LINK"
  })
}

# Same URL, same five keys, different constant alertname — so the receiver can
# tell a tenant-grouped event from a project/environment-grouped one. `tenant` is
# kept in the body (rendering "") rather than dropped, so every provider and
# every monitor here POST the same shape.
resource "datadog_webhook" "health_events_no_tenant" {
  count = local.datadog_webhook_enabled ? 1 : 0

  name      = local.datadog_webhook_no_tenant_name
  url       = var.public_webhook_url
  encode_as = "json"

  payload = jsonencode({
    alertname   = "AppSuccessRateNoTenant"
    environment = "$TAGS[environment]"
    project     = "$TAGS[project]"
    status      = "$ALERT_TRANSITION"
    tenant      = "$TAGS[tenant]"
    provider    = "datadog"
    origin      = local.rig_instance
    link        = "$LINK"
  })
}

# Mirrors the AppSuccessRateLow / AppSuccessRateCritical pair as one monitor:
# Datadog escalates warning -> critical on its own, so it needs no equivalent of
# the PromQL rules' explicit `< 0.95 >= 0.8` band to keep the tiers exclusive.
#
# Grouped on the same PET labels as the PromQL rules now that the app emits
# them under those names.
#
# SCOPE: this monitor sees only the tenanted instances. Datadog excludes any
# series missing a group-by tag, and the app omits `tenant` entirely when unset,
# so payments-production-acme and payments-production-globex produce groups and
# checkout-production-untenanted, checkout-staging-untenanted and
# payments-staging-untenanted silently produce none. (Those three carry
# `untenanted` in their *name* only — the label itself is still unset, which is
# what Datadog excludes on.) That exclusion is not worked around here — the sibling
# app_success_rate_no_tenant monitor below covers the same five instances without
# the tenant dimension, so between the pair every instance is monitored and both
# payload shapes reach the receiver.
resource "datadog_monitor" "app_success_rate" {
  count = local.datadog_monitors_enabled ? 1 : 0

  name = "[live-status ${var.owner}/${terraform.workspace}] Synthetic app success rate"
  type = "query alert"

  # last_1m carries both roles the PromQL rules split between avg_over_time[20s]
  # and `for: 1m` — Datadog has no separate sustain duration, the window is it.
  #
  # Scoped to {owner:…}, not {*}: teammates share the Datadog org and all ship
  # identically-tagged app_* series, so an unscoped query alerts on everyone's
  # instances. The tag comes from the Agent's datadog.tags above.
  query = "avg(last_1m):avg:app_request_success_rate{owner:${var.owner}} by {project,environment,tenant} < 0.8"

  monitor_thresholds {
    warning  = 0.95
    critical = 0.8
  }

  message = <<-EOT
    {{#is_alert}}Success rate critical for {{project.name}}/{{environment.name}} ({{tenant.name}}): 1m-averaged app_request_success_rate is {{value}} (< 0.8).{{/is_alert}}
    {{#is_warning}}Success rate low for {{project.name}}/{{environment.name}} ({{tenant.name}}): 1m-averaged app_request_success_rate is {{value}} (in [0.8, 0.95)).{{/is_warning}}
    {{#is_no_data}}No success-rate data for {{project.name}}/{{environment.name}} (tenant {{tenant.name}}) — the instance is in absent/down mode or its pod is gone. This is the Unknown state, which is distinct from Unhealthy.{{/is_no_data}}
    {{#is_recovery}}Success rate recovered for {{project.name}}/{{environment.name}} ({{tenant.name}}): now {{value}}.{{/is_recovery}}

    ${local.datadog_webhook_handle}
  EOT

  # The handle above is deliberately outside every {{#is_*}} block. A handle
  # nested in one only fires for that state; at the top level it fires on every
  # transition the monitor notifies about — triggered, warning, recovery, and
  # (because notify_no_data is on) no data.
  depends_on = [datadog_webhook.health_events]

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
    "owner:${var.owner}",
    "workspace:${terraform.workspace}",
    "grouping:project-environment-tenant",
  ]
}

# The same monitor grouped one dimension shallower: project/environment only.
# Both tags are always present, so nothing is excluded and all five instances
# produce a group — which is the point of running the pair.
#
# TRADE-OFF, deliberate: rolling tenants up means a single bad tenant is diluted
# by its healthy siblings. payments-production at acme=1.0 / globex=0.90 averages
# 0.95, which lands on the warning boundary rather than tripping critical, where
# the tenant-grouped monitor above sees globex at 0.90 directly. `avg:` is kept so
# this stays a true duplicate of that monitor, differing only in group_by; swap it
# for `min:` (the worst-of fold) if masking matters more than symmetry.
resource "datadog_monitor" "app_success_rate_no_tenant" {
  count = local.datadog_monitors_enabled ? 1 : 0

  name = "[live-status ${var.owner}/${terraform.workspace}] Synthetic app success rate (no tenant grouping)"
  type = "query alert"

  query = "avg(last_1m):avg:app_request_success_rate{owner:${var.owner}} by {project,environment} < 0.8"

  monitor_thresholds {
    warning  = 0.95
    critical = 0.8
  }

  # No tenant in the message: it isn't a group tag here, so {{tenant.name}} has
  # nothing to resolve against.
  message = <<-EOT
    {{#is_alert}}Success rate critical for {{project.name}}/{{environment.name}}: 1m-averaged app_request_success_rate is {{value}} (< 0.8), averaged across all tenants.{{/is_alert}}
    {{#is_warning}}Success rate low for {{project.name}}/{{environment.name}}: 1m-averaged app_request_success_rate is {{value}} (in [0.8, 0.95)), averaged across all tenants.{{/is_warning}}
    {{#is_no_data}}No success-rate data for {{project.name}}/{{environment.name}} — every instance in it is in absent/down mode or its pod is gone. This is the Unknown state, which is distinct from Unhealthy.{{/is_no_data}}
    {{#is_recovery}}Success rate recovered for {{project.name}}/{{environment.name}}: now {{value}}.{{/is_recovery}}

    ${local.datadog_webhook_no_tenant_handle}
  EOT

  depends_on = [datadog_webhook.health_events_no_tenant]

  notify_no_data    = true
  no_data_timeframe = 10

  evaluation_delay = 60

  include_tags = true

  tags = [
    "managed-by:terraform",
    "app:synthetic-service",
    "owner:${var.owner}",
    "workspace:${terraform.workspace}",
    "grouping:project-environment",
  ]
}
