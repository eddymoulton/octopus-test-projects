variable server_address {
  type    = string
  default = "http://localhost:8066/"
}

variable access_token {
  type      = string
  sensitive = true
  default   = "API-APIKEY01"
}

variable docker_username {
  type = string
  default = "<TODO>"
}

variable docker_password {
  type      = string
  sensitive = true
  default = "<TODO>"
}

variable space_id {
  type    = string
  default = "Spaces-1"
}

variable environment_id {
  type    = string
  default = "Environments-1"
}

variable k8s_target_role {
  type    = string
  default = "k8s"
}

variable auto_create_release {
  type    = bool
  default = false
}

variable auto_create_release_minute_interval {
  type    = number
  default = 10
}

variable number_of_projects {
  type    = number
  default = 1
}

variable process_type {
  type    = string
  default = "everything"

  validation {
    condition     = contains(["everything", "argo"], var.process_type)
    error_message = "Unknown process type"
  }
}