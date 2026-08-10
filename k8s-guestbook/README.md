# k8s-guestbook

A "Kubernetes Examples" space with a single Example environment, a Kubernetes agent and monitor
installed by Helm, and one project running the guestbook deployment process.

## Setup

Only `octopus_api_key`.

## Run it

```
terraform init
terraform apply
```

## Worth knowing

Untouched since January 2026 and still on octopusdeploy provider 1.7.2, so expect to bump it.

It also wants the same "Kubernetes Examples" space as `shared-agent`, so only one of the two can
exist at a time.
