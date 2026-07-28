output "space_id" {
  value = octopusdeploy_space.main.id
}

output "space_name" {
  value = octopusdeploy_space.main.name
}

output "prometheus_ui_hint" {
  description = "Prometheus is deployed by Terraform (prometheus.tf) and comes up at apply. Reach the UI via the Ingress or a port-forward."
  value       = "http://prometheus-${local.monitoring_suffix}.localhost   (or: kubectl -n ${kubernetes_namespace_v1.monitoring.metadata[0].name} port-forward svc/prometheus 9090:9090 then http://localhost:9090)"
}

output "alertmanager_ui_hint" {
  description = "Alertmanager UI, for inspecting firing alerts and webhook delivery."
  value       = "http://alertmanager-${local.monitoring_suffix}.localhost   (or: kubectl -n ${kubernetes_namespace_v1.monitoring.metadata[0].name} port-forward svc/prometheus-alertmanager 9093:9093 then http://localhost:9093)"
}
