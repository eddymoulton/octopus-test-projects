# Prometheus, deployed by Terraform via the prometheus-community Helm chart.
# Previously stood up by an Octopus "Infrastructure" deployment process
# (../deployment_processes/prometheus_process); now it mirrors the agent.tf /
# datadog.tf pattern — a namespace + a helm_release into the Colima cluster, up
# at `terraform apply`.
#
# Trimmed to the server plus alertmanager (no pushgateway / node-exporter /
# kube-state-metrics). Alertmanager was originally trimmed too, but Prometheus
# alone can't notify anything — alerting rules only fire alerts internally, and
# delivering them is Alertmanager's job — so it's back, carrying the webhook to
# the Octopus test endpoint.
# The chart's default `kubernetes-pods` scrape job keeps
# pods annotated prometheus.io/scrape: "true" — the same annotations the
# synthetic-service pods carry — so Prometheus scrapes them with no app changes.
# server.fullnameOverride + servicePort keep the Service named `prometheus` on
# 9090, so existing `svc/prometheus 9090` port-forwards keep working; the
# Ingress is at http://prometheus-<workspace>.localhost.
#
# Everything cluster-scoped here is suffixed with the workspace so the config
# can be applied into several workspaces against the same cluster.

locals {
  # Everything this file creates that lives in a cluster-wide namespace — the
  # Namespace itself, the chart's ClusterRole/ClusterRoleBinding, and the
  # Ingress hostname — has to carry the workspace, or a second workspace
  # collides with the first. Matches the suffix agent.tf and datadog.tf use.
  monitoring_suffix = replace(terraform.workspace, ".", "-")

  # Shared base query for the success-rate alert tiers.
  success_rate_20s = "avg by (project, environment, tenant) (avg_over_time(app_request_success_rate[20s]))"

  # host.lima.internal, not localhost: Alertmanager posts from inside the
  # cluster, where localhost is its own container. Same address the in-cluster
  # agent uses to reach the Server (local.colima_octopus_address in main.tf),
  # and the Server speaks http on 8065, not https.
  webhook_target_url = "http://host.lima.internal:8065/api/test/webhook"
}

resource "kubernetes_namespace_v1" "monitoring" {
  metadata {
    name = "live-status-monitoring-${local.monitoring_suffix}"
  }
}

