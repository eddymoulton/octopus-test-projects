resource "octopusdeploy_project" "argo_root_app" {
  space_id = octopusdeploy_space.main.id

  default_guided_failure_mode          = "EnvironmentDefault"
  default_to_skip_if_already_installed = false
  is_disabled                          = false
  is_discrete_channel_release          = false
  lifecycle_id                         = octopusdeploy_lifecycle.main.id
  name                                 = "Argo Root App"
  tenanted_deployment_participation    = "Untenanted"
  included_library_variable_sets       = []
  project_group_id                     = octopusdeploy_project_group.argo_cd_samples.id
}

resource "octopusdeploy_process" "argo_root_app" {
  project_id = octopusdeploy_project.argo_root_app.id
  space_id   = octopusdeploy_space.main.id
}

resource "octopusdeploy_process_step" "argo_root_app" {
  process_id = octopusdeploy_process.argo_root_app.id
  space_id   = octopusdeploy_space.main.id
  name       = "Deploy Argo Root App"
  type       = "Octopus.KubernetesDeployRawYaml"
  properties = {
    "Octopus.Action.TargetRoles" = "argo-k8s-agent"
  }
  execution_properties = {
    "Octopus.Action.Kubernetes.DeploymentTimeout"                    = "180"
    "Octopus.Action.Kubernetes.ResourceStatusCheck"                  = "True"
    "Octopus.Action.Kubernetes.ServerSideApply.Enabled"              = "True"
    "Octopus.Action.Kubernetes.ServerSideApply.ForceConflicts"       = "True"
    "Octopus.Action.Script.ScriptSource"                             = "GitRepository"
    "Octopus.Action.KubernetesContainers.CustomResourceYamlFileName" = "argo-root-app/argo-root-app.yaml"
  }

  git_dependencies = {
    "" = {
      repository_uri      = "https://github.com/eddymoulton/octopus-argo-cd-samples.git"
      default_branch      = "main"
      git_credential_type = "Library"
      git_credential_id   = octopusdeploy_git_credential.github.id
      file_path_filters   = ["argo-root-app/argo-root-app.yaml"]
    }
  }
}
