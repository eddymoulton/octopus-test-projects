# live-status: Octopus space for Live Application Status testing

Terraform that stands up an Octopus Space to exercise application updates against the synthetic-service app that
emits Live Application Status metrics, running in the local Colima k8s cluster. Mirrors the conventions of the
sibling `../k8s-agent/` example (provider `OctopusDeploy/octopusdeploy` 1.18.0, polling k8s agent via Helm,
deployment processes as modules under `../deployment_processes/`).

## What it creates

- Space `Live Application Status <workspace>`, Environments Staging + Production, a manual
  lifecycle (Staging → Production via `optional_deployment_targets`), a project group, and a Docker feed
  (`synthetic-service-images`) for the app image.
- Kubernetes agent (`Live Status Agent`, role `live-status`) installed by Helm into the cluster. The
  `kubernetesMonitor` is not installed (that's the k8s live-object monitor, separate from the Prometheus
  app-monitoring exercised here).
- Prometheus (namespace `live-status-monitoring`), deployed by Terraform via the
  `prometheus-community/prometheus` Helm chart (`prometheus.tf`) — server only, annotation-based pod
  scraping, Service `prometheus:9090`, and an Ingress at `http://prometheus.localhost`. Comes up at
  `terraform apply` (no Octopus project involved). Migrating a cluster that already has an
  Octopus-deployed Prometheus in this namespace? Delete it first (`kubectl delete ns live-status-monitoring`)
  so Terraform doesn't collide with the existing resources.
- checkout (untenanted) and payments (tenanted: `acme`, `globex`) projects →
  `../deployment_processes/synthetic_service_process`: deploy the app. Project name = the `service` label.
  A prompted Variant (Good/Bad) drives `App.ErrorRate`; `Octopus.Release.Number` → the `release`
  label; the image tag is picked from the Docker feed per release. Each instance also gets a Service + a
  Traefik Ingress at `http://<instance>.localhost`.

## Before `terraform apply`: resolve with Eddy

1. App image (GHCR): the image is published to `ghcr.io/eddymoulton/synthetic-service` by the workflow.
   `app_feed_uri` and `app_image_package` default to the GHCR values, but you must give Octopus a GitHub token
   so the Docker feed can list image tags. Add it to `live-status/variables.auto.tfvars` (gitignored, so the
   secret stays out of git):

   ```hcl
   app_feed_username = "eddymoulton"   # your GitHub username
   app_feed_password = "ghp_…"         # a *classic* PAT with read:packages
   ```

   Use a classic PAT: fine-grained PATs don't expose the `read:packages` scope. (Alternatively, make the
   GHCR package public and leave both empty to pull anonymously.) For pods to pull a private package, also
   add an `imagePullSecret` to the manifest. The manifest already prefixes the `ghcr.io/` host on the image
   string.
2. Confirm the Colima kube context is current and the Octopus addresses in `main.tf` locals still match your
   setup (`localhost:8065`, `host.lima.internal` grpc/polling).
3. `octopus_api_key` defaults to `API-APIKEY01`; override for your instance.

## Apply + demo runbook

```
cd live-status
terraform init
terraform apply            # creates space, agent + prometheus (helm), test projects
# wait for the "Live Status Agent" target to go healthy in Octopus
```

1. Prometheus is already up — Terraform deploys it at `terraform apply`. View it at
   `http://prometheus.localhost`, or `kubectl -n live-status-monitoring port-forward svc/prometheus 9090:9090`
   → http://localhost:9090
2. Baseline good: release payments, pick the image tag, deploy to Production for `acme` (and
   `globex`) with Variant=Good. Repeat checkout → Production. Confirm pods:
   `kubectl -n live-status-production get pods`.
3. Observe healthy: in Prometheus, `avg by (service, env) (app_request_success_rate)` ≈ 1.0. Series carry
   `service` / `env` / `tenant` / `release`.
4. Bad deploy: new release of payments → Production/`acme`, Variant=Bad. The rollout replaces the
   pod (new `release`, error rate 0.10); success rate drops < 0.95 within a scrape or two. That's the
   deployment-correlated regression.
5. Roll forward: new release, Variant=Good → recovers.

## Optional: mirror metrics to Datadog

The app's metrics (`app_request_success_rate`, `app_requests_total`, latency
histograms, etc.) go to Prometheus by default. To **also** send them to Datadog,
provide a Datadog API key — nothing else changes, and the metrics keep flowing to
Prometheus too.

Add to `live-status/variables.auto.tfvars` (gitignored, so the key stays out of
git):

```hcl
datadog_api_key = "…"             # a Datadog API key
datadog_app_key = "…"             # optional; only needed to create monitors (see below)
datadog_site    = "datadoghq.com" # optional; your DD site, e.g. us5.datadoghq.com, datadoghq.eu
```

On the next `terraform apply`, a Datadog Agent (Helm chart `datadog/datadog`) is
deployed into a `datadog-<workspace>` namespace. It uses Datadog's Prometheus
autodiscovery to scrape the same `prometheus.io/scrape` pods Prometheus already
scrapes, so Datadog collects the same `app_*` metrics (counts, latency, success
rate), tagged by `service` / `env` / `tenant` / `release`. Datadog's OpenMetrics
check may name or shape some series (notably histograms) differently from
Prometheus's raw output. The Agent runs a lean, metrics-only profile (no APM,
logs, process-agent, orchestrator explorer, or cluster agent).

**It is fully optional.** Leave `datadog_api_key` empty (the default) and no
Datadog resources are created — `terraform plan` is identical to the
Prometheus-only setup.

Confirm it after apply:

```
kubectl -n datadog-<workspace> get pods      # the datadog agent pod(s) are Running
```

Then check the metrics land in Datadog (Metrics Explorer → `app_request_success_rate`,
filtered by the `service`/`env` tags). The Agent needs outbound network access to
your Datadog site.

### Optional: Datadog monitors

Also set `datadog_app_key` to have Terraform manage a Datadog monitor mirroring the
`alerting_rules.yml` tiers in `prometheus.tf`. The APP key is a second, independent
gate: the Agent needs only an API key, so with no APP key you still get metrics and
simply no monitors. With neither key the Datadog provider skips credential validation
entirely, so a keyless `terraform plan` stays clean.

`datadog_monitor.app_success_rate` folds `AppSuccessRateLow` and
`AppSuccessRateCritical` into one monitor — Datadog escalates warning → critical
itself, so it needs no equivalent of the PromQL `< 0.95 >= 0.8` band:

```
avg(last_1m):avg:app_request_success_rate{*} by {service,env,kube_deployment} < 0.8
```

with `warning = 0.95`, `critical = 0.8`, and `notify_no_data` after 10m to surface the
`absent`/`down` modes as the first-class Unknown state.

Two deliberate divergences from the PromQL:

- **`last_1m` does double duty.** Datadog has no separate sustain duration, so the
  window covers both `avg_over_time(...[20s])` and `for: 1m`.
- **Grouped by `kube_deployment`, not `tenant`.** Datadog *excludes* any series
  missing a group-by tag, and the app omits `tenant` entirely when unset, so
  `by {service,env,tenant}` would silently monitor only the two tenanted `payments`
  instances. `kube_deployment` is always present and one-per-instance, restoring full
  coverage while keeping tenants apart — its value already encodes the tenant
  (`payments-production-globex`).

The monitor watches `{*}`. If you ever run two workspaces against the same Datadog
account, scope it with the Agent's cluster tag
(`kube_cluster_name:live-status-<workspace>`) so the two don't overlap.

## Accessing the app UIs

Each synthetic-service instance gets a Service + Traefik Ingress at `http://<instance>.localhost`
(e.g. `checkout-production.localhost`, `payments-production-acme.localhost`). Browsers route `*.localhost` to
loopback automatically; for `curl`, add an `/etc/hosts` entry (`127.0.0.1 checkout-production.localhost`).

Reaching Traefik's `:80` entrypoint from the host differs by platform:

- Colima (k3s): Traefik is bundled (LoadBalancer `svc/traefik` in `kube-system`). Colima forwards
  LoadBalancer service ports to the host, so `http://<instance>.localhost` works once the cluster is up. If
  your Colima version doesn't auto-forward, run `kubectl -n kube-system port-forward svc/traefik 80:80`.
- Docker Desktop: its built-in Kubernetes has no ingress controller, so the Ingress won't route on
  its own. Either run the cluster via k3d (bundles Traefik) created with `-p "80:80@loadbalancer"`, or
  install an ingress controller. Docker Desktop publishes LoadBalancer services on `localhost`, so once
  Traefik is running, `http://<instance>.localhost` resolves through it.
- Fallback (any platform, no Ingress needed): port-forward straight to a pod:
  `kubectl -n live-status-production port-forward deploy/checkout-production 8080:8080` → http://localhost:8080.
  Prometheus: `kubectl -n live-status-monitoring port-forward svc/prometheus 9090:9090`.

## Verify the Terraform itself

```
terraform init && terraform validate      # schema-clean
terraform plan                            # once placeholders are filled
```

## Notes

- Provider schemas used here (prompted variable `display_settings`, the container-image `packages` map on
  `octopusdeploy_process_step`, `octopusdeploy_tenant`/`tenant_project`) were verified against the installed
  1.18.0 provider schema.
- The synthetic-service image is built and published to GHCR by `.github/workflows/synthetic-service-image.yml`; this config only references it.
