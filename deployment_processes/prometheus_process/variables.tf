variable "space_id" {
  type = string
}

variable "project_id" {
  type = string
}

variable "target_role" {
  type = string
}

variable "monitoring_namespace" {
  type    = string
  default = "live-status-monitoring"
}
