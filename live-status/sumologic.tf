# Optional Sumo Logic path. Deployed only when both Sumo access credentials are
# provided. Terraform creates the hosted collector and the HTTP source, so the
# ingest URL is a computed attribute rather than something pasted in by hand,
# and an OpenTelemetry collector in the cluster scrapes every pod annotated
# prometheus.io/scrape: "true" — the same annotations the synthetic-service pods
# already carry (see ../deployment_processes/synthetic_service_process/
# synthetic-service.tf), and that both Prometheus and the Datadog Agent already
# scrape. So Sumo receives the same app_* metric surface with no app or manifest
# changes.
#
# With no credentials, local.sumologic_enabled is false, every resource here is
# count 0, and the plan is identical to the Prometheus-only setup.
#
# One credential tier, not two: unlike Datadog (API key for the Agent, APP key
# for monitors), Sumo's ingest endpoint is created through the same API that
# manages monitors, so there is nothing to split.

locals {
  # Same suffix agent.tf, prometheus.tf and datadog.tf use, for the same reason:
  # the namespace and the chart's ClusterRole/ClusterRoleBinding are not
  # namespaced, so a second workspace collides without it.
  sumologic_suffix = replace(terraform.workspace, ".", "-")

  sumologic_enabled = var.sumologic_access_id != "" && var.sumologic_access_key != ""

  # Stamped on every metric by the HTTP source, and the scope every monitor
  # query uses. A Sumo org is one namespace for everybody, exactly like a Datadog
  # org — but _sourceCategory is a better discriminator than Datadog's owner tag,
  # because it separates workspaces as well as people. It is also a built-in
  # field, so unlike a custom metadata field it can't be dropped on ingest for
  # being absent from the org's Fields schema.
  sumologic_source_category = "live-status/${var.owner}/${local.sumologic_suffix}"

  # Third gate, on top of the credentials — same shape as Datadog's. Blank the
  # URL and no connection is created; the monitors then notify nothing.
  sumologic_webhook_enabled = local.sumologic_enabled && var.public_webhook_url != ""

  # Connection names are org-global, so they carry owner + workspace: two
  # teammates sharing a name would repoint each other's alerts at the wrong
  # tunnel. Same trap datadog_webhook documents.
  sumologic_connection_name           = "octopus-live-status-health-${var.owner}-${local.sumologic_suffix}"
  sumologic_connection_no_tenant_name = "octopus-live-status-health-${var.owner}-${local.sumologic_suffix}-no-tenant"

  # One body per connection, used for both the triggering and the resolving
  # notification. The receiver tells them apart by status: {{TriggerType}}
  # renders Critical on the way in and ResolvedCritical on the way out, so a
  # single template covers both — the same way Alertmanager's send_resolved
  # reuses one payload.
  #
  # resolution_payload is Optional+Computed, so an unset value is whatever the
  # API decides to store. Setting it explicitly is what guarantees recovery isn't
  # the one transition that arrives in a different shape.
  sumologic_payload = jsonencode({
    alertname   = "AppSuccessRate"
    environment = "{{ResultsJson.environment}}"
    project     = "{{ResultsJson.project}}"
    status      = "{{TriggerType}}"
    tenant      = "{{ResultsJson.tenant}}"
  })

  # tenant is a hardcoded empty string, not {{ResultsJson.tenant}}. Sumo emits an
  # unresolvable field reference VERBATIM — a real event from this connection
  # arrived carrying the literal "{{ResultsJson.tenant}}" as the tenant value,
  # which a receiver would read as a tenant of that name rather than as "no
  # tenant". (Sumo's alert-variables docs say unresolved variables render as "";
  # they do not.) This monitor groups on project/environment only, so the field
  # can never be on the row, and the value is always empty by definition —
  # matching what Datadog's $TAGS[tenant] renders in the same situation.
  sumologic_payload_no_tenant = jsonencode({
    alertname   = "AppSuccessRateNoTenant"
    environment = "{{ResultsJson.environment}}"
    project     = "{{ResultsJson.project}}"
    status      = "{{TriggerType}}"
    tenant      = ""
  })
}

