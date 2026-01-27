locals {
  octopus_address                = "http://localhost:8065/"
  colima_octopus_address         = "http://host.lima.internal:8065/"
  colima_octopus_grpc_address    = "grpc://host.lima.internal:8443"
  colima_octopus_polling_address = "http://host.lima.internal:10943/"
}

data "octopusdeploy_teams" "everyone" {
  partial_name = "Everyone"
  skip         = 0
  take         = 1
}

resource "octopusdeploy_space" "main" {
  name                 = "Argo Examples"
  description          = "Terraform created Argo examples"
  space_managers_teams = [data.octopusdeploy_teams.everyone.teams[0].id]
}

resource "octopusdeploy_environment" "test" {
  name     = "Test"
  space_id = octopusdeploy_space.main.id
}

resource "octopusdeploy_environment" "prod" {
  name     = "Production"
  space_id = octopusdeploy_space.main.id
}

resource "octopusdeploy_lifecycle" "main" {
  description = "Testing lifecycle"
  name        = "terraform-created"
  space_id    = octopusdeploy_space.main.id

  release_retention_policy {
    quantity_to_keep    = 1
    should_keep_forever = false
    unit                = "Days"
  }

  tentacle_retention_policy {
    quantity_to_keep    = 30
    should_keep_forever = false
    unit                = "Items"
  }

  phase {
    automatic_deployment_targets = [octopusdeploy_environment.test.id]
    name                         = "Test"
  }

  phase {
    automatic_deployment_targets = [octopusdeploy_environment.prod.id]
    name                         = "Production"
  }
}

resource "octopusdeploy_docker_container_registry" "docker" {
  api_version = "v2"
  name        = "docker.io"
  feed_uri    = "https://index.docker.io"
  space_id    = octopusdeploy_space.main.id

  username = var.docker_username
  password = var.docker_password
}

resource "octopusdeploy_git_credential" "github" {
  name     = "GitHub"
  space_id = octopusdeploy_space.main.id
  username = var.github_username
  password = var.github_password

  repository_restrictions = {
    allowed_repositories = [
      "https://github.com/eddymoulton/octopus-argo-cd-samples"
    ],
    enabled = true
  }
}

resource "octopusdeploy_project_group" "argo_cd_samples" {
  description = "Argo CD Sample Projects"
  name        = "Argo CD Samples"
  space_id    = octopusdeploy_space.main.id
}

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
    "Octopus.Action.ArgoCD.CommitMethod" : "PullRequest"
  }
  packages = {
    "octopub-products-microservice" : {
      feed_id              = octopusdeploy_docker_container_registry.docker.id
      package_id           = "octopussamples/octopub-products-microservice"
      acquisition_location = "NotAcquired"
      properties = {
        "SelectionMode" = "immediate"
      }
    },
    "octopub-frontend" : {
      feed_id              = octopusdeploy_docker_container_registry.docker.id
      package_id           = "octopussamples/octopub-frontend"
      acquisition_location = "NotAcquired"
      properties = {
        "SelectionMode" = "immediate"
      }
    },
    "octopub-audit-microservice" : {
      feed_id              = octopusdeploy_docker_container_registry.docker.id
      package_id           = "octopussamples/octopub-audit-microservice"
      acquisition_location = "NotAcquired"
      properties = {
        "SelectionMode" = "immediate"
      }
    }
  }
}

# resource "octopusdeploy_project" "update_image_tags_kustomize" {
#   space_id = octopusdeploy_space.main.id

#   default_guided_failure_mode          = "EnvironmentDefault"
#   default_to_skip_if_already_installed = false
#   is_disabled                          = false
#   is_discrete_channel_release          = false
#   lifecycle_id                         = octopusdeploy_lifecycle.main.id
#   name                                 = "Update Image Tags Kustomize"
#   tenanted_deployment_participation    = "Untenanted"
#   included_library_variable_sets       = []
#   project_group_id                     = octopusdeploy_project_group.argo_cd_samples.id
# }

# resource "octopusdeploy_project" "update_image_tags_helm" {
#   space_id = octopusdeploy_space.main.id

#   default_guided_failure_mode          = "EnvironmentDefault"
#   default_to_skip_if_already_installed = false
#   is_disabled                          = false
#   is_discrete_channel_release          = false
#   lifecycle_id                         = octopusdeploy_lifecycle.main.id
#   name                                 = "Update Image Tags Helm"
#   tenanted_deployment_participation    = "Untenanted"
#   included_library_variable_sets       = []
#   project_group_id                     = octopusdeploy_project_group.argo_cd_samples.id
# }

# resource "octopusdeploy_project" "update_manifests_helm_playhq" {
#   space_id = octopusdeploy_space.main.id

#   default_guided_failure_mode          = "EnvironmentDefault"
#   default_to_skip_if_already_installed = false
#   is_disabled                          = false
#   is_discrete_channel_release          = false
#   lifecycle_id                         = octopusdeploy_lifecycle.main.id
#   name                                 = "Update Manifests Helm Playhq"
#   tenanted_deployment_participation    = "Untenanted"
#   included_library_variable_sets       = []
#   project_group_id                     = octopusdeploy_project_group.argo_cd_samples.id
# }

# resource "octopusdeploy_project" "update_manifests_kustomize" {
#   space_id = octopusdeploy_space.main.id

#   default_guided_failure_mode          = "EnvironmentDefault"
#   default_to_skip_if_already_installed = false
#   is_disabled                          = false
#   is_discrete_channel_release          = false
#   lifecycle_id                         = octopusdeploy_lifecycle.main.id
#   name                                 = "Update Manifests Kustomize"
#   tenanted_deployment_participation    = "Untenanted"
#   included_library_variable_sets       = []
#   project_group_id                     = octopusdeploy_project_group.argo_cd_samples.id
# }

# resource "octopusdeploy_project" "update_manifests_yaml" {
#   space_id = octopusdeploy_space.main.id

#   default_guided_failure_mode          = "EnvironmentDefault"
#   default_to_skip_if_already_installed = false
#   is_disabled                          = false
#   is_discrete_channel_release          = false
#   lifecycle_id                         = octopusdeploy_lifecycle.main.id
#   name                                 = "Update Manifests Yaml"
#   tenanted_deployment_participation    = "Untenanted"
#   included_library_variable_sets       = []
#   project_group_id                     = octopusdeploy_project_group.argo_cd_samples.id
# }

# resource "octopusdeploy_project" "update_manifests_yaml_multisource" {
#   space_id = octopusdeploy_space.main.id

#   default_guided_failure_mode          = "EnvironmentDefault"
#   default_to_skip_if_already_installed = false
#   is_disabled                          = false
#   is_discrete_channel_release          = false
#   lifecycle_id                         = octopusdeploy_lifecycle.main.id
#   name                                 = "Update Manifests Yaml Multisource"
#   tenanted_deployment_participation    = "Untenanted"
#   included_library_variable_sets       = []
#   project_group_id                     = octopusdeploy_project_group.argo_cd_samples.id
# }