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
