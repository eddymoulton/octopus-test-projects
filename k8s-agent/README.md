# k8s-agent

A "K8s Agent Examples \<workspace\>" space with Test and Production, a Kubernetes agent and
monitor installed by Helm, a guestbook project, and a couple of variable sets for local Calamari
debugging.

## Setup

Only `octopus_api_key`, and it defaults to `API-APIKEY01`, so you may not need to set anything at
all.

## Run it

```
terraform init
terraform apply
```

## Worth knowing

`Octopus.Calamari.Executable` is hardcoded to
`/Users/eddy/octo/Calamari/source/Calamari/bin/Debug/net8.0/Calamari`, so point that at your own
build.

Nobody has touched this since March 2026 and it's still on octopusdeploy provider 1.7.2, where
`live-status` is on 1.18.1. Expect to bump it before it applies cleanly.
