resource "octopusdeploy_project" "guestbook" {
  space_id = octopusdeploy_space.main.id

  default_guided_failure_mode          = "EnvironmentDefault"
  default_to_skip_if_already_installed = false
  is_disabled                          = false
  is_discrete_channel_release          = false
  lifecycle_id                         = octopusdeploy_lifecycle.main.id
  name                                 = "Deploy Guestbook YAML"
  tenanted_deployment_participation    = "Untenanted"
  included_library_variable_sets       = []
  project_group_id                     = octopusdeploy_project_group.main.id
}

module "guestbook_process" {
  source = "../deployment_processes/guestbook_process"

  space_id      = octopusdeploy_space.main.id
  project_id    = octopusdeploy_project.guestbook.id
  k8s_namespace = octopusdeploy_project.guestbook.slug
  target_role   = "k8s-agent"
}
