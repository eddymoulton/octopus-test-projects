output "space" {
  value = var.space_name
}

output "project_indexes" {
  value = keys(module.project)[*]
}

output "project_names" {
  value = values(module.project)[*].project_name
}
