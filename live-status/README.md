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
- Prometheus (namespace `live-status-monitoring-<workspace>`), deployed by Terraform via the
  `prometheus-community/prometheus` Helm chart (`prometheus.tf`) — server plus Alertmanager,
  annotation-based pod scraping, Service `prometheus:9090`, and Ingresses at
  `http://prometheus-<workspace>.localhost` and `http://alertmanager-<workspace>.localhost`.
  Comes up at
  `terraform apply` (no Octopus project involved). Migrating a cluster that already has an
  Octopus-deployed Prometheus in this namespace? Delete it first
  (`kubectl delete ns live-status-monitoring-<workspace>`) so Terraform doesn't collide with the
  existing resources.
- checkout (untenanted) and payments (tenanted: `acme`, `globex`) projects →
  `../deployment_processes/synthetic_service_process`: deploy the app. Project name = the `project` label.
  A prompted Variant (Good/Bad) drives `App.ErrorRate`; `Octopus.Release.Number` → the `release`
  label; the image tag is picked from the Docker feed per release. Each instance also gets a Service + a
  Traefik Ingress at `http://<instance>.localhost`.

## Before `terraform apply`: resolve with Eddy

0. **`owner` is required and has no default.** Set it in `live-status/variables.auto.tfvars`:

   ```hcl
   owner = "eddy"   # lowercase, alphanumeric + dashes
   ```

   Everything else in this rig is per-machine and can't collide, but a Datadog org is shared:
   metrics, monitors and webhooks from every teammate land in one namespace. `owner` is the
   discriminator. It has no default deliberately — `terraform plan` fails with "No value for
   required variable" rather than silently adopting someone else's identity.
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

### Multiple workspaces on one cluster

Every cluster-scoped name this config creates carries `terraform.workspace`, so the whole
stack can be stood up several times against the same Colima cluster:

```
terraform workspace new live-status-dev
terraform apply
```

Per workspace you get its own Octopus space, agent namespace, Prometheus namespace
(`live-status-monitoring-<workspace>`), Prometheus `ClusterRole`/`ClusterRoleBinding`
(`prometheus-<workspace>`), Ingress hosts (`prometheus-<workspace>.localhost` and
`alertmanager-<workspace>.localhost`), Datadog namespace, and Datadog monitor.

Two things are *not* workspace-scoped, and will collide if you run app deployments from
more than one workspace at a time:

- **The app namespaces**, `live-status-<environment>` — they come from the Octopus
  deployment process (`../deployment_processes/synthetic_service_process`), which names
  them from the Octopus environment, not the Terraform workspace.
- **The app Ingress hosts**, `<project>-<environment>[-<tenant>].localhost`, for the same
  reason.

Prometheus scrapes by pod annotation across all namespaces, so each workspace's Prometheus
picks up whatever synthetic-service pods exist, whichever workspace deployed them.

1. Prometheus is already up — Terraform deploys it at `terraform apply`. View it at
   `http://prometheus-<workspace>.localhost`, or
   `kubectl -n live-status-monitoring-<workspace> port-forward svc/prometheus 9090:9090`
   → http://localhost:9090 (`terraform output prometheus_ui_hint` prints both for the current
   workspace)
2. Baseline good: release payments, pick the image tag, deploy to Production for `acme` (and
   `globex`) with Variant=Good. Repeat checkout → Production. Confirm pods:
   `kubectl -n live-status-production get pods`.
3. Observe healthy: in Prometheus, `avg by (project, environment) (app_request_success_rate)` ≈ 1.0. Series carry
   `project` / `environment` / `tenant` / `release`.
4. Bad deploy: new release of payments → Production/`acme`, Variant=Bad. The rollout replaces the
   pod (new `release`, error rate 0.10); success rate drops < 0.95 within a scrape or two. That's the
   deployment-correlated regression.
5. Roll forward: new release, Variant=Good → recovers.

## Alerting and the Octopus webhook

`prometheus.tf` defines four rules in the `live-status` group — `AppUpDegraded`,
`AppSuccessRateLow`, `AppSuccessRateCritical` and `AppTargetDown` — and routes all of
them to a single Alertmanager receiver that POSTs to the Octopus test endpoint.

Alertmanager is enabled for this (Prometheus itself only fires alerts internally;
delivering them is Alertmanager's job). Enabling it also auto-wires the server's
`alerting.alertmanagers` discovery, so there's no explicit `server.alertmanagers`.

The receiver uses `webhook_config`'s `payload`, which replaces Alertmanager's own
envelope with a flat body:

```json
{
  "project": "payments",
  "environment": "production",
  "tenant": "globex",
  "status": "firing",
  "alertname": "AppSuccessRateCritical"
}
```

Worth knowing:

- **`payload` needs Alertmanager ≥ v0.31**; the chart pinned here ships v0.33.0.
  Alertmanager performs no validation on the rendered body, so the shape is ours to
  keep correct.
- **No renaming step.** The app emits `project`/`environment`/`tenant` directly, so
  the rules, the `group_by` and the payload all use the same names end to end.
- **`group_by` is load-bearing.** The payload renders once per *group* and reads
  `.GroupLabels`, so grouping by `[alertname, project, environment, tenant]` is what makes each
  call carry a single instance's identity.
- **The URL is `host.lima.internal:8065`, not `localhost`.** Alertmanager posts from
  inside the cluster, where `localhost` is its own container — same address the
  in-cluster agent uses (`local.colima_octopus_address`). It's `http`, not `https`.
- **`AppTargetDown` carries no PET labels** (it's pod-level, off the scrape-level `up`
  series), so it arrives with `project`/`environment`/`tenant` empty. Untenanted
  instances likewise send `tenant: ""` — Alertmanager templates with
  `missingkey=zero`, so a missing label renders empty rather than `<no value>`.
- **No auth header is sent.** If the endpoint needs one, add it under the receiver's
  `http_config`.

Watch it work: drive an instance unhealthy from its control panel (error rate > 0.05), then
check Alertmanager at `http://alertmanager-<workspace>.localhost` (or
`kubectl -n live-status-monitoring-<workspace> port-forward svc/prometheus-alertmanager 9093:9093`).
Alerts need `for: 1m` plus `group_wait` before the first call goes out.

## Optional: mirror metrics to Datadog

The app's metrics (`app_request_success_rate`, `app_requests_total`, latency
histograms, etc.) go to Prometheus by default. To **also** send them to Datadog,
provide a Datadog API key — nothing else changes, and the metrics keep flowing to
Prometheus too.

Add to `live-status/variables.auto.tfvars` (gitignored, so the key stays out of
git):

```hcl
datadog_api_key     = "…"             # a Datadog API key
datadog_app_key     = "…"             # optional; only needed to create monitors (see below)
datadog_site        = "datadoghq.com" # optional; your DD site, e.g. us5.datadoghq.com, datadoghq.eu
public_webhook_url  = "https://….trycloudflare.com"  # optional; shared by Datadog + Sumo Logic
```

On the next `terraform apply`, a Datadog Agent (Helm chart `datadog/datadog`) is
deployed into a `datadog-<workspace>` namespace. It uses Datadog's Prometheus
autodiscovery to scrape the same `prometheus.io/scrape` pods Prometheus already
scrapes, so Datadog collects the same `app_*` metrics (counts, latency, success
rate), tagged by `project` / `environment` / `tenant` / `release`. Datadog's OpenMetrics
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
filtered by the `project`/`environment` tags). The Agent needs outbound network access to
your Datadog site.

### Optional: Datadog monitors

Also set `datadog_app_key` to have Terraform manage Datadog monitors mirroring the
`alerting_rules.yml` tiers in `prometheus.tf`. The APP key is a second, independent
gate: the Agent needs only an API key, so with no APP key you still get metrics and
simply no monitors. With neither key the Datadog provider skips credential validation
entirely, so a keyless `terraform plan` stays clean.

Terraform manages **two** monitors, identical but for their `by {...}` clause. Both fold
`AppSuccessRateLow` and `AppSuccessRateCritical` into a single monitor — Datadog escalates
warning → critical itself, so neither needs an equivalent of the PromQL `< 0.95 >= 0.8`
band:

