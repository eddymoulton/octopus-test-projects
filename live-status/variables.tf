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
# Datadog (optional). Leave datadog_api_key empty to skip Datadog entirely:
# no Agent is deployed and the app keeps emitting only to Prometheus, exactly
# as before. Set it (in the gitignored variables.auto.tfvars) to deploy a
# Datadog Agent that scrapes the same /metrics the Prometheus path already uses.
# Only an API key is needed for a metrics-scraping Agent — no Datadog APP key.
# --------------------------------------------------------------------------

variable "datadog_api_key" {
  type        = string
  sensitive   = true
  description = "Datadog API key. Empty (default) = skip Datadog; app emits only to Prometheus, as today."
  default     = ""
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
