output "space_id" {
  value = octopusdeploy_space.main.id
}

output "space_name" {
  value = octopusdeploy_space.main.name
}

output "prometheus_ui_hint" {
  description = "Prometheus is deployed by Terraform (prometheus.tf) and comes up at apply. Reach the UI via the Ingress or a port-forward."
  value       = "http://prometheus.localhost   (or: kubectl -n live-status-monitoring port-forward svc/prometheus 9090:9090 then http://localhost:9090)"
}
