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

resource "octopusdeploy_process_step" "prometheus" {
  process_id = octopusdeploy_process.main.id
  space_id   = var.space_id
  name       = "deploy-prometheus"
  type       = "Octopus.KubernetesDeployRawYaml"

  properties = {
    "Octopus.Action.TargetRoles" = var.target_role
  }

  execution_properties = {
    "Octopus.Action.Kubernetes.DeploymentTimeout"              = "180"
    "Octopus.Action.Kubernetes.ResourceStatusCheck"            = "True"
    "Octopus.Action.Kubernetes.ServerSideApply.Enabled"        = "True"
    "Octopus.Action.Kubernetes.ServerSideApply.ForceConflicts" = "True"
    "Octopus.Action.KubernetesContainers.CustomResourceYaml"   = local.prometheus_yaml
    "Octopus.Action.Script.ScriptSource"                       = "Inline"
  }
}

# Prints how to reach the Prometheus UI (runs on the Octopus Server).
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
    octopusdeploy_process_step.prometheus.id,
    octopusdeploy_process_step.access_info.id,
  ]
}