# Hosted collector names are org-global, so this carries owner + workspace.
resource "sumologic_collector" "live_status" {
  count = local.sumologic_enabled ? 1 : 0

  name        = "live-status-${var.owner}-${local.sumologic_suffix}"
  description = "Synthetic-service metrics from the live-status rig (Terraform-managed)."
}

# content_type is deliberately left unset: that is the plain HTTP Logs and
# Metrics source, which is what accepts the OTel exporter's output. Setting it
# would make this an OTLP/Zipkin/RUM source instead.
#
# The exported `url` embeds a token in its path, so it is a credential: it goes
# to Helm via set_sensitive below and must never become a plain output.
resource "sumologic_http_source" "metrics" {
  count = local.sumologic_enabled ? 1 : 0

  name         = "metrics"
  description  = "app_* metrics scraped from synthetic-service pods by the in-cluster OTel collector."
  category     = local.sumologic_source_category
  collector_id = sumologic_collector.live_status[0].id
}

resource "kubernetes_namespace_v1" "sumologic" {
  count = local.sumologic_enabled ? 1 : 0

  metadata {
    name = "live-status-sumologic-${local.sumologic_suffix}"
  }
}

resource "helm_release" "otel_sumologic" {
  count = local.sumologic_enabled ? 1 : 0

  # The release name feeds the chart's fullname template, which names the
  # ClusterRole and ClusterRoleBinding — both cluster-scoped — so the workspace
  # has to be in here. Same collision prometheus.tf handles with
  # server.clusterRoleNameOverride.
  name       = "otel-sumologic-${local.sumologic_suffix}"
  repository = "https://open-telemetry.github.io/opentelemetry-helm-charts"
  chart      = "opentelemetry-collector"
  version    = "0.165.0"
  namespace  = kubernetes_namespace_v1.sumologic[0].metadata[0].name
  atomic     = true
  timeout    = 300

  values = [
    yamlencode({
      # The chart ships no default image, and the contrib distribution is
      # required: sumologicexporter is not in the core collector. command.name is
      # left alone — it already defaults to otelcol-contrib.
      mode = "deployment"
      image = {
        repository = "otel/opentelemetry-collector-contrib"
      }

      # Pod discovery needs cluster-wide read on pods; nodes covers the metadata
      # the receiver's relabeling reads.
      clusterRole = {
        create = true
        rules = [
          {
            apiGroups = [""]
            resources = ["pods", "nodes"]
            verbs     = ["get", "list", "watch"]
          }
        ]
      }

      config = {
        receivers = {
          # The prometheus-community chart's own kubernetes-pods job, reproduced
          # so the two collectors select the same targets by the same rules. The
          # OTel prometheus receiver takes stock Prometheus scrape config, so this
          # is a copy rather than a translation.
          prometheus = {
            config = {
              scrape_configs = [
                {
                  job_name        = "kubernetes-pods"
                  honor_labels    = true
                  scrape_interval = "15s"
                  kubernetes_sd_configs = [
                    { role = "pod" }
                  ]
                  relabel_configs = [
                    # DIVERGENCE from the prometheus-community job, on purpose:
                    # only the app's own pods. Annotation-based discovery also
                    # matches Traefik, the Datadog Agent and Prometheus itself,
                    # which is free for a local Prometheus but not for a Sumo org
                    # shared with the whole team — that would be paid ingest of
                    # cluster infrastructure metrics no part of this rig reads.
                    # The label comes from the app's Deployment template (see
                    # ../deployment_processes/synthetic_service_process/
                    # synthetic-service.tf).
                    {
                      source_labels = ["__meta_kubernetes_pod_label_app"]
                      action        = "keep"
                      regex         = "synthetic-service"
                    },
                    {
                      source_labels = ["__meta_kubernetes_pod_annotation_prometheus_io_scrape"]
                      action        = "keep"
                      regex         = "true"
                    },
                    {
                      source_labels = ["__meta_kubernetes_pod_annotation_prometheus_io_scrape_slow"]
                      action        = "drop"
                      regex         = "true"
                    },
                    {
                      source_labels = ["__meta_kubernetes_pod_annotation_prometheus_io_scheme"]
                      action        = "replace"
                      regex         = "(https?)"
                      target_label  = "__scheme__"
                    },
                    {
                      source_labels = ["__meta_kubernetes_pod_annotation_prometheus_io_path"]
                      action        = "replace"
                      regex         = "(.+)"
                      target_label  = "__metrics_path__"
                    },
                    {
                      source_labels = ["__meta_kubernetes_pod_annotation_prometheus_io_port", "__meta_kubernetes_pod_ip"]
                      action        = "replace"
                      regex         = "(\\d+);(([A-Fa-f0-9]{1,4}::?){1,7}[A-Fa-f0-9]{1,4})"
                      replacement   = "[$2]:$1"
                      target_label  = "__address__"
                    },
                    {
                      source_labels = ["__meta_kubernetes_pod_annotation_prometheus_io_port", "__meta_kubernetes_pod_ip"]
                      action        = "replace"
                      regex         = "(\\d+);((([0-9]+?)(\\.|$)){4})"
                      replacement   = "$2:$1"
                      target_label  = "__address__"
                    },
                    {
                      action      = "labelmap"
                      regex       = "__meta_kubernetes_pod_annotation_prometheus_io_param_(.+)"
                      replacement = "__param_$1"
                    },
                    {
                      action = "labelmap"
                      regex  = "__meta_kubernetes_pod_label_(.+)"
                    },
                    {
                      source_labels = ["__meta_kubernetes_namespace"]
                      action        = "replace"
                      target_label  = "namespace"
                    },
                    {
                      source_labels = ["__meta_kubernetes_pod_name"]
                      action        = "replace"
                      target_label  = "pod"
                    },
                    {
                      source_labels = ["__meta_kubernetes_pod_phase"]
                      regex         = "Pending|Succeeded|Failed|Completed"
                      action        = "drop"
                    },
                    {
                      source_labels = ["__meta_kubernetes_pod_node_name"]
                      action        = "replace"
                      target_label  = "node"
                    },
                  ]
                }
              ]
            }
          }
        }

        exporters = {
          sumologic = {
            # endpoint comes from set_sensitive below — the source URL is a
            # credential and must not appear in plan output.
            #
            # prometheus, not the exporter's default of otlp, and this has to
            # match the source type above. An HTTP Logs and Metrics source
            # accepts Prometheus exposition text, Carbon2 or Graphite — it does
            # not speak OTLP. Point otlp at it and Sumo takes the protobuf as
            # log lines: binary noise lands in the log index under this
            # _sourceCategory, no metrics appear, and nothing errors. The
            # alternative pairing is content_type = "Otlp" on the source with
            # metric_format = "otlp" here.
            metric_format = "prometheus"
          }
        }

        service = {
          pipelines = {
            metrics = {
              receivers  = ["prometheus"]
              processors = ["batch"]
              exporters  = ["sumologic"]
            }
            # Helm coalescing treats an explicit null as a delete, so the chart's
            # default logs/traces pipelines (and the OTLP/Jaeger/Zipkin ports they
            # open) don't run. Nothing here sends logs or traces.
            logs   = null
            traces = null
          }
        }
      }
    })
  ]

  set_sensitive = [
    {
      name  = "config.exporters.sumologic.endpoint"
      value = sumologic_http_source.metrics[0].url
    },
  ]
}

