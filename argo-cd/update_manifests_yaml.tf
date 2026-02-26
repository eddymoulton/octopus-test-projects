resource "octopusdeploy_project" "update_manifests_yaml" {
  space_id = octopusdeploy_space.main.id

  default_guided_failure_mode          = "EnvironmentDefault"
  default_to_skip_if_already_installed = false
  is_disabled                          = false
  is_discrete_channel_release          = false
  lifecycle_id                         = octopusdeploy_lifecycle.main.id
  name                                 = "Update Manifests Yaml"
  tenanted_deployment_participation    = "Untenanted"
  included_library_variable_sets       = []
  project_group_id                     = octopusdeploy_project_group.argo_cd_samples.id
}

resource "octopusdeploy_process" "update_manifests_yaml" {
  project_id = octopusdeploy_project.update_manifests_yaml.id
  space_id   = octopusdeploy_space.main.id
}

resource "octopusdeploy_process_step" "update_manifests_yaml" {
  process_id = octopusdeploy_process.update_manifests_yaml.id
  space_id   = octopusdeploy_space.main.id
  name       = "Update Image Tags"
  type       = "Octopus.ArgoCDUpdateManifests"
  execution_properties = {
    "Octopus.Action.ArgoCD.CommitMessageSummary" : "Octopus Deploy updated image versions",
    "Octopus.Action.ArgoCD.CommitMethod" : "DirectCommit"
  }
  packages = {
    "octopub-products-microservice" : {
      feed_id              = octopusdeploy_docker_container_registry.docker.id
      package_id           = "octopussamples/octopub-products-microservice"
      acquisition_location = "NotAcquired"
      properties = {
        "SelectionMode" = "immediate"
        "Extract"       = "False"
        "Purpose"       = "DockerImageReference"

      }
    },
    "octopub-frontend" : {
      feed_id              = octopusdeploy_docker_container_registry.docker.id
      package_id           = "octopussamples/octopub-frontend"
      acquisition_location = "NotAcquired"
      properties = {
        "SelectionMode" = "immediate"
        "Extract"       = "False"
        "Purpose"       = "DockerImageReference"
      }
    },
    "octopub-audit-microservice" : {
      feed_id              = octopusdeploy_docker_container_registry.docker.id
      package_id           = "octopussamples/octopub-audit-microservice"
      acquisition_location = "NotAcquired"
      properties = {
        "SelectionMode" = "immediate"
        "Extract"       = "False"
        "Purpose"       = "DockerImageReference"
      }
    }
  }
}
