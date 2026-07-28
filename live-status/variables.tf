# --------------------------------------------------------------------------
# Who is running this copy of the rig.
#
# Deliberately has NO default. Everything else here is per-machine and can't
# collide, but a shared Datadog org is one namespace for everybody: metrics,
# monitors and webhooks from every teammate land in the same place. This value
# is the discriminator that keeps them apart, so an unset owner has to fail the
# plan rather than quietly inherit someone else's identity.
# --------------------------------------------------------------------------

variable "owner" {
  type        = string
  description = "Short identifier for whoever is running this rig (e.g. your username). Keeps Datadog metrics, monitors and webhooks distinct in a Datadog org shared with teammates."

  validation {
    # Has to be safe as both a Datadog tag value and a webhook name, and
    # lowercase because Datadog lowercases tags anyway.
    condition     = can(regex("^[a-z0-9][a-z0-9-]*$", var.owner))
    error_message = "owner must be lowercase alphanumeric with dashes, starting with a letter or digit (e.g. \"eddy\" or \"eddy-m\")."
  }
}

variable "octopus_api_key" {
  type      = string
  sensitive = true
  default   = "API-APIKEY01"
}

# --------------------------------------------------------------------------
# App image, published to GHCR by the GitHub workflow
# (.github/workflows/synthetic-service-image.yml). If the GHCR package is public,
# no credentials are needed (leave username/password empty). For a private
# package, set username to your GitHub user and password to a *classic* PAT with
# read:packages (fine-grained PATs don't expose that scope).
# --------------------------------------------------------------------------

variable "app_feed_uri" {
  type        = string
  description = "Docker registry URI for the app image feed."
  default     = "https://ghcr.io"
}

variable "app_feed_username" {
  type        = string
  description = "Registry username. Only needed for a private GHCR package (your GitHub username); leave empty for a public package."
  default     = ""
}

variable "app_feed_password" {
  type        = string
  sensitive   = true
  description = "Registry password. Only needed for a private GHCR package (a classic PAT with read:packages); leave empty for a public package."
  default     = ""
}

variable "app_image_package" {
  type        = string
  description = "Container image (package) id for the app in the GHCR feed, without the registry host."
  default     = "eddymoulton/synthetic-service"
}

# --------------------------------------------------------------------------
# Datadog (optional), in two independent tiers:
#
#   datadog_api_key alone -> the metrics-scraping Agent (datadog.tf). This is
#     all you need to get app_* metrics into Datadog.
#   + datadog_app_key     -> additionally manages monitors through the Datadog
#     API, which is the one thing an API key can't do on its own.
#
# Leave datadog_api_key empty to skip Datadog entirely: no Agent, no monitors,
# and the app keeps emitting only to Prometheus, exactly as before. Set these
# in the gitignored variables.auto.tfvars.
# --------------------------------------------------------------------------

variable "datadog_api_key" {
  type        = string
  sensitive   = true
  description = "Datadog API key. Empty (default) = skip Datadog; app emits only to Prometheus, as today."
  default     = ""
}

variable "datadog_app_key" {
  type        = string
  sensitive   = true
  description = "Datadog APP key, required only to manage monitors (the Agent doesn't need one). Empty (default) = deploy the Agent but create no monitors."
  default     = ""
}

variable "datadog_webhook_url" {
  type        = string
  description = "External URL Datadog POSTs monitor health events to. Must be reachable from Datadog's servers, not just the local machine — hence a tunnel. Empty (default) = create no webhook and leave the monitor notifying nothing. No shared default on purpose: a committed URL would point every teammate's alerts at one person's tunnel."
  default     = ""

  validation {
    condition     = var.datadog_webhook_url == "" || startswith(var.datadog_webhook_url, "https://") || startswith(var.datadog_webhook_url, "http://")
    error_message = "datadog_webhook_url must be empty or an http(s) URL."
  }
}

variable "datadog_site" {
  type        = string
  description = "Datadog site/region for the Agent, e.g. datadoghq.com (US1), us5.datadoghq.com, datadoghq.eu."
  default     = "datadoghq.com"

  validation {
    condition     = trimspace(var.datadog_site) != ""
    error_message = "datadog_site must not be empty (e.g. datadoghq.com, us5.datadoghq.com, datadoghq.eu)."
  }
}