# --------------------------------------------------------------------------
# Monitors and notifications — the Sumo Logic counterpart to the
# alerting_rules.yml / alertmanager route in prometheus.tf and the monitor pair
# in datadog.tf.
# --------------------------------------------------------------------------

# Sumo POSTs from its own servers, like Datadog and unlike Alertmanager, so this
# URL has to be publicly reachable — a tunnel, for a local rig.
#
# The body mirrors the other two providers' flat shape so one endpoint handles
# all three. {{ResultsJson.<field>}} pulls a single field out of the triggering
# row; the PET fields are there because they are the monitor's group fields.
#
# Two values can't match the others exactly, for the same structural reasons
# documented in datadog.tf:
#   status     Sumo's vocabulary is Critical/Warning/MissingData/Resolved*, a
#              third one after Alertmanager's firing/resolved and Datadog's
#              Triggered/Warn/Recovered. Payload templates have no branching, so
#              the mapping belongs in the receiver.
#   alertname  one monitor spans both tiers via warning/critical, so the name
#              distinguishes the grouping rather than the severity.
resource "sumologic_connection" "octopus_health" {
  count = local.sumologic_webhook_enabled ? 1 : 0

  type         = "WebhookConnection"
  webhook_type = "Webhook"
  name         = local.sumologic_connection_name
  description  = "Live Application Status test endpoint (tenant-grouped monitor)."
  url          = var.public_webhook_url

  default_payload    = local.sumologic_payload
  resolution_payload = local.sumologic_payload
}

