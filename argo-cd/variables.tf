variable "octopus_api_key" {
  type      = string
  sensitive = true
}

variable "argo_token" {
  type      = string
  sensitive = true
}

variable "docker_username" {
  type = string
}

variable "docker_password" {
  type      = string
  sensitive = true
}

variable "github_username" {
  type = string
}

variable "github_password" {
  type      = string
  sensitive = true
}