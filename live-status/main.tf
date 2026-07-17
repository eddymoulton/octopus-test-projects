locals {
  # Local Octopus Server address (Terraform provider talks to this).
  octopus_address = "http://localhost:8065/"

  # Addresses the in-cluster agent uses to reach the Server (Colima).
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
  name                 = "Live Application Status ${terraform.workspace}"
  description          = "Terraform-created Live Application Status test space"
  space_managers_teams = [data.octopusdeploy_teams.everyone.teams[0].id]
}

resource "octopusdeploy_environment" "staging" {
  name     = "Staging"
  space_id = octopusdeploy_space.main.id
}

resource "octopusdeploy_environment" "production" {
  name     = "Production"
  space_id = octopusdeploy_space.main.id
}

resource "octopusdeploy_lifecycle" "main" {
  name        = "live-status-lifecycle"
  description = "Staging then Production (manual deployments)"
  space_id    = octopusdeploy_space.main.id

  release_retention_with_strategy {
    strategy         = "Count"
    quantity_to_keep = 1
    unit             = "Days"
  }

  tentacle_retention_with_strategy {
    strategy         = "Count"
    quantity_to_keep = 30
    unit             = "Items"
  }

  # optional_deployment_targets => the environment is available in the phase
  # but deployments are triggered manually (so we can pick Good/Bad per deploy).
  phase {
    name                        = "Staging"
    optional_deployment_targets = [octopusdeploy_environment.staging.id]
  }

  phase {
    name                        = "Production"
    optional_deployment_targets = [octopusdeploy_environment.production.id]
  }
}

resource "octopusdeploy_project_group" "main" {
  name        = "Live Application Status"
  description = "Synthetic-service projects"
  space_id    = octopusdeploy_space.main.id
}

# Docker feed the app image is pulled from (GHCR).
resource "octopusdeploy_docker_container_registry" "app" {
  name        = "synthetic-service-images"
  api_version = "v2"
  feed_uri    = var.app_feed_uri
  username    = var.app_feed_username
  password    = var.app_feed_password
  space_id    = octopusdeploy_space.main.id
}