# Same URL, same five keys, different constant alertname — so the receiver can
# tell a tenant-grouped event from a project/environment-grouped one. `tenant` is
# kept in the body (rendering "") rather than dropped, so every provider and
# every monitor here POST the same shape.
resource "sumologic_connection" "octopus_health_no_tenant" {
  count = local.sumologic_webhook_enabled ? 1 : 0

  type         = "WebhookConnection"
  webhook_type = "Webhook"
  name         = local.sumologic_connection_no_tenant_name
  description  = "Live Application Status test endpoint (no tenant grouping)."
  url          = var.public_webhook_url

  default_payload    = local.sumologic_payload_no_tenant
  resolution_payload = local.sumologic_payload_no_tenant
}

# Mirrors AppSuccessRateLow / AppSuccessRateCritical as one monitor, but NOT the
# way the Datadog monitors do it. Datadog escalates warning -> critical and
# notifies once; Sumo evaluates the two tiers as independent conditions, and
# these thresholds overlap — a success rate of 0.70 satisfies `< 0.95` and
# `< 0.8` both, so both conditions go active and both resolve. Measured: one
# instance recovering sent a ResolvedCritical *and* a ResolvedWarning, in no
# guaranteed order.
#
# Kept as-is deliberately. Over-delivery is the safe direction — every one of
# those events says "healthy now", so a receiver that tracks state per instance
# rather than per event converges correctly. Making the tiers exclusive the way
# the PromQL rules do (`< 0.95 >= 0.8`) isn't expressible in
# metrics_static_condition; it would take two monitors with disjoint queries.
#
# Scoped by _sourceCategory, not by an owner tag: teammates share the org and all
# ship identically-dimensioned app_* series. The category is set on the HTTP
# source, so it also separates workspaces.
#
# `tenant=*` is load-bearing and NOT decoration. Sumo's third distinct behaviour
# for a missing group-by dimension: Prometheus keeps the series with an empty
# label, Datadog silently drops it, and Sumo fails the whole query with
# "Aggregate by non-existent keys". So without this predicate, one untenanted
# instance breaks the query for every instance in it. Requiring the dimension to
# exist confines this monitor to the tenanted instances, and the sibling monitor
# below covers the rest.
resource "sumologic_monitor" "app_success_rate" {
  count = local.sumologic_enabled ? 1 : 0

  # owner-workspace, not owner/workspace as the Datadog monitors use: Sumo
  # rejects "/" in a monitor name, since that is the separator in the Monitors
  # library's folder paths.
  name         = "[live-status ${var.owner}-${terraform.workspace}] Synthetic app success rate"
  description  = "Managed by Terraform (live-status/sumologic.tf). Grouped on project/environment/tenant; tenanted instances only."
  monitor_type = "Metrics"

  queries {
    row_id = "A"
    query  = "_sourceCategory=${local.sumologic_source_category} metric=app_request_success_rate tenant=* | avg by project, environment, tenant"
  }

  trigger_conditions {
    metrics_static_condition {
      critical {
        time_range      = "5m"
        occurrence_type = "Always"

        alert {
          threshold      = 0.8
          threshold_type = "LessThan"
        }

        resolution {
          threshold      = 0.8
          threshold_type = "GreaterThanOrEqual"
        }
      }

      warning {
        time_range      = "5m"
        occurrence_type = "Always"

        alert {
          threshold      = 0.95
          threshold_type = "LessThan"
        }

        resolution {
          threshold      = 0.95
          threshold_type = "GreaterThanOrEqual"
        }
      }
    }

    # The app's absent/down modes stop app_request_success_rate entirely, which
    # is the connector's first-class Unknown state rather than a failure. Same
    # role as notify_no_data on the Datadog monitors.
    metrics_missing_data_condition {
      time_range     = "10m"
      trigger_source = "AnyTimeSeries"
    }
  }

  # Load-bearing, and the direct analogue of Alertmanager's group_by: the payload
  # renders per notification group, so grouping this way is what makes each call
  # carry one application instance's identity instead of collapsing every
  # instance into one call with no usable identity.
  group_notifications       = true
  notification_group_fields = ["project", "environment", "tenant"]

  # The collector batches and ingestion lags behind it, so the most recent minute
  # is usually still filling. Same reasoning as evaluation_delay = 60 on the
  # Datadog monitors.
  evaluation_delay = "1m"

  # No webhook URL means no connection exists, and the monitor simply notifies
  # nobody — the same shape as a Datadog monitor with an empty handle.
  dynamic "notifications" {
    for_each = local.sumologic_webhook_enabled ? [1] : []

    content {
      notification {
        connection_type = "Webhook"
        connection_id   = sumologic_connection.octopus_health[0].id
      }

      run_for_trigger_types = [
        "Critical", "Warning", "MissingData",
        "ResolvedCritical", "ResolvedWarning", "ResolvedMissingData",
      ]
    }
  }
}

