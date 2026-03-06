resource "octopusdeploy_project" "update_image_tags_helm" {
  space_id = octopusdeploy_space.main.id

  default_guided_failure_mode          = "EnvironmentDefault"
  default_to_skip_if_already_installed = false
  is_disabled                          = false
  is_discrete_channel_release          = false
  lifecycle_id                         = octopusdeploy_lifecycle.main.id
  name                                 = "Update Image Tags Helm"
  tenanted_deployment_participation    = "Untenanted"
  included_library_variable_sets       = []
  project_group_id                     = octopusdeploy_project_group.argo_cd_samples.id
}

resource "octopusdeploy_process" "update_image_tags_helm" {
  project_id = octopusdeploy_project.update_image_tags_helm.id
  space_id   = octopusdeploy_space.main.id
}

resource "octopusdeploy_process_step" "update_image_tags_helm" {
  process_id = octopusdeploy_process.update_image_tags_helm.id
  space_id   = octopusdeploy_space.main.id
  name       = "Update Image Tags"
  type       = "Octopus.ArgoCDUpdateImageTags"
  execution_properties = {
    "Octopus.Action.ArgoCD.CommitMessageSummary" : "Octopus Deploy updated image versions",
    "Octopus.Action.ArgoCD.CommitMethod" : "DirectCommit"
  }
  packages = {
    "nginx" : {
      feed_id              = octopusdeploy_docker_container_registry.docker.id
      package_id           = "nginx"
      acquisition_location = "NotAcquired"
      properties = {
        "SelectionMode" = "immediate"
        "Extract"       = "False"
        "Purpose"       = "DockerImageReference"
      }
    },
    "redis" : {
      feed_id              = octopusdeploy_docker_container_registry.docker.id
      package_id           = "redis"
      acquisition_location = "NotAcquired"
      properties = {
        "SelectionMode" = "immediate"
        "Extract"       = "False"
        "Purpose"       = "DockerImageReference"
      }
    }
  }
}
