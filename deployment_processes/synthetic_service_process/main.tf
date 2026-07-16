terraform {
  required_providers {
    octopusdeploy = {
      source  = "OctopusDeploy/octopusdeploy"
      version = "1.18.1"
    }
  }
}

resource "octopusdeploy_process" "main" {
  project_id = var.project_id
  space_id   = var.space_id
}

resource "octopusdeploy_process_step" "app" {
  process_id = octopusdeploy_process.main.id
  space_id   = var.space_id
  name       = "deploy-synthetic-service"
  type       = "Octopus.KubernetesDeployRawYaml"

  properties = {
    "Octopus.Action.TargetRoles" = var.target_role
  }

  # Container-image package reference. The image tag is chosen at release
  # creation from the Docker feed; referenced in the YAML as
  # #{Octopus.Action.Package[app].PackageId}:#{...PackageVersion}.
  packages = {
    "app" = {
      acquisition_location = "NotAcquired"
      feed_id              = var.docker_feed_id
      package_id           = var.image_package_id
      properties = {
        Extract              = "False"
        SelectionMode        = "immediate"
        PackageParameterName = ""
      }
    }
  }

  execution_properties = {
    "Octopus.Action.Kubernetes.DeploymentTimeout"              = "180"
    "Octopus.Action.Kubernetes.ResourceStatusCheck"            = "True"
    "Octopus.Action.Kubernetes.ServerSideApply.Enabled"        = "True"
    "Octopus.Action.Kubernetes.ServerSideApply.ForceConflicts" = "True"
    "Octopus.Action.KubernetesContainers.CustomResourceYaml"   = local.app_yaml
    "Octopus.Action.Script.ScriptSource"                       = "Inline"
  }
}

# Prints how to reach the app UI (runs on the Octopus Server).
resource "octopusdeploy_process_step" "access_info" {
  process_id = octopusdeploy_process.main.id
  space_id   = var.space_id
  name       = "show-access-info"
  type       = "Octopus.Script"

  execution_properties = {
    "Octopus.Action.RunOnServer"         = "True"
    "Octopus.Action.Script.ScriptSource" = "Inline"
    "Octopus.Action.Script.Syntax"       = "Bash"
    "Octopus.Action.Script.ScriptBody"   = local.access_info_script
  }
}

resource "octopusdeploy_process_steps_order" "main" {
  process_id = octopusdeploy_process.main.id
  space_id   = var.space_id

  steps = [
    octopusdeploy_process_step.app.id,
    octopusdeploy_process_step.access_info.id,
  ]
}

# Prompted at deploy time: Good (healthy) vs Bad (raises error rate -> Unhealthy).
resource "octopusdeploy_variable" "variant" {
  project_id = var.project_id
  space_id   = var.space_id
  name       = "Variant"
  type       = "String"
  value      = "Good"

  prompt {
    label       = "Release variant"
    description = "Good = healthy (low error rate); Bad = raises the error rate so the app goes Unhealthy."
    is_required = true

    display_settings {
      control_type = "Select"

      select_option {
        value        = "Good"
        display_name = "Good (healthy)"
      }

      select_option {
        value        = "Bad"
        display_name = "Bad (unhealthy)"
      }
    }
  }
}

# Derived from Variant; consumed by the manifest as #{App.ErrorRate}.
# (Computed in a variable rather than inline in YAML: a YAML scalar can't both
# start with #{ and contain the inner "Bad" quotes.)
resource "octopusdeploy_variable" "error_rate" {
  project_id = var.project_id
  space_id   = var.space_id
  name       = "App.ErrorRate"
  type       = "String"
  value      = "#{if Variant == \"Bad\"}0.10#{else}0.002#{/if}"
}
