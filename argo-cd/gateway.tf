resource "kubernetes_namespace_v1" "example" {
  metadata {
    name = "octopus-argo-gateway-${replace(terraform.workspace, ".", "-")}"
  }
}

resource "helm_release" "argo_gateway" {
  name       = "octopus-argo-gateway-terraform"
  repository = "oci://registry-1.docker.io"
  chart      = "octopusdeploy/octopus-argocd-gateway-chart"
  version    = "1.15.0"
  atomic     = true
  namespace  = "octopus-argo-gateway-${replace(terraform.workspace, ".", "-")}"
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
    value = [octopusdeploy_environment.test.name, octopusdeploy_environment.prod.id]
  }]
}