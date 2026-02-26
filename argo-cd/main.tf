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

resource "octopusdeploy_library_variable_set" "calamari_local" {
  name     = "Calamari Local"
  space_id = octopusdeploy_space.main.id
}

resource "octopusdeploy_variable" "calamari_executable" {
  name     = "Octopus.Calamari.Executable"
  type     = "String"
  value    = "/Users/eddy/octo/Calamari/source/Calamari/bin/Debug/net8.0/Calamari"
  owner_id = octopusdeploy_library_variable_set.calamari_local.id
  space_id = octopusdeploy_space.main.id
}

resource "octopusdeploy_library_variable_set" "calamari_debugging" {
  name     = "Calamari Debugging"
  space_id = octopusdeploy_space.main.id
}

resource "octopusdeploy_variable" "calamari_wait_for_debugger" {
  name     = "Octopus.Calamari.WaitForDebugger"
  type     = "String"
  value    = "True"
  owner_id = octopusdeploy_library_variable_set.calamari_debugging.id
  space_id = octopusdeploy_space.main.id
}