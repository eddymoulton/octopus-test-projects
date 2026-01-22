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

resource "octopusdeploy_space" "main" {
  name                 = "Argo Examples"
  description          = "Terraform created Argo examples"
  space_managers_teams = [data.octopusdeploy_teams.everyone.teams[0].id]
}

resource "octopusdeploy_environment" "dev" {
  name     = "Development"
  space_id = octopusdeploy_space.main.id
}

resource "octopusdeploy_environment" "prod" {
  name     = "Production"
  space_id = octopusdeploy_space.main.id
}

resource "kubernetes_namespace_v1" "example" {
  metadata {
    name = "octopus-argo-gateway-example"
  }
}

resource "helm_release" "argo_gateway" {
  name       = "octopus-argo-gateway-terraform"
  repository = "oci://registry-1.docker.io"
  chart      = "octopusdeploy/octopus-argocd-gateway-chart"
  version    = "1.15.0"
  atomic     = true
  namespace  = "octopus-argo-gateway-example"
  timeout    = 60
  set = [
    {
      name  = "registration.octopus.name",
      value = "terraform-argo-gateway"
    },
    {
      name  = "registration.octopus.serverApiUrl"
      value = local.colima_octopus_address
    },
    {
      name  = "registration.octopus.serverAccessToken"
      value = var.octopus_api_key
    },
    {
      name  = "registration.octopus.spaceId"
      value = octopusdeploy_space.main.id
    },
    {
      name  = "gateway.octopus.serverGrpcUrl"
      value = local.colima_octopus_grpc_address
    },
    {
      name  = "gateway.argocd.serverGrpcUrl"
      value = "grpc://argocd-server.argocd.svc.cluster.local"
    },
    {
      name  = "gateway.argocd.insecure"
      value = "true"
    },
    {
      name  = "gateway.argocd.plaintext"
      value = "false"
    },
    {
      name  = "gateway.argocd.authenticationToken"
      value = var.argo_token
    }
  ]

  set_list = [{
    name  = "registration.octopus.environments"
    value = [octopusdeploy_environment.dev.name, octopusdeploy_environment.prod.id]
  }]
}

resource "octopusdeploy_lifecycle" "main" {
  description = "Testing lifecycle"
  name        = "terraform-created"
  space_id    = octopusdeploy_space.main.id

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
    automatic_deployment_targets = [octopusdeploy_environment.dev.id, octopusdeploy_environment.prod.id]
    name                         = "terraform"
  }
}

resource "octopusdeploy_project_group" "main" {
  description = "Terraform projects"
  name        = "terraform-created"
  space_id    = octopusdeploy_space.main.id
}

resource "octopusdeploy_project" "main" {
  space_id = octopusdeploy_space.main.id

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
