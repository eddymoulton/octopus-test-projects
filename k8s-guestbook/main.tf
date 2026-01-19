terraform {
  required_providers {
    octopusdeploy = {
      source  = "OctopusDeploy/octopusdeploy"
      version = "1.7.2"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "3.0.1"
    }

    helm = {
      source  = "registry.terraform.io/hashicorp/helm"
      version = "3.1.1"
    }
  }
}

locals {
  octopus_address                = "http://localhost:8065/"
  colima_octopus_address         = "http://host.lima.internal:8065/"
  colima_octopus_grpc_address    = "grpc://host.lima.internal:8443"
  colima_octopus_polling_address = "http://host.lima.internal:10943/"
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes = {
    config_path = "~/.kube/config"
  }
}

provider "octopusdeploy" {
  address = local.octopus_address
  api_key = var.octopus_api_key
}

data "octopusdeploy_teams" "everyone" {
  partial_name = "Everyone"
  skip         = 0
  take         = 1
}

resource "octopusdeploy_space" "monitoring" {
  name                 = "Kubernetes Examples"
  description          = "Terraform created examples"
  space_managers_teams = [data.octopusdeploy_teams.everyone.teams[0].id]
}

resource "octopusdeploy_environment" "example" {
  name     = "Example"
  space_id = octopusdeploy_space.monitoring.id
}

resource "octopusdeploy_polling_subscription_id" "agent_subscription_id" {}
resource "octopusdeploy_tentacle_certificate" "agent_cert" {}

# Create the Kubernetes agent deployment target
resource "octopusdeploy_kubernetes_agent_deployment_target" "example" {
  name         = "Example Kubernetes Agent"
  space_id     = octopusdeploy_space.monitoring.id
  environments = [octopusdeploy_environment.example.id]
  roles        = ["k8s-agent", "monitoring-enabled"]

  thumbprint = octopusdeploy_tentacle_certificate.agent_cert.thumbprint
  uri        = octopusdeploy_polling_subscription_id.agent_subscription_id.polling_uri
}

# Generate a unique installation ID for the monitor
resource "random_uuid" "monitor_installation" {}

# Create the Kubernetes monitor
resource "octopusdeploy_kubernetes_monitor" "example" {
  space_id        = octopusdeploy_space.monitoring.id
  installation_id = random_uuid.monitor_installation.result
  machine_id      = octopusdeploy_kubernetes_agent_deployment_target.example.id
}

resource "kubernetes_namespace_v1" "example" {
  metadata {
    name = "octopus-agent-example"
  }
}

# Install the Kubernetes agent and monitor via Helm
resource "helm_release" "kubernetes_agent" {
  name       = "example-kubernetes-agent"
  repository = "oci://registry-1.docker.io"
  chart      = "octopusdeploy/kubernetes-agent"
  version    = "2.34.0"
  atomic     = true
  namespace  = "octopus-agent-example"
  timeout    = 120

  set = [
    {
      name  = "agent.acceptEula"
      value = "Y"
    },
    {
      name  = "agent.name"
      value = octopusdeploy_kubernetes_agent_deployment_target.example.name
    },
    {
      name  = "agent.serverUrl"
      value = local.colima_octopus_address
    },
    {
      name  = "agent.serverCommsAddress"
      value = local.colima_octopus_polling_address
    },
    {
      name  = "agent.serverSubscriptionId"
      value = octopusdeploy_polling_subscription_id.agent_subscription_id.polling_uri
    },
    {
      name  = "agent.space"
      value = octopusdeploy_space.monitoring.name
    },
    {
      name  = "agent.deploymentTarget.enabled"
      value = "true"
    },
    {
      name  = "agent.targetName"
      value = octopusdeploy_kubernetes_agent_deployment_target.example.name
    },
    {
      name  = "kubernetesMonitor.enabled"
      value = "true"
    },
    {
      name  = "kubernetesMonitor.registration.register"
      value = "false"
    },
    {
      name  = "kubernetesMonitor.monitor.serverGrpcUrl"
      value = local.colima_octopus_grpc_address
    },
    {
      name  = "kubernetesMonitor.monitor.installationId"
      value = octopusdeploy_kubernetes_monitor.example.installation_id
    },
    {
      name  = "kubernetesMonitor.monitor.serverThumbprint"
      value = octopusdeploy_kubernetes_monitor.example.certificate_thumbprint
    }
  ]

  set_sensitive = [
    {
      name  = "agent.serverApiKey"
      value = var.octopus_api_key
    },
    {
      name  = "agent.certificate"
      value = octopusdeploy_tentacle_certificate.agent_cert.base64
    },
    {
      name  = "kubernetesMonitor.monitor.authenticationToken"
      value = octopusdeploy_kubernetes_monitor.example.authentication_token
    }
  ]

  set_list = [
    {
      name  = "agent.deploymentTarget.initial.environments"
      value = octopusdeploy_kubernetes_agent_deployment_target.example.environments
    },
    {
      name  = "agent.deploymentTarget.initial.tags"
      value = octopusdeploy_kubernetes_agent_deployment_target.example.roles
    }
  ]
}

resource "octopusdeploy_lifecycle" "main" {
  description = "Testing lifecycle"
  name        = "terraform-created"
  space_id    = octopusdeploy_space.monitoring.id

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
    automatic_deployment_targets = [octopusdeploy_environment.example.id]
    name                         = "terraform"
  }
}

resource "octopusdeploy_project_group" "main" {
  description = "Terraform projects"
  name        = "terraform-created"
  space_id    = octopusdeploy_space.monitoring.id
}

resource "octopusdeploy_project" "main" {
  space_id = octopusdeploy_space.monitoring.id

  default_guided_failure_mode          = "EnvironmentDefault"
  default_to_skip_if_already_installed = false
  description                          = "Terraform created"
  is_disabled                          = false
  is_discrete_channel_release          = false
  lifecycle_id                         = octopusdeploy_lifecycle.main.id
  name                                 = "Terraform created"
  tenanted_deployment_participation    = "Untenanted"
  included_library_variable_sets       = []
  project_group_id                     = octopusdeploy_project_group.main.id
}

module "guestbook_process" {
  source = "../deployment_processes/guestbook_process"

  space_id      = octopusdeploy_space.monitoring.id
  project_id    = octopusdeploy_project.main.id
  k8s_namespace = octopusdeploy_project.main.slug
  target_role   = "k8s-agent"
}