# Basic config
variable "server_address" {
  type    = string
  default = "http://localhost:8066/"
}

variable "access_token" {
  type      = string
  sensitive = true
  default   = "API-APIKEY01"
}

variable "space_name" {
  type    = string
  default = "Default"
}

variable "space_id" {
  type    = string
  default = "Spaces-1"
}

variable "environment_id" {
  type    = string
  default = "Environments-1"
}

variable "target_role" {
  type    = string
  default = "k8s"
}

# Feeds
variable "docker_username" {
  type    = string
  default = "<TODO>"
}

variable "docker_password" {
  type      = string
  sensitive = true
  default   = "<TODO>"
}

# Project config
variable "number_of_projects" {
  type    = number
  default = 1
}

## Sets the deployment process for all created projects to one of the modules under ./deployment_processes
variable "process_type" {
  type    = string
  default = "everything"

  validation {
    condition     = contains(["everything", "argo"], var.process_type)
    error_message = "Unknown process type"
  }
}

variable "auto_create_release" {
  type    = bool
  default = false
}

## Don't set this too low with lots of projects or you'll have a mess to clean up
variable "auto_create_release_minute_interval" {
  type    = number
  default = 10
}