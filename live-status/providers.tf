terraform {
  required_providers {
    octopusdeploy = {
      source  = "OctopusDeploy/octopusdeploy"
      version = "1.18.1"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "3.2.1"
    }

    helm = {
      source  = "registry.terraform.io/hashicorp/helm"
      version = "3.2.0"
    }

    datadog = {
      source  = "DataDog/datadog"
      version = "4.16.0"
    }
  }
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

# Talks to the Datadog API, not the cluster — only the monitors in datadog.tf
# use it (the Agent is a helm_release and needs nothing from here).
#
# validate is tied to the monitors' own enable flag: with no keys the provider
# would otherwise try to authenticate at configure time and fail the plan even
# though every resource using it is count 0. Turning validate off in that case
# keeps a keyless plan clean.
provider "datadog" {
  api_key  = var.datadog_api_key
  app_key  = var.datadog_app_key
  api_url  = "https://api.${var.datadog_site}/"
  validate = local.datadog_monitors_enabled
}
