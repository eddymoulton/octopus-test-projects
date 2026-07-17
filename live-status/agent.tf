# Polling Kubernetes agent for this space, installed by Helm into the Colima
# cluster. Adapted from ../k8s-agent/agent.tf. The kubernetesMonitor (the k8s
# live-object monitor, separate from the Prometheus app-monitoring this space
# exercises) is not installed; the chart defaults it off.

resource "octopusdeploy_polling_subscription_id" "agent" {}
resource "octopusdeploy_tentacle_certificate" "agent" {}

resource "octopusdeploy_kubernetes_agent_deployment_target" "main" {
  name         = "Live Status Agent"
  space_id     = octopusdeploy_space.main.id
  environments = [octopusdeploy_environment.staging.id, octopusdeploy_environment.production.id]
  roles        = ["live-status"]

  # One agent serves untenanted (checkout) and tenanted (payments)
  # deployments; connect the payments tenants so they have a target to deploy to.
  tenanted_deployment_participation = "TenantedOrUntenanted"
  tenants                           = [octopusdeploy_tenant.acme.id, octopusdeploy_tenant.globex.id]

  thumbprint = octopusdeploy_tentacle_certificate.agent.thumbprint
  uri        = octopusdeploy_polling_subscription_id.agent.polling_uri
}

resource "kubernetes_namespace_v1" "agent" {
  metadata {
    name = "octopus-live-status-agent-${replace(terraform.workspace, ".", "-")}"
  }
}

resource "helm_release" "agent" {
  name       = "live-status-agent-${replace(terraform.workspace, ".", "-")}"
  repository = "oci://registry-1.docker.io"
  chart      = "octopusdeploy/kubernetes-agent"
  version    = "3.8.1"
  atomic     = true
  namespace  = kubernetes_namespace_v1.agent.metadata[0].name
  timeout    = 120

  set = [
    {
      name  = "agent.acceptEula"
      value = "Y"
    },
    {
      name  = "agent.name"
      value = octopusdeploy_kubernetes_agent_deployment_target.main.name
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
      value = octopusdeploy_polling_subscription_id.agent.polling_uri
    },
    {
      name  = "agent.space"
      value = octopusdeploy_space.main.name
    },
    {
      name  = "agent.deploymentTarget.enabled"
      value = "true"
    },
    {
      name  = "agent.targetName"
      value = octopusdeploy_kubernetes_agent_deployment_target.main.name
    }
  ]

  set_sensitive = [
    {
      name  = "agent.serverApiKey"
      value = var.octopus_api_key
    },
    {
      name  = "agent.certificate"
      value = octopusdeploy_tentacle_certificate.agent.base64
    }
  ]

  set_list = [
    {
      name  = "agent.deploymentTarget.initial.environments"
      value = octopusdeploy_kubernetes_agent_deployment_target.main.environments
    },
    {
      name  = "agent.deploymentTarget.initial.tags"
      value = octopusdeploy_kubernetes_agent_deployment_target.main.roles
    }
  ]
}
