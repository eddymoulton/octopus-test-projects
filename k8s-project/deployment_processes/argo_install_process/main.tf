terraform {
  required_providers {
    octopusdeploy = {
      source  = "OctopusDeployLabs/octopusdeploy"
      version = "0.32.0"
    }
  }
}

resource "octopusdeploy_deployment_process" "main" {
  project_id = var.project_id
  space_id   = var.space_id

  step {
    condition    = "Always"
    name         = "yaml-argo"
    target_roles = [var.k8s_target_role]

    action {
      name          = "yaml-argo"
      action_type   = "Octopus.KubernetesDeployRawYaml"
      run_on_server = false
      properties = {
        "Octopus.Action.Kubernetes.DeploymentTimeout"              = "180"
        "Octopus.Action.Kubernetes.ResourceStatusCheck"            = "True"
        "Octopus.Action.Kubernetes.ServerSideApply.Enabled"        = "True"
        "Octopus.Action.Kubernetes.ServerSideApply.ForceConflicts" = "True"
        "Octopus.Action.KubernetesContainers.CustomResourceYaml"   = local.argo_yaml
        "Octopus.Action.KubernetesContainers.Namespace"            = "terraform-yaml-argo-${var.k8s_namespace}"
        "Octopus.Action.Script.ScriptSource"                       = "Inline"
      }
    }
  }
}