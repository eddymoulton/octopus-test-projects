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
# Prometheus (on by default), the rig's baseline metrics tier.
#
# The opposite shape to the Datadog and Sumo Logic tiers below: those are gated
# on credentials and stay off until you supply them, whereas Prometheus needs
# nothing but the cluster, so it defaults on and has to be switched off
# explicitly. Off means every resource in prometheus.tf is count 0 — no
# monitoring namespace, no Helm release, and so no alerting rules and no
# Alertmanager webhook to Octopus. The app is untouched and keeps carrying its
# prometheus.io scrape annotations, so turning this back on resumes scraping
# with no redeploy.
# --------------------------------------------------------------------------

variable "prometheus_enabled" {
  type        = bool
  description = "Deploy the in-cluster Prometheus + Alertmanager stack (prometheus.tf). false = no monitoring namespace, no Helm release, no alerting rules, and nothing posting Prometheus alerts to the Octopus webhook."
  default     = true
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

variable "public_webhook_url" {
  type        = string
  description = "External URL that Datadog and Sumo Logic POST monitor health events to. Both call from their own servers, not from the cluster, so it must be reachable from the public internet rather than just this machine — hence a tunnel. One variable for both because they send the same flat body to the same endpoint. Empty (default) = create no webhook/connection and leave the monitors notifying nothing. No shared default on purpose: a committed URL would point every teammate's alerts at one person's tunnel."
  default     = ""

  validation {
    condition     = var.public_webhook_url == "" || startswith(var.public_webhook_url, "https://") || startswith(var.public_webhook_url, "http://")
    error_message = "public_webhook_url must be empty or an http(s) URL."
  }
}

# Renamed to public_webhook_url, now that Sumo Logic needs the same tunnel URL.
# Kept declared, and required to be empty, only because a stale value in
# variables.auto.tfvars would otherwise be an ignorable warning rather than an
# error — and the silent consequence is that no Datadog webhook gets created.
# Delete this block once variables.auto.tfvars no longer sets it.
variable "datadog_webhook_url" {
  type    = string
  default = ""

  validation {
    condition     = var.datadog_webhook_url == ""
    error_message = "datadog_webhook_url has been renamed to public_webhook_url; rename the key in variables.auto.tfvars."
  }
}

# --------------------------------------------------------------------------
# Sumo Logic (optional), a single credential tier.
#
# Unlike Datadog — where the Agent needs only an API key and monitors need a
# second APP key — Sumo can't be split: the ingest endpoint is itself created
# through the API, so the same access pair gates collection and alerting.
# public_webhook_url remains an independent third gate, as it is for Datadog.
#
# Leave these empty to skip Sumo Logic entirely: no hosted collector, no HTTP
# source, no OTel collector in the cluster, no monitors. Set them in the
# gitignored variables.auto.tfvars.
# --------------------------------------------------------------------------

variable "sumologic_access_id" {
  type        = string
  sensitive   = true
  description = "Sumo Logic Access ID. Empty (default) = skip Sumo Logic entirely."
  default     = ""
}

variable "sumologic_access_key" {
  type        = string
  sensitive   = true
  description = "Sumo Logic Access Key. Empty (default) = skip Sumo Logic entirely."
  default     = ""
}

variable "sumologic_environment" {
  type        = string
  description = "Sumo Logic deployment the org lives in (au, us1, us2, ca, de, eu, fed, in, jp, kr). Must match the org or every API call fails; validated here so a typo fails the plan rather than the apply."
  default     = "au"

  validation {
    condition     = contains(["au", "us1", "us2", "ca", "de", "eu", "fed", "in", "jp", "kr"], var.sumologic_environment)
    error_message = "sumologic_environment must be one of: au, us1, us2, ca, de, eu, fed, in, jp, kr."
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
