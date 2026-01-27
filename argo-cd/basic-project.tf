resource "octopusdeploy_project_group" "main" {
  description = "Terraform projects"
  name        = "terraform-created"
  space_id    = octopusdeploy_space.main.id
}

resource "octopusdeploy_project" "main" {
  space_id = octopusdeploy_space.main.id

  default_guided_failure_mode          = "EnvironmentDefault"
  default_to_skip_if_already_installed = false
  description                          = "Terraform created"
  is_disabled                          = false
  is_discrete_channel_release          = false
  lifecycle_id                         = octopusdeploy_lifecycle.main.id
  name                                 = "Terraform created"
  tenanted_deployment_participation    = "Untenanted"
  included_library_variable_sets       = []
  project_group_id                     = octopusdeploy_project_group.main.id
}