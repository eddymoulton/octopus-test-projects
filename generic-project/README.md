# generic-project

Creates however many identical projects you ask for inside a space you already have, along with
docker and helm feeds, a lifecycle, and a project group. `process_type` decides which module
under `deployment_processes/` becomes their deployment process.

## Setup

This one creates no targets, so you'll need an existing agent that already satisfies your
`target_role` and `environment_id`. Without one, the deployments have nowhere to go.

In `variables.auto.tfvars`:

- `access_token`, `docker_username`, `docker_password`, and `target_role`
- `server_address` (defaults to `:8066`), `space_name`, and `environment_id`
- `number_of_projects`, and `process_type`, which takes `everything`, `argo`, or
  `namespace_testing`
- `auto_create_release` and `auto_create_release_minute_interval`, if you want releases appearing
  on their own

`variables.tf` has comments covering the rest.

## Run it

```
terraform init
terraform apply
```

Once the projects have releases, Terraform can't destroy them. Use `../force-delete.sh` for that.

## Worth knowing

Last touched January 2026, and still on the legacy `OctopusDeployLabs/octopusdeploy` 0.38.0
provider talking to port 8066. Both will probably need updating before this runs.