# The same monitor grouped one dimension shallower: project/environment only.
# Both dimensions are always present, so every instance produces a group — which
# is what makes the pair cover everything despite the `tenant=*` restriction
# above.
#
# TRADE-OFF, deliberate and matching datadog.tf: rolling tenants up means a bad
# tenant is diluted by its healthy siblings. payments-staging at acme=1.0 /
# globex=0.90 averages 0.95, landing on the warning boundary rather than tripping
# critical, where the tenant-grouped monitor above sees globex at 0.90 directly.
# `avg` is kept so the pair differs only in grouping; swap it for `min` (the
# worst-of fold) if masking matters more than symmetry.
resource "sumologic_monitor" "app_success_rate_no_tenant" {
  count = local.sumologic_enabled ? 1 : 0

  name         = "[live-status ${var.owner}-${terraform.workspace}] Synthetic app success rate (no tenant grouping)"
  description  = "Managed by Terraform (live-status/sumologic.tf). Grouped on project/environment, tenants rolled up."
  monitor_type = "Metrics"

  queries {
    row_id = "A"
    query  = "_sourceCategory=${local.sumologic_source_category} metric=app_request_success_rate | avg by project, environment"
  }

  trigger_conditions {
    metrics_static_condition {
      critical {
        time_range      = "5m"
        occurrence_type = "Always"

        alert {
          threshold      = 0.8
          threshold_type = "LessThan"
        }

        resolution {
          threshold      = 0.8
          threshold_type = "GreaterThanOrEqual"
        }
      }

      warning {
        time_range      = "5m"
        occurrence_type = "Always"

        alert {
          threshold      = 0.95
          threshold_type = "LessThan"
        }

        resolution {
          threshold      = 0.95
          threshold_type = "GreaterThanOrEqual"
        }
      }
    }

    metrics_missing_data_condition {
      time_range     = "10m"
      trigger_source = "AnyTimeSeries"
    }
  }

  group_notifications       = true
  notification_group_fields = ["project", "environment"]

  evaluation_delay = "1m"

  dynamic "notifications" {
    for_each = local.sumologic_webhook_enabled ? [1] : []

    content {
      notification {
        connection_type = "Webhook"
        connection_id   = sumologic_connection.octopus_health_no_tenant[0].id
      }

      run_for_trigger_types = [
        "Critical", "Warning", "MissingData",
        "ResolvedCritical", "ResolvedWarning", "ResolvedMissingData",
      ]
    }
  }
}
