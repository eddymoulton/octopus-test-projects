# Two "service" projects deploy the app. Project name = the `service`
# label the app emits, so the same synthetic_service_process module serves both.
#   checkout: Untenanted
#   payments: Tenanted (acme, globex)

# ---------------------------------------------------------------- checkout
resource "octopusdeploy_project" "checkout" {
  space_id = octopusdeploy_space.main.id

  name                                 = "checkout"
  description                          = "Synthetic service instance: checkout service"
  lifecycle_id                         = octopusdeploy_lifecycle.main.id
  project_group_id                     = octopusdeploy_project_group.main.id
  tenanted_deployment_participation    = "Untenanted"
  default_guided_failure_mode          = "EnvironmentDefault"
  default_to_skip_if_already_installed = false
  is_disabled                          = false
  is_discrete_channel_release          = false
  included_library_variable_sets       = []
}

module "checkout_process" {
  source = "../deployment_processes/synthetic_service_process"

  space_id         = octopusdeploy_space.main.id
  project_id       = octopusdeploy_project.checkout.id
  target_role      = "live-status"
  docker_feed_id   = octopusdeploy_docker_container_registry.app.id
  image_package_id = var.app_image_package
}

# ---------------------------------------------------------------- payments
resource "octopusdeploy_project" "payments" {
  space_id = octopusdeploy_space.main.id

  name                                 = "payments"
  description                          = "Synthetic service instance: payments service (tenanted)"
  lifecycle_id                         = octopusdeploy_lifecycle.main.id
  project_group_id                     = octopusdeploy_project_group.main.id
  tenanted_deployment_participation    = "Tenanted"
  default_guided_failure_mode          = "EnvironmentDefault"
  default_to_skip_if_already_installed = false
  is_disabled                          = false
  is_discrete_channel_release          = false
  included_library_variable_sets       = []
}

module "payments_process" {
  source = "../deployment_processes/synthetic_service_process"

  space_id         = octopusdeploy_space.main.id
  project_id       = octopusdeploy_project.payments.id
  target_role      = "live-status"
  docker_feed_id   = octopusdeploy_docker_container_registry.app.id
  image_package_id = var.app_image_package
}

# ---------------------------------------------------------------- tenants
resource "octopusdeploy_tenant" "acme" {
  name     = "acme"
  space_id = octopusdeploy_space.main.id
}

resource "octopusdeploy_tenant" "globex" {
  name     = "globex"
  space_id = octopusdeploy_space.main.id
}

resource "octopusdeploy_tenant_project" "acme_payments" {
  space_id        = octopusdeploy_space.main.id
  tenant_id       = octopusdeploy_tenant.acme.id
  project_id      = octopusdeploy_project.payments.id
  environment_ids = [octopusdeploy_environment.production.id, octopusdeploy_environment.staging.id]
}

resource "octopusdeploy_tenant_project" "globex_payments" {
  space_id        = octopusdeploy_space.main.id
  tenant_id       = octopusdeploy_tenant.globex.id
  project_id      = octopusdeploy_project.payments.id
  environment_ids = [octopusdeploy_environment.production.id, octopusdeploy_environment.staging.id]
}
