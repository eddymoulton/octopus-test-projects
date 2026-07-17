# Prometheus, deployed by Terraform via the prometheus-community Helm chart.
# Previously stood up by an Octopus "Infrastructure" deployment process
# (../deployment_processes/prometheus_process); now it mirrors the agent.tf /
# datadog.tf pattern — a namespace + a helm_release into the Colima cluster, up
# at `terraform apply`.
#
# Trimmed to the server only (no alertmanager / pushgateway / node-exporter /
# kube-state-metrics). The chart's default `kubernetes-pods` scrape job keeps
# pods annotated prometheus.io/scrape: "true" — the same annotations the
# synthetic-service pods carry — so Prometheus scrapes them with no app changes.
# server.fullnameOverride + servicePort keep the Service named `prometheus` on
# 9090, so existing `svc/prometheus 9090` port-forwards and the
# http://prometheus.localhost Ingress keep working.

resource "kubernetes_namespace_v1" "monitoring" {
  metadata {
    name = "live-status-monitoring"
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
    # Server only — drop the bundled extras for a lean, single-node footprint.
    {
      name  = "alertmanager.enabled"
      value = "false"
    },
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
    # commands (svc/prometheus 9090) and docs stay valid.
    {
      name  = "server.fullnameOverride"
      value = "prometheus"
    },
    {
      name  = "server.service.servicePort"
      value = "9090"
    },
    # Ingress at http://prometheus.localhost via Traefik (as before).
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
      name  = "server.ingress.hosts"
      value = ["prometheus.localhost"]
    },
  ]
}
