resource "octopusdeploy_polling_subscription_id" "agent_subscription_id" {}
resource "octopusdeploy_tentacle_certificate" "agent_cert" {}

resource "octopusdeploy_kubernetes_agent_deployment_target" "main" {
  name         = "K8s Agent"
  space_id     = octopusdeploy_space.main.id
  environments = [octopusdeploy_environment.test.id, octopusdeploy_environment.prod.id]
  roles        = ["k8s-agent"]

  thumbprint = octopusdeploy_tentacle_certificate.agent_cert.thumbprint
  uri        = octopusdeploy_polling_subscription_id.agent_subscription_id.polling_uri
}

resource "random_uuid" "monitor_installation" {}

resource "octopusdeploy_kubernetes_monitor" "main" {
  space_id        = octopusdeploy_space.main.id
  installation_id = random_uuid.monitor_installation.result
  machine_id      = octopusdeploy_kubernetes_agent_deployment_target.main.id
}

resource "kubernetes_namespace_v1" "agent" {
  metadata {
    name = "octopus-k8s-agent-${replace(terraform.workspace, ".", "-")}"
  }
}

resource "helm_release" "kubernetes_agent" {
  name       = "k8s-agent-${replace(terraform.workspace, ".", "-")}"
  repository = "oci://registry-1.docker.io"
  chart      = "octopusdeploy/kubernetes-agent"
  version    = "2.34.0"
  atomic     = true
  namespace  = "octopus-k8s-agent-${replace(terraform.workspace, ".", "-")}"
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
      value = octopusdeploy_polling_subscription_id.agent_subscription_id.polling_uri
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
      value = octopusdeploy_kubernetes_monitor.main.installation_id
    },
    {
      name  = "kubernetesMonitor.monitor.serverThumbprint"
      value = octopusdeploy_kubernetes_monitor.main.certificate_thumbprint
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
      value = octopusdeploy_kubernetes_monitor.main.authentication_token
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