| Resource | Query | Covers |
|---|---|---|
| `datadog_monitor.app_success_rate` | `avg(last_1m):avg:app_request_success_rate{owner:<owner>} by {project,environment,tenant} < 0.8` | the two tenanted `payments-production` instances |
| `datadog_monitor.app_success_rate_no_tenant` | `… by {project,environment} < 0.8` | all five instances, tenants rolled up |

Both carry `warning = 0.95`, `critical = 0.8`, and `notify_no_data` after 10m to surface
the `absent`/`down` modes as the first-class Unknown state, and each is tagged
`grouping:…` so you can tell them apart in Datadog.

**Why a pair.** Datadog *excludes* any series missing a group-by tag, and the app omits
`tenant` entirely when unset, so the tenant-grouped monitor covers only
`payments-production-acme` and `payments-production-globex` — `checkout-production`,
`checkout-staging` and `payments-staging` produce no group and drop out silently. No
error; they simply aren't monitored. (Prometheus does *not* behave this way: it keeps
those series with an empty `tenant`, so the PromQL rules cover all five from one rule.)
Rather than work around the exclusion, the second monitor groups one dimension shallower
on tags that are always present. Between the pair, every instance is monitored and the
receiver sees both payload shapes — a body with a real `tenant` and a body without.

Two deliberate divergences from the PromQL:

- **`last_1m` does double duty.** Datadog has no separate sustain duration, so the
  window covers both `avg_over_time(...[20s])` and `for: 1m`.
- **The no-tenant monitor dilutes per-tenant regressions.** Rolling tenants up means a
  bad tenant is averaged with its healthy siblings: `payments-production` at `acme=1.0` /
  `globex=0.90` averages `0.95`, landing on the warning boundary rather than tripping
  critical, where the tenant-grouped monitor sees `globex` at `0.90` directly. `avg:` is
  kept so the pair differs only in `by {...}`; swap the no-tenant one to `min:` (the
  worst-of fold the README's example PromQL uses) if masking matters more than symmetry.

The other route to covering the untenanted three from a single monitor would be grouping on
`kube_deployment` (always present, one per instance, and its value already encodes the
tenant — `payments-production-globex`), or having the app emit an explicit placeholder
tenant.

### Sharing a Datadog org with teammates

A Datadog org is one namespace for everyone, so `var.owner` scopes four things:

| | Value |
|---|---|
| Agent global tag | `owner:<owner>` on every metric shipped (`datadog.tags`) |
| Monitor query | `{owner:<owner>}` rather than `{*}` |
| Monitor name + tags | `[live-status <owner>/<workspace>] …`, `owner:<owner>` |
| Webhook names | `octopus-live-status-health-<owner>-<workspace>` and `…-no-tenant` |
| Cluster name | `live-status-<owner>-<workspace>` |

The query scope is the one that matters most. Every teammate's Agent ships
`app_request_success_rate` with identical `project`/`environment`/`tenant` tags, so an
unscoped `{*}` monitor alerts on *everyone's* pods. Renaming monitors doesn't fix that —
the data needs the discriminator.

The webhook name is the sharpest. `@webhook-<name>` is an org-wide addressing key, and
each teammate's tunnel URL is different, so two people sharing a name would silently
repoint each other's alerts. Separate Terraform states mean neither sees drift.

Two caveats: the `owner` tag only lands on metrics ingested *after* the Agent restarts,
so there's a window where older series are unscoped and won't match the monitor. And
`source:local-test` (set by the app itself) separates synthetic from real data, not one
person's from another's.

If you don't need Datadog at all, leave `datadog_api_key` empty — the Prometheus and
Alertmanager path is entirely local and has no shared surface to collide on.

### Datadog webhook

`datadog_webhook.health_events` and `datadog_webhook.health_events_no_tenant` POST every
health event to `var.public_webhook_url`, which is **empty by default** — a committed URL
would point every teammate's alerts at one person's tunnel. It's a third gate on top of the
APP key: blank the URL and neither webhook is created.

The variable is deliberately provider-neutral: Sumo Logic's monitors call the same endpoint
with the same body, so both providers read one URL. It was named `datadog_webhook_url` until
Sumo Logic arrived; the old name is still declared and now *rejects* any non-empty value, so
a stale entry in `variables.auto.tfvars` fails the plan instead of being silently ignored.

**One webhook per monitor, both pointing at the same URL.** They are identical but for the
constant `alertname` they emit (`AppSuccessRate` vs `AppSuccessRateNoTenant`). Payload
templates have no branching and nothing in the body reveals the monitor's grouping, so a
webhook each is the only way the receiver can tell a tenant-grouped event from a
project/environment-grouped one.

Unlike the Alertmanager webhook, **Datadog calls from its own servers**, so this URL
has to be publicly reachable; `host.lima.internal` or `localhost` won't do.

Each monitor references its own handle as `@webhook-<name>` placed *outside* every
`{{#is_*}}` block — a handle nested inside one only fires for that state, whereas at the top
level it fires on every transition the monitor notifies about: triggered, warning, recovery,
and no data. Both webhook names carry the owner and workspace because Datadog webhooks are
org-global.

The payload deliberately mirrors the Alertmanager webhook's flat shape, so one endpoint
can handle both. `$TAGS[key]` pulls a single tag out by name (it yields an empty string
when the tag is absent):

```json
{
  "alertname": "AppSuccessRate",
  "environment": "staging",
  "project": "checkout",
  "status": "Triggered",
  "tenant": ""
}
```

The example above is a no-tenant-monitor body; the tenant-grouped monitor sends the same
five keys with `"alertname": "AppSuccessRate"` and a populated `"tenant"`.

**Three fields can't match the Alertmanager body exactly**, and the gaps are structural
rather than oversights:

| Field | Alertmanager | Datadog | Why |
|---|---|---|---|
| `status` | `firing` / `resolved` | `Triggered` / `Warn` / `Recovered` / `No Data` / `Renotify` | Datadog's own vocabulary. Payload templates have no branching, so any mapping has to live in the receiver. |
| `tenant` | the tag, or absent | the tag from the tenant-grouped monitor; always `""` from the no-tenant one | `$TAGS[tenant]` resolves only when `tenant` is a group tag. The key is kept in both bodies (rendering `""`) rather than dropped, since a payload template can't emit a JSON `null`. |
| `alertname` | per-rule (`AppSuccessRateCritical` vs `…Low`) | per-monitor (`AppSuccessRate` vs `AppSuccessRateNoTenant`), not per-tier | Each Datadog monitor spans both tiers via `warning`/`critical` thresholds, so the name distinguishes the *grouping*, not the severity. |

If exact parity matters more than the current shape:

- **`alertname` per tier** — split each monitor into a warning and a critical one (four
  monitors, four webhooks). Note Datadog can't express the PromQL `< 0.95 >= 0.8` exclusive
  band in `monitor_thresholds`, so both tiers would fire below 0.8 unless the queries are
  reworked.
- **`tenant` populated on every event** — the tenant-grouped monitor already does this for
  the instances that have one. For the untenanted three, the options are grouping on
  `kube_deployment` (whose value encodes the tenant — `payments-production-globex`), having
  the receiver parse it out of that name, or having the app emit a placeholder tenant.
- **`status` vocabulary** — map `Recovered → resolved`, everything else `→ firing`, in the
  receiver.

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
  Prometheus: `kubectl -n live-status-monitoring-<workspace> port-forward svc/prometheus 9090:9090`.

## Verify the Terraform itself

```
terraform init && terraform validate      # schema-clean
terraform plan                            # once placeholders are filled
```

Both optional backends are gated so a credential-free plan stays clean, by different
means. The Datadog provider is told not to authenticate (`validate =
local.datadog_monitors_enabled`), because it would otherwise fail at configure time even
with every resource using it at `count = 0`. The Sumo Logic provider has no such flag and
takes its credentials unconditionally, but tolerates empty ones: with no Sumo access pair,
`terraform plan` succeeds and creates nothing.

Note that `terraform validate` does **not** evaluate variable values, so variable
`validation` blocks only fire on `plan`/`apply`. A config that validates clean can still
fail the plan on a bad or renamed variable.

## Notes

- Provider schemas used here (prompted variable `display_settings`, the container-image `packages` map on
  `octopusdeploy_process_step`, `octopusdeploy_tenant`/`tenant_project`) were verified against the installed
  1.18.0 provider schema.
- The synthetic-service image is built and published to GHCR by `.github/workflows/synthetic-service-image.yml`; this config only references it.
