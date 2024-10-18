terraform {
  required_providers {
    octopusdeploy = {
      source  = "OctopusDeployLabs/octopusdeploy"
      version = "0.32.0"
    }
  }

  backend "local" {
  }
}

provider "octopusdeploy" {
  address = var.server_address
  api_key = var.access_token
}

resource "random_pet" "main" {
}

locals {
  unique_name = "${terraform.workspace == "default" ? random_pet.main.id : terraform.workspace}"
}

resource "octopusdeploy_docker_container_registry" "docker" {
  api_version = "v2"
  name        = "container_docker-${local.unique_name}"
  feed_uri    = "https://index.docker.io"
  space_id    = var.space_id

  username = var.docker_username
  password = var.docker_password
}

resource "octopusdeploy_helm_feed" "helm_examples" {
  name     = "helm_examples-${local.unique_name}"
  feed_uri = "https://helm.github.io/examples"
  space_id = var.space_id
}

resource "octopusdeploy_lifecycle" "main" {
  description = "Testing lifecycle"
  name        = "terraform-${local.unique_name}"
  space_id    = var.space_id

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
    automatic_deployment_targets = [var.environment_id]
    name                         = "terraform"
  }
}

resource "octopusdeploy_project_group" "main" {
  description = "Terraform projects"
  name        = "terraform-projects-${local.unique_name}"
  space_id    = var.space_id
}

module "project" {
  for_each = { for x in range(0, var.number_of_projects) : x => x }
  source   = "./project"

  space_id         = var.space_id
  environment_id   = var.environment_id
  project_name     = "${local.unique_name}-${each.value}"
  project_group_id = octopusdeploy_project_group.main.id
  lifecycle_id     = octopusdeploy_lifecycle.main.id

  target_role                     = var.target_role
  auto_create_release                 = var.auto_create_release
  auto_create_release_minute_interval = var.auto_create_release_minute_interval

  docker_feed_id = octopusdeploy_docker_container_registry.docker.id
  helm_feed_id   = octopusdeploy_helm_feed.helm_examples.id

  process = var.process_type
}