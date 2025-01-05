terraform {
  required_providers {
    octopusdeploy = {
      source  = "OctopusDeployLabs/octopusdeploy"
      version = "0.38.0"
    }
  }
}

resource "octopusdeploy_deployment_process" "main" {
  project_id = var.project_id
  space_id   = var.space_id

  step {
    condition    = "Always"
    name         = "yaml-guestbook-manifest-ns"
    target_roles = [var.target_role]

    action {
      name          = "yaml-guestbook-manifest-ns"
      action_type   = "Octopus.KubernetesDeployRawYaml"
      run_on_server = false
      properties = {
        "Octopus.Action.Kubernetes.DeploymentTimeout"              = "180"
        "Octopus.Action.Kubernetes.ResourceStatusCheck"            = "True"
        "Octopus.Action.Kubernetes.ServerSideApply.Enabled"        = "True"
        "Octopus.Action.Kubernetes.ServerSideApply.ForceConflicts" = "True"
        "Octopus.Action.KubernetesContainers.CustomResourceYaml"   = local.guestbook_with_ns_yaml
        "Octopus.Action.KubernetesContainers.Namespace"            = "terraform-yaml-guestbook-${var.k8s_namespace}-manifest-ns"
        "Octopus.Action.Script.ScriptSource"                       = "Inline"
      }
    }
  }

  step {
    condition    = "Always"
    name         = "yaml-guestbook-step-ns"
    target_roles = [var.target_role]

    action {
      name          = "yaml-guestbook-step-ns"
      action_type   = "Octopus.KubernetesDeployRawYaml"
      run_on_server = false
      properties = {
        "Octopus.Action.Kubernetes.DeploymentTimeout"              = "180"
        "Octopus.Action.Kubernetes.ResourceStatusCheck"            = "True"
        "Octopus.Action.Kubernetes.ServerSideApply.Enabled"        = "True"
        "Octopus.Action.Kubernetes.ServerSideApply.ForceConflicts" = "True"
        "Octopus.Action.KubernetesContainers.CustomResourceYaml"   = local.guestbook_without_ns_yaml
        "Octopus.Action.KubernetesContainers.Namespace"            = "terraform-yaml-guestbook-${var.k8s_namespace}-step-ns"
        "Octopus.Action.Script.ScriptSource"                       = "Inline"
      }
    }
  }

  step {
    condition    = "Always"
    name         = "yaml-guestbook-target-ns"
    target_roles = [var.target_role]

    action {
      name          = "yaml-guestbook-target-ns"
      action_type   = "Octopus.KubernetesDeployRawYaml"
      run_on_server = false
      properties = {
        "Octopus.Action.Kubernetes.DeploymentTimeout"              = "180"
        "Octopus.Action.Kubernetes.ResourceStatusCheck"            = "True"
        "Octopus.Action.Kubernetes.ServerSideApply.Enabled"        = "True"
        "Octopus.Action.Kubernetes.ServerSideApply.ForceConflicts" = "True"
        "Octopus.Action.KubernetesContainers.CustomResourceYaml"   = local.guestbook_without_ns_yaml
        "Octopus.Action.KubernetesContainers.Namespace"            = "terraform-yaml-guestbook-${var.k8s_namespace}-target-ns"
        "Octopus.Action.Script.ScriptSource"                       = "Inline"
      }
    }
  }

  step {
    condition    = "Always"
    name         = "yaml-guestbook-invalid-version"
    target_roles = [var.target_role]

    action {
      name          = "yaml-guestbook-invalid-version"
      action_type   = "Octopus.KubernetesDeployRawYaml"
      run_on_server = false
      properties = {
        "Octopus.Action.Kubernetes.DeploymentTimeout"              = "180"
        "Octopus.Action.Kubernetes.ResourceStatusCheck"            = "True"
        "Octopus.Action.Kubernetes.ServerSideApply.Enabled"        = "True"
        "Octopus.Action.Kubernetes.ServerSideApply.ForceConflicts" = "True"
        "Octopus.Action.KubernetesContainers.CustomResourceYaml"   = local.guestbook_without_ns_yaml
        "Octopus.Action.KubernetesContainers.Namespace"            = "terraform-yaml-guestbook-${var.k8s_namespace}-invalid-kind"
        "Octopus.Action.Script.ScriptSource"                       = "Inline"
        "Octopus.Action.Kubernetes.ResourceStatusCheck"            = "False"
      }
    }
  }
}