# live-status

The rig for testing Live Application Status. It builds an Octopus space with Staging and
Production, installs a Kubernetes agent, deploys Prometheus and Alertmanager, and gives you two
projects — `checkout` (untenanted) and `payments` (tenanted) — that deploy a small synthetic app
built to emit metrics on cue.

## Setup

Everything goes in `variables.auto.tfvars`, which is gitignored.

`owner` is required and has no default, deliberately. It's lowercase, and it scopes everything
landing in the shared Datadog org so you don't trip over a teammate's data.

`app_feed_username` and `app_feed_password` are your GitHub username and a *classic* PAT with
`read:packages` — Octopus needs them to list image tags from GHCR, and fine-grained tokens don't
offer that scope. Skip both if the package is public.

`octopus_api_key` defaults to `API-APIKEY01`, which is probably what you want locally.

Then the optional ones. `datadog_api_key` gets you the agent, `datadog_app_key` adds monitors,
and `public_webhook_url` wires up webhooks — that last one has to be reachable from the internet,
so a tunnel. Sumo Logic wants `sumologic_access_id` and `sumologic_access_key`. If you'd rather
skip Prometheus entirely, set `prometheus_enabled = false`.

## Run it

```
terraform init
terraform apply
```

Wait for the `Live Status Agent` target to go healthy in Octopus before you deploy anything.

## The demo

1. Release `payments` to Production for `acme` with Variant set to **Good**, then do the same for
   `checkout`. That's your healthy baseline.
2. Open Prometheus at `http://prometheus-<workspace>.localhost` and run
   `avg by (project, environment) (app_request_success_rate)`. It should sit around 1.0.
3. Cut a new release to Production for `acme`, this time with Variant set to **Bad**. The success
   rate falls below 0.95 after a scrape or two, and alerts turn up at
   `http://alertmanager-<workspace>.localhost`.
4. Release once more with Variant back to **Good**, and watch it recover.

Every app instance has a UI at `http://<project>-<environment>-<tenant>.localhost`. Untenanted
deployments use `untenanted` in that last slot, so `checkout-production-untenanted.localhost`. If
ingress isn't routing for you, port-forward instead:

```
kubectl -n live-status-production port-forward deploy/checkout-production-untenanted 8080:8080
```

## Worth knowing

You can run several `terraform workspace`s against one cluster, but the app namespaces and
ingress hosts aren't workspace-scoped. Deploy apps from two workspaces at once and they'll
collide.

The app image is built and pushed to GHCR by `.github/workflows/synthetic-service-image.yml`.
