# shared-agent

Installs a single agent and monitor into the cluster, then registers it against two Octopus
spaces — "Kubernetes Examples" and "Kubernetes Examples 2" — to see whether a shared installation
holds up.

## Setup

Only `octopus_api_key`.

## Run it

```
terraform init
terraform apply
```

## Worth knowing

Fair warning: this one probably doesn't work. It hasn't been touched since January 2026, and
there are two known problems.

`main.tf` declares the `kubernetes` and `helm` providers but never configures them, with no
`config_path`, unlike every other project here. It also creates the same "Kubernetes Examples"
space that `k8s-guestbook` does, so the two can't both exist.

It's on octopusdeploy provider 1.7.2 as well.
