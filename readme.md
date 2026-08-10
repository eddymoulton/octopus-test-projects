# octopus-test-projects

Terraform rigs for standing up Octopus Deploy test setups against a local Octopus server and a
local Kubernetes cluster (Colima). Each top-level folder is its own Terraform root — pick one,
`cd` in, then `terraform init` and `terraform apply`.

Some of these get used regularly. Others have been sitting since early 2026 and need a provider
bump before they'll apply cleanly. The table below says which is which.

## Before you start

- You'll need a local Octopus server. Most projects expect it at `http://localhost:8065/`, but
  `generic-project` and `tenant-project` want `:8066`. The addresses are `locals` in `main.tf`
  rather than variables, so changing them means editing code.
- Anything that installs an agent needs a running cluster with a current `~/.kube/config`. Agents
  reach Octopus from inside the cluster through `host.lima.internal`, which is a Colima thing.
- Secrets go in a per-project `variables.auto.tfvars`. It's gitignored, and Terraform picks it up
  automatically.
- Terraform can't destroy a project that already has releases. `force-delete.sh` will, but only
  for `generic-project` and `tenant-project`.

## The projects

| Project | What you get | State |
|---|---|---|
| [live-status](live-status/README.md) | The Live Application Status rig: an agent, Prometheus and Alertmanager, and two apps busily emitting metrics. Datadog and Sumo Logic are there if you want them. | Current |
| [argo-cd](argo-cd/README.md) | An "Argo Examples" space with an agent, the Octopus Argo CD gateway, and sample projects covering image tag and manifest updates. | Works, but dated |
| [k8s-agent](k8s-agent/README.md) | A "K8s Agent Examples" space with an agent, a monitor, and a guestbook project. | Stale |
| [k8s-guestbook](k8s-guestbook/README.md) | A "Kubernetes Examples" space with an agent, a monitor, and one guestbook project. | Stale |
| [generic-project](generic-project/README.md) | However many identical projects you ask for, dropped into a space you already have. | Stale |
| [tenant-project](tenant-project/README.md) | `generic-project`, plus a tenant wired to every project it makes. | Stale |
| [shared-agent](shared-agent/readme.md) | One agent and monitor registered against two spaces at once. | Broken |

"Stale" means untouched since early 2026 and still on an old provider. Each README spells out
what needs attention.

## Everything else

- `deployment_processes/` holds the deployment process modules the projects above pull in. You
  don't apply these directly.
- `applications/synthetic-service/` is the Go app behind `live-status`, emitting fake Prometheus
  metrics on cue. It has [its own README](applications/synthetic-service/README.md).
- `docs/` is plans and specs. Nothing to run.