resource "helm_release" "prometheus" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus"
  version    = "29.17.0"
  namespace  = kubernetes_namespace_v1.monitoring.metadata[0].name
  atomic     = true
  timeout    = 300

  set = [
    # Required for any notification at all; also auto-wires the server's
    # alerting.alertmanagers discovery, so no explicit server.alertmanagers.
    {
      name  = "alertmanager.enabled"
      value = "true"
    },
    # Ephemeral, like the server below: no PVC, so no dependency on a default
    # StorageClass (the chart otherwise provisions a 2Gi RWO volume).
    {
      name  = "alertmanager.persistence.enabled"
      value = "false"
    },
    # Drop the remaining bundled extras for a lean, single-node footprint.
    {
      name  = "prometheus-pushgateway.enabled"
      value = "false"
    },
    {
      name  = "prometheus-node-exporter.enabled"
      value = "false"
    },
    {
      name  = "kube-state-metrics.enabled"
      value = "false"
    },
    # Preserve the old setup's 5s scrape/eval cadence (chart default is 1m) so a
    # deploy-correlated regression still shows up "within a scrape or two".
    {
      name  = "server.global.scrape_interval"
      value = "5s"
    },
    {
      name  = "server.global.evaluation_interval"
      value = "5s"
    },
    # Must be <= scrape_interval or Prometheus refuses to load the config. The
    # chart's default scrape_timeout is 10s, which exceeds our 5s interval, so
    # override it here too. (The old raw-YAML setup left it unset, letting
    # Prometheus auto-clamp it to the interval; the chart writes an explicit 10s.)
    {
      name  = "server.global.scrape_timeout"
      value = "5s"
    },
    # Ephemeral, like the old raw-YAML Deployment: no PVC, so no dependency on a
    # default StorageClass (the chart otherwise provisions an 8Gi RWO volume).
    {
      name  = "server.persistentVolume.enabled"
      value = "false"
    },
    # Keep the Service named `prometheus` on 9090 so existing port-forward
    # commands (svc/prometheus 9090) and docs stay valid. Safe to leave
    # unsuffixed: Services are namespaced, and the namespace now carries the
    # workspace.
    {
      name  = "server.fullnameOverride"
      value = "prometheus"
    },
    # The ClusterRole/ClusterRoleBinding are NOT namespaced, though, and the
    # chart names them after server.fullnameOverride — so without this override
    # a second workspace fails with "clusterroles.rbac.authorization.k8s.io
    # \"prometheus\" already exists" right after the namespace is fixed.
    {
      name  = "server.clusterRoleNameOverride"
      value = "prometheus-${local.monitoring_suffix}"
    },
    {
      name  = "server.service.servicePort"
      value = "9090"
    },
    # Ingress at http://prometheus-<workspace>.localhost via Traefik.
    {
      name  = "server.ingress.enabled"
      value = "true"
    },
    {
      name  = "server.ingress.ingressClassName"
      value = "traefik"
    },
  ]

  set_list = [
    {
      name = "server.ingress.hosts"
      # Ingress objects are namespaced, but the hostname is a cluster-wide
      # routing key: two workspaces both claiming prometheus.localhost would
      # apply cleanly and then route ambiguously.
      value = ["prometheus-${local.monitoring_suffix}.localhost"]
    },
  ]

  # Alerting rules, rendered by the chart to /etc/config/alerting_rules.yml.
  # Passed as a values doc, not `set`, so the expressions aren't split on
  # spaces and operators.
  values = [
    yamlencode({
      # Every alert goes to the Octopus webhook, the only receiver. Helm replaces
      # lists wholesale, so this drops the chart's default-receiver rather than
      # adding alongside it.
      alertmanager = {
        # Ingress at http://alertmanager-<workspace>.localhost via Traefik. Set
        # here rather than in `set_list` alongside the server's: this subchart
        # takes `className` (not `ingressClassName`) and `hosts` as a list of
        # {host, paths} objects rather than plain strings.
        ingress = {
          enabled   = true
          className = "traefik"
          hosts = [
            {
              host = "alertmanager-${local.monitoring_suffix}.localhost"
              paths = [
                {
                  path     = "/"
                  pathType = "Prefix"
                }
              ]
            }
          ]
        }

        config = {
          route = {
            # Grouping on the PET labels does real work here: webhook_config
            # renders one payload per *group*, and the payload below reads
            # .GroupLabels. Grouping this way therefore yields one call per
            # application instance carrying that instance's PET, rather than
            # collapsing every instance's alert of the same name into one call
            # with no usable identity.
            group_by        = ["alertname", "project", "environment", "tenant"]
            group_wait      = "10s"
            group_interval  = "1m"
            repeat_interval = "1h"
            receiver        = "octopus-test-webhook"
          }
          receivers = [
            {
              name = "octopus-test-webhook"
              webhook_configs = [
                {
                  url           = local.webhook_target_url
                  send_resolved = true

                  # Alertmanager's own envelope nests the labels; `payload`
                  # (Alertmanager >= v0.31, chart appVersion here is v0.33.0)
                  # replaces it with this flat body instead. Alertmanager does
                  # no validation on the result, so the shape is ours to keep
                  # right.
                  #
                  # Straight pass-through now that the app emits PET label
                  # names directly — no renaming step to get wrong. Templating
                  # runs with missingkey=zero over a map[string]string, so an
                  # untenanted instance renders tenant as "" rather than
                  # "<no value>".
                  payload = {
                    project     = "{{ .GroupLabels.project }}"
                    environment = "{{ .GroupLabels.environment }}"
                    tenant      = "{{ .GroupLabels.tenant }}"
                    status      = "{{ .Status }}"
                    alertname   = "{{ .GroupLabels.alertname }}"
                  }
                }
              ]
            }
          ]
        }
      }

      serverFiles = {
        "alerting_rules.yml" = {
          groups = [
            {
              name = "live-status"
              rules = [
                # app_up is only ever 1, so this trips only on partial scrape gaps.
                {
                  alert = "AppUpDegraded"
                  expr  = "avg by (project, environment, tenant) (avg_over_time(app_up[20s])) < 1"
                  "for" = "1m"
                  labels = {
                    severity = "warning"
                  }
                  annotations = {
                    summary     = "app_up degraded for {{ $labels.project }}/{{ $labels.environment }}{{ if $labels.tenant }} (tenant {{ $labels.tenant }}){{ end }}"
                    description = "20s-averaged app_up is {{ $value }} (< 1) for project={{ $labels.project }} environment={{ $labels.environment }} tenant={{ $labels.tenant }}."
                  }
                },
                # Warning band [0.8, 0.95); the >= 0.8 bound keeps it exclusive
                # from the critical tier.
                {
                  alert = "AppSuccessRateLow"
                  expr  = "${local.success_rate_20s} < 0.95 >= 0.8"
                  "for" = "1m"
                  labels = {
                    severity = "warning"
                  }
                  annotations = {
                    summary     = "Success rate low for {{ $labels.project }}/{{ $labels.environment }}{{ if $labels.tenant }} (tenant {{ $labels.tenant }}){{ end }}"
                    description = "20s-averaged app_request_success_rate is {{ $value }} (in [0.8, 0.95)) for project={{ $labels.project }} environment={{ $labels.environment }} tenant={{ $labels.tenant }}."
                  }
                },
                {
                  alert = "AppSuccessRateCritical"
                  expr  = "${local.success_rate_20s} < 0.8"
                  "for" = "1m"
                  labels = {
                    severity = "critical"
                  }
                  annotations = {
                    summary     = "Success rate critical for {{ $labels.project }}/{{ $labels.environment }}{{ if $labels.tenant }} (tenant {{ $labels.tenant }}){{ end }}"
                    description = "20s-averaged app_request_success_rate is {{ $value }} (< 0.8) for project={{ $labels.project }} environment={{ $labels.environment }} tenant={{ $labels.tenant }}."
                  }
                },
                # A hard-down pod stops emitting app_up, so catch a full outage
                # via the scrape-level `up`.
                {
                  alert = "AppTargetDown"
                  expr  = "up{job=\"kubernetes-pods\"} == 0"
                  "for" = "1m"
                  labels = {
                    severity = "critical"
                  }
                  annotations = {
                    summary     = "Scrape target down: {{ $labels.namespace }}/{{ $labels.pod }}"
                    description = "Prometheus target {{ $labels.instance }} (pod {{ $labels.pod }}) has up == 0 for over 1m; app_up is absent while it is down."
                  }
                }
              ]
            }
          ]
        }
      }
    })
  ]
}
