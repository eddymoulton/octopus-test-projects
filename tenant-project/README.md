# tenant-project

[`generic-project`](../generic-project/README.md) with a "Tenant A" tenant connected to every
project it creates.

## Setup

The same variables as `generic-project`, plus `space_id`.

## Run it

```
terraform init
terraform apply
```

Same story on teardown: once there are releases, reach for `../force-delete.sh`.

## Worth knowing

The same caveats too. Untouched since January 2026, and still on the legacy
`OctopusDeployLabs/octopusdeploy` 0.38.0 provider against port 8066.
