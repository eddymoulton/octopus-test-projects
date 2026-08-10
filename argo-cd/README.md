# argo-cd

An "Argo Examples" space with Test and Production, a Kubernetes agent alongside the Octopus Argo
CD gateway, and a set of sample projects covering image tag and manifest updates across yaml,
kustomize, helm, multi-source, and SSH.

## Setup

Argo CD itself isn't Terraform's job here. Run `./install-argo.sh` first — it installs Argo CD,
port-forwards it to `:8089`, creates a `gateway` user, and prints a token. You'll want that token
in a moment.

Then fill in `variables.auto.tfvars`:

- `octopus_api_key`
- `argo_token`, the one `install-argo.sh` just printed
- `docker_username` and `docker_password`
- `github_username` and `github_password`

## Run it

```
terraform init
terraform apply
```

## Worth knowing

This one is wired to Eddy's machine in two places you'll have to change. The git credential is
locked to `github.com/eddymoulton/octopus-argo-cd-samples`, and `Octopus.Calamari.Executable`
points at `/Users/eddy/octo/Calamari/...`.

It's also still on octopusdeploy provider 1.7.2, while `live-status` has moved on to 1.18.1.
