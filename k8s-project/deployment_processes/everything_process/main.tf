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
    name         = "yaml-guestbook"
    target_roles = [var.k8s_target_role]

    action {
      name          = "yaml-guestbook"
      action_type   = "Octopus.KubernetesDeployRawYaml"
      run_on_server = false
      properties = {
        "Octopus.Action.Kubernetes.DeploymentTimeout"              = "180"
        "Octopus.Action.Kubernetes.ResourceStatusCheck"            = "True"
        "Octopus.Action.Kubernetes.ServerSideApply.Enabled"        = "True"
        "Octopus.Action.Kubernetes.ServerSideApply.ForceConflicts" = "True"
        "Octopus.Action.KubernetesContainers.CustomResourceYaml"   = local.guestbook_yaml
        "Octopus.Action.KubernetesContainers.Namespace"            = "terraform-yaml-guestbook-${var.k8s_namespace}"
        "Octopus.Action.Script.ScriptSource"                       = "Inline"
      }
    }
  }

  step {
    condition    = "Always"
    name         = "helm-hello-world"
    target_roles = [var.k8s_target_role]

    action {
      name        = "helm-hello-world"
      action_type = "Octopus.HelmChartUpgrade"
      properties = {
        "Octopus.Action.Helm.ClientVersion"         = "V3"
        "Octopus.Action.Helm.Namespace"             = "terraform-helm-hello-world-${var.k8s_namespace}"
        "Octopus.Action.Helm.ReleaseName"           = "hello-world"
        "Octopus.Action.Helm.ResetValues"           = "True"
        "Octopus.Action.Package.DownloadOnTentacle" = "False"
        "Octopus.Action.Package.PackageId"          = "hello-world"
        "Octopus.Action.Helm.AdditionalArgs"        = "--create-namespace --wait"
        "Octopus.Action.Package.FeedId"             = var.helm_feed_id
        "Octopus.Action.RunOnServer"                = "False"
        "Octopus.Action.Script.ScriptSource"        = "Package"
        "Extract"                                   = "False"
      }
    }
  }

  step {
    name         = "deploy-kubernetes-config-map-resource"
    target_roles = [var.k8s_target_role]

    action {
      name        = "deploy-kubernetes-config-map-resource"
      action_type = "Octopus.KubernetesDeployConfigMap"
      properties = {
        "Octopus.Action.Kubernetes.ResourceStatusCheck"            = "True"
        "Octopus.Action.Kubernetes.ServerSideApply.Enabled"        = "True"
        "Octopus.Action.Kubernetes.ServerSideApply.ForceConflicts" = "True"
        "Octopus.Action.KubernetesContainers.ConfigMapName"        = "test"
        "Octopus.Action.KubernetesContainers.ConfigMapValues"      = "{\"abc\":\"def\"}"
        "Octopus.Action.KubernetesContainers.Namespace"            = "terraform-built-in-${var.k8s_namespace}"
      }
    }
  }

  step {
    condition    = "Always"
    name         = "deploy-kubernetes-containers"
    target_roles = [var.k8s_target_role]

    action {
      name        = "deploy-kubernetes-containers"
      action_type = "Octopus.KubernetesDeployContainers"
      properties = {
        "Octopus.Action.Kubernetes.DeploymentTimeout"                = "180"
        "Octopus.Action.Kubernetes.ResourceStatusCheck"              = "True"
        "Octopus.Action.Kubernetes.ServerSideApply.Enabled"          = "True"
        "Octopus.Action.Kubernetes.ServerSideApply.ForceConflicts"   = "True"
        "Octopus.Action.KubernetesContainers.Containers"             = "[{\"FeedId\": \"${var.docker_feed_id}\",\"Name\": \"nginx\"}]"
        "Octopus.Action.KubernetesContainers.DeploymentName"         = "my-deployment"
        "Octopus.Action.KubernetesContainers.DeploymentResourceType" = "Deployment"
        "Octopus.Action.KubernetesContainers.DeploymentStyle"        = "RollingUpdate"
        "Octopus.Action.KubernetesContainers.IngressAnnotations"     = "[]"
        "Octopus.Action.KubernetesContainers.PodManagementPolicy"    = "OrderedReady"
        "Octopus.Action.KubernetesContainers.Replicas"               = "1"
        "Octopus.Action.KubernetesContainers.ServiceNameType"        = "External"
        "Octopus.Action.KubernetesContainers.ServiceType"            = "ClusterIP"
        "Octopus.Action.KubernetesContainers.Namespace"              = "terraform-built-in-${var.k8s_namespace}"
        "Octopus.Action.RunOnServer"                                 = "False"
      }

      package {
        name                 = "nginx"
        acquisition_location = "NotAcquired"
        feed_id              = var.docker_feed_id
        package_id           = "nginx"
        properties = {
          Extract              = "False"
          PackageParameterName = ""
          SelectionMode        = "immediate"
        }
      }
    }
  }

  step {
    condition    = "Always"
    name         = "deploy-kubernetes-ingress-resource"
    target_roles = [var.k8s_target_role]

    action {
      name        = "deploy-kubernetes-ingress-resource"
      action_type = "Octopus.KubernetesDeployIngress"
      properties = {
        "Octopus.Action.Kubernetes.DeploymentTimeout"                = "180"
        "Octopus.Action.Kubernetes.ResourceStatusCheck"              = "True"
        "Octopus.Action.Kubernetes.ServerSideApply.Enabled"          = "True"
        "Octopus.Action.Kubernetes.ServerSideApply.ForceConflicts"   = "True"
        "Octopus.Action.KubernetesContainers.DefaultRulePort"        = "80"
        "Octopus.Action.KubernetesContainers.DefaultRuleServiceName" = "test"
        "Octopus.Action.KubernetesContainers.IngressAnnotations"     = "[]"
        "Octopus.Action.KubernetesContainers.IngressName"            = "test-ingress"
        "Octopus.Action.KubernetesContainers.Namespace"              = "terraform-built-in-${var.k8s_namespace}"
      }
    }
  }

  step {
    condition    = "Always"
    name         = "deploy-kubernetes-secret-resource"
    target_roles = [var.k8s_target_role]

    deploy_kubernetes_secret_action {
      name = "deploy-kubernetes-secret-resource"
      properties = {
        "Octopus.Action.Kubernetes.ResourceStatusCheck"            = "True"
        "Octopus.Action.Kubernetes.ServerSideApply.Enabled"        = "True"
        "Octopus.Action.Kubernetes.ServerSideApply.ForceConflicts" = "True"
        "Octopus.Action.KubernetesContainers.Namespace"            = "terraform-built-in-${var.k8s_namespace}"
      }

      secret_name   = "test-secret"
      secret_values = { "key" : "value" }
    }
  }

  step {
    condition    = "Always"
    name         = "deploy-kubernetes-service-resource"
    target_roles = [var.k8s_target_role]

    action {
      name        = "deploy-kubernetes-service-resource"
      action_type = "Octopus.KubernetesDeployService"
      properties = {
        "Octopus.Action.Kubernetes.DeploymentTimeout"              = "180"
        "Octopus.Action.Kubernetes.ResourceStatusCheck"            = "True"
        "Octopus.Action.Kubernetes.ServerSideApply.Enabled"        = "True"
        "Octopus.Action.Kubernetes.ServerSideApply.ForceConflicts" = "True"
        "Octopus.Action.KubernetesContainers.ServiceName"          = "test-service"
        "Octopus.Action.KubernetesContainers.ServicePorts"         = "[{\"name\":\"test\",\"port\":\"80\",\"targetPort\":\"80\",\"nodePort\":\"\",\"protocol\":\"TCP\"}]"
        "Octopus.Action.KubernetesContainers.ServiceType"          = "ClusterIP"
        "Octopus.Action.KubernetesContainers.Namespace"            = "terraform-built-in-${var.k8s_namespace}"
      }
    }
  }
}