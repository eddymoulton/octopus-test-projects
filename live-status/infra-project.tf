# Infrastructure project: deploys shared cluster infra (Prometheus).
resource "octopusdeploy_project" "infra" {
  space_id = octopusdeploy_space.main.id

  name                                 = "Infrastructure"
  description                          = "Deploys shared infrastructure (Prometheus) into the cluster"
  lifecycle_id                         = octopusdeploy_lifecycle.main.id
  project_group_id                     = octopusdeploy_project_group.main.id
  tenanted_deployment_participation    = "Untenanted"
  default_guided_failure_mode          = "EnvironmentDefault"
  default_to_skip_if_already_installed = false
  is_disabled                          = false
  is_discrete_channel_release          = false
  included_library_variable_sets       = []
}

module "infra_process" {
  source = "../deployment_processes/prometheus_process"

  space_id             = octopusdeploy_space.main.id
  project_id           = octopusdeploy_project.infra.id
  target_role          = "live-status"
  monitoring_namespace = "live-status-monitoring"
}
