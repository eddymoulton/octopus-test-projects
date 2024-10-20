## Required setup

- An existing agent/API target set up that satisfies the `target_role` and `environment_id`

## Required variables (local dev)

- `docker_username`
- `docker_password`
- `target_role`

Add a `variables.auto.tfvars` file to automatically apply vars

## Changing other settings

`variables.tf` is commented with some short hints about what does what

## Multiple instances

Use `terraform workspace` to manage creating multiple instances or combinations of a project
