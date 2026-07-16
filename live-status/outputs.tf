output "space_id" {
  value = octopusdeploy_space.main.id
}

output "space_name" {
  value = octopusdeploy_space.main.name
}

output "prometheus_ui_hint" {
  description = "Once the Infrastructure project has been deployed, port-forward the Prometheus UI."
  value       = "kubectl -n live-status-monitoring port-forward svc/prometheus 9090:9090   # then open http://localhost:9090"
}
