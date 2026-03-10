terraform {
  required_providers {
    octopusdeploy = {
      source  = "OctopusDeploy/octopusdeploy"
      version = "1.7.2"
    }
  }
}

resource "octopusdeploy_process" "main" {
  project_id = var.project_id
  space_id   = var.space_id
}

resource "octopusdeploy_process_step" "yaml" {
  process_id = octopusdeploy_process.main.id
  space_id   = var.space_id
  name       = "yaml-guestbook"
  type       = "Octopus.KubernetesDeployRawYaml"
  properties = {
    "Octopus.Action.TargetRoles" = var.target_role
  }
  execution_properties = {
    "Octopus.Action.Kubernetes.DeploymentTimeout"              = "180"
    "Octopus.Action.Kubernetes.ResourceStatusCheck"            = "True"
    "Octopus.Action.Kubernetes.ServerSideApply.Enabled"        = "True"
    "Octopus.Action.Kubernetes.ServerSideApply.ForceConflicts" = "True"
    "Octopus.Action.KubernetesContainers.CustomResourceYaml"   = local.guestbook_yaml
    "Octopus.Action.KubernetesContainers.Namespace"            = "terraform-yaml-guestbook-${var.k8s_namespace}"
    "Octopus.Action.Script.ScriptSource"                       = "Inline"
  }
}