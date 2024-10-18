terraform {
  required_providers {
    octopusdeploy = {
      source  = "OctopusDeployLabs/octopusdeploy"
      version = "0.32.0"
    }
  }
}

resource "octopusdeploy_project" "main" {
  space_id = var.space_id

  auto_create_release                  = false
  default_guided_failure_mode          = "EnvironmentDefault"
  default_to_skip_if_already_installed = false
  description                          = "Terraform cretaed"
  discrete_channel_release             = false
  is_disabled                          = false
  is_discrete_channel_release          = false
  lifecycle_id                         = var.lifecycle_id
  name                                 = var.project_name
  tenanted_deployment_participation    = "Untenanted"
  included_library_variable_sets       = []
  project_group_id                     = var.project_group_id
}

resource "octopusdeploy_channel" "main" {
  name       = "TF channel"
  project_id = octopusdeploy_project.main.id
  space_id   = var.space_id
}

resource "octopusdeploy_project_scheduled_trigger" "main" {
  for_each = var.auto_create_release == true ? toset([1]) : toset([])

  name       = octopusdeploy_project.main.id
  space_id   = var.space_id
  project_id = octopusdeploy_project.main.id

  channel_id = octopusdeploy_channel.main.id

  deploy_new_release_action {
    destination_environment_id = var.environment_id
  }

  continuous_daily_schedule {
    interval        = "OnceEveryMinute"
    minute_interval = var.auto_create_release_minute_interval
    run_after       = "2000-01-01T01:00:00"
    run_until       = "2000-01-01T23:00:00"
    days_of_week    = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
  }
}

module "everything_process" {
  for_each = var.process == "everything" ? toset(["process"]) : toset([])
  source   = "../deployment_processes/everything_process"

  space_id        = var.space_id
  project_id      = octopusdeploy_project.main.id
  k8s_namespace   = var.project_name
  target_role = var.target_role
  docker_feed_id  = var.docker_feed_id
  helm_feed_id    = var.helm_feed_id
}

module "argo_process" {
  for_each = var.process == "argo" ? toset(["process"]) : toset([])
  source   = "../deployment_processes//argo_install_process"

  space_id        = var.space_id
  project_id      = octopusdeploy_project.main.id
  k8s_namespace   = var.project_name
  target_role = var.target_role
}