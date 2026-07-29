# octopus-test-projects

Terraform rigs that stand up Octopus Deploy test setups against a local Octopus server and a local
Kubernetes cluster (Colima). Each top-level directory is an independent Terraform root: `cd` in,
`terraform init`, `terraform apply`.

## Common to all

- A local Octopus server. Most projects target `http://localhost:8065/`; `generic-project` and
  `tenant-project` target `:8066`. Addresses are `locals` in `main.tf`, not variables.
- Anything that installs an agent needs a running local cluster with a current `~/.kube/config`, and
  reaches Octopus from inside the cluster via `host.lima.internal` (Colima-specific).
- Secrets go in a per-project `variables.auto.tfvars` — gitignored, applied automatically.
- `terraform workspace` gives you multiple parallel copies (supported by `argo-cd`, `k8s-agent`,
  `live-status`, `generic-project`, `tenant-project`).
- `force-delete.sh` destroys a project that already has releases, which Terraform can't do on its own.
  Needs `terraform output` to expose `space` / `project_names` / `project_indexes`, so it only works
  for `generic-project` and `tenant-project`.

## Projects

### live-status

Octopus space for Live Application Status testing: Staging + Production, a manual lifecycle, a k8s
agent, Prometheus + Alertmanager (Helm), and `checkout` (untenanted) + `payments` (tenanted) projects
that deploy the synthetic-service app. Optionally mirrors metrics to Datadog and Sumo Logic, with
monitors and webhooks.

Configure:

- `owner` — **required, no default**. Scopes the shared Datadog org.
- `app_feed_username` / `app_feed_password` — GitHub username + *classic* PAT with `read:packages`, so
  Octopus can list image tags from GHCR. Skip if the package is public.
- `octopus_api_key` — defaults to `API-APIKEY01`.
- Optional: `datadog_api_key` (agent), `datadog_app_key` (monitors), `datadog_site`,
  `public_webhook_url` (must be publicly reachable — a tunnel), `sumologic_access_id` /
  `sumologic_access_key` / `sumologic_environment`.

See `live-status/README.md` for the demo runbook and the alerting details.

### argo-cd

"Argo Examples" space with Test + Production, a k8s agent and the Octopus Argo CD gateway (both Helm),
and sample projects covering image-tag and manifest updates across yaml, kustomize, helm, multi-source,
and SSH.

Configure:

- `octopus_api_key`, `argo_token`, `docker_username` / `docker_password`, `github_username` /
  `github_password`.
- Argo CD itself is installed out-of-band: run `install-argo.sh` first. It installs Argo CD,
  port-forwards it to `:8089`, creates a `gateway` user, and prints the token to use as `argo_token`.
- Hardcoded to Eddy's machine: the git credential is restricted to
  `github.com/eddymoulton/octopus-argo-cd-samples`, and `Octopus.Calamari.Executable` points at
  `/Users/eddy/octo/Calamari/...`. Change both.

### k8s-agent

"K8s Agent Examples \<workspace\>" space with Test + Production, a k8s agent + monitor (Helm), a
guestbook project, and Calamari local/debugging variable sets.

Configure: `octopus_api_key` (defaults to `API-APIKEY01`). `Octopus.Calamari.Executable` is hardcoded
to `/Users/eddy/octo/Calamari/source/Calamari/bin/Debug/net8.0/Calamari`.

Last touched March 2026 and still on octopusdeploy provider 1.7.2 (`live-status` is on 1.18.1), so
expect a provider bump before it applies cleanly.

### shared-agent — old, possibly broken

One agent + monitor installed into the cluster and registered against two Octopus spaces
("Kubernetes Examples" and "Kubernetes Examples 2"), to test a shared installation.

Configure: `octopus_api_key`.

Last touched January 2026. Two known problems: `main.tf` declares the `kubernetes` and `helm`
providers but never configures them (no `config_path`, unlike every other project here), and it
creates the same "Kubernetes Examples" space as `k8s-guestbook`, so the two can't coexist.

### k8s-guestbook — old, possibly broken

"Kubernetes Examples" space with an Example environment, a k8s agent + monitor (Helm), and one project
running the guestbook deployment process.

Configure: `octopus_api_key`.

Last touched January 2026, still on octopusdeploy provider 1.7.2. Collides with `shared-agent` on the
space name.

### generic-project — old, possibly broken

N identical projects created in an **existing** space, plus docker + helm feeds, a lifecycle, and a
project group. `process_type` selects which module under `deployment_processes/` becomes the
deployment process.

Configure:

- `access_token`, `docker_username` / `docker_password`, `target_role`.
- `server_address` (defaults `:8066`), `space_name`, `environment_id`.
- `number_of_projects`, `process_type` (`everything` | `argo` | `namespace_testing`),
  `auto_create_release`, `auto_create_release_minute_interval`.
- Requires an existing agent/target that satisfies `target_role` and `environment_id` — this project
  creates none.

`variables.tf` is commented with hints on the rest.

Last touched January 2026 and still on the legacy `OctopusDeployLabs/octopusdeploy` 0.38.0 provider
against port 8066. Both are likely to need updating.

### tenant-project — old, possibly broken

`generic-project` plus a "Tenant A" tenant connected to every created project. Same variables, same
legacy provider and port caveats.

## Supporting directories

- `deployment_processes/` — deployment process modules consumed by the projects above, not applied
  directly. `guestbook_process` and `synthetic_service_process` are on the current provider;
  `argo_install_process`, `everything_process`, and `namespace_testing` are still on 0.38.0 and only
  work from the legacy roots.
- `applications/synthetic-service/` — Go app (not Terraform) that emits fake Prometheus metrics
  labelled by Project/Environment/Tenant, plus a docker-compose stack with Prometheus. `docker compose
  up --build`, control panels on `:8081`–`:8085`. Published to GHCR by
  `.github/workflows/synthetic-service-image.yml`. See its README.
- `docs/` — plans and specs. Nothing to run.
