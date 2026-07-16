# Synthetic Service

Octopus Deploy is building "Live Application Status" to surface live application health in the context of a deployment. This synthetic service is a fake app for locally exercising the first connector, which polls Prometheus using PromQL Model A: it queries a scalar per application instance and thresholds it.

Health attaches to an application instance via a Project/Environment/Tenant tuple ("PET"). The synthetic service provides fake Go apps that emit realistic Prometheus metrics (labelled by PET), plus a docker-compose stack running Prometheus that scrapes several instances. You can point the real connector (or ad-hoc PromQL) at `localhost:9090` and see a full matrix of Healthy/Degraded/Unhealthy/Unknown instances.

## Quickstart

Prerequisites: Docker (+ compose). Go 1.25+ only needed for `go test`.

```bash
docker compose up --build
```

This brings up Prometheus + 5 fake-app containers (one PET each). Wait ~15s for the ramp-up.

## URLs

| Service | URL |
|---------|-----|
| Prometheus UI | http://localhost:9090 |
| checkout-prod control panel | http://localhost:8081 |
| checkout-staging control panel | http://localhost:8082 |
| payments-prod-acme control panel | http://localhost:8083 |
| payments-prod-globex control panel | http://localhost:8084 |
| payments-staging control panel | http://localhost:8085 |

Each app's control panel shows identity + live-editable knobs for error rate and mode.

## Health Matrix

The default stack demonstrates all health states:

| Service (compose) | service | env | tenant | error_rate / mode | Host port | Demonstrates |
|---|---|---|---|---|---|---|
| checkout-prod | checkout | production | — | 0.002 | 8081 | Healthy (≥0.99) |
| checkout-staging | checkout | staging | — | 0.03 | 8082 | Degraded (0.95–0.99) |
| payments-prod-acme | payments | production | acme | 0.002 | 8083 | Healthy + tenant dimension |
| payments-prod-globex | payments | production | globex | 0.10 | 8084 | Unhealthy (<0.95) |
| payments-staging | payments | staging | — | mode=absent | 8085 | Unknown (empty result) |

## Health Model & States

The primary metric (Model A) is `app_request_success_rate`, a gauge in [0,1]. The connector thresholds it as follows:

- **Healthy:** ≥ 0.99
- **Degraded:** 0.95–0.99
- **Unhealthy:** < 0.95
- **Unknown:** no data (distinct from Unhealthy)

Unknown is first-class and reproducible two ways:

1. **absent**: the app still serves `/metrics` but omits its `app_*` series, so a grouped query returns no row for that PET (empty result → Unknown).
2. **down**: `/metrics` returns HTTP 503, so Prometheus records `up=0` and series go stale after the lookback window (default 5m).

## PET → Prometheus Labels

Every app metric carries:

- `service` → Project
- `env` → Environment
- `tenant` → Tenant (optional; omitted entirely when unset)
- `release` → Release / version

## Metric Surface

- `app_requests_total`: counter, label `status="success"|"error"`
- `app_request_duration_seconds`: histogram (for `histogram_quantile`)
- `app_request_success_rate`: gauge [0,1] over a rolling window
- `app_up`: gauge 0/1
- `app_build_info{release=…}`: gauge 1, version carrier

## Load Generation

Each 100ms tick the generator dispatches a request count derived from `APP_MAX_RPS`, carrying the fractional remainder forward so throughput matches the target over time. Requests run concurrently, each on its own goroutine, so per-request latency never serialises throughput: the observed rate tracks `APP_MAX_RPS` regardless of how high latency goes. Concurrency is bounded by `APP_MAX_INFLIGHT`.

Successful requests log at `debug` and errors at `error`, so at the default `info` level you'll see only error lines. Confirm the generated rate with the counter: `rate(app_requests_total[1m])` ≈ `APP_MAX_RPS`.

## Environment Variables

| Env var | Default | Meaning |
|---|---|---|
| `APP_PROJECT` | checkout | → `service` label |
| `APP_ENVIRONMENT` | production | → `env` label |
| `APP_TENANT` | (unset) | → `tenant` label; omitted when empty |
| `APP_RELEASE` | 1.0.0 | → `release` label |
| `APP_MAX_RPS` | 50 | target request rate at full ramp |
| `APP_RAMP_SECONDS` | 10 | linear ramp 0→max on startup / ramp-restart |
| `APP_ERROR_RATE` | 0.005 | fraction of simulated requests that fail [0,1] |
| `APP_LATENCY_MEAN_MS` | 80 | mean synthetic latency |
| `APP_LATENCY_JITTER_MS` | 40 | +/- jitter |
| `APP_MODE` | normal | `normal` \| `absent` (omit app_* metrics) \| `down` (503 on /metrics) |
| `APP_SUCCESS_WINDOW_SECONDS` | 60 | rolling window for the success-rate gauge |
| `APP_LOG_LEVEL` | info | `debug` \| `info` \| `warn` \| `error` |
| `APP_HTTP_ADDR` | :8080 | listen address |
| `APP_MAX_INFLIGHT` | 4096 | ceiling on concurrently in-flight simulated requests |

## HTTP Endpoints

Each app exposes:

- `GET /`: web control panel (offline, no CDN)
- `GET /metrics`: Prometheus exposition format
- `GET /api/state`: JSON config + derived state (effective_rps, observed_success_rate, mode)
- `POST /api/state`: partial config update
- `POST /api/ramp/restart`: restart the ramp
- `GET /healthz`: liveness check

## Driving Each Health State

You can control health states in two ways:

1. Via `docker-compose.yml`: set environment variables before startup. Restart containers to apply changes.
2. Via the web control panel: visit each app's host port (8081–8085) to live-edit `error_rate` and `mode` without restarting.

To reach specific states:

- **Degraded:** Set `error_rate` between 0.01 and 0.05
- **Unhealthy:** Set `error_rate` > 0.05
- **Unknown (absent):** Set `mode=absent`
- **Unknown (down):** Set `mode=down`

After a change, watch the value move in Prometheus within a scrape or two (5s scrape interval).

## Example PromQL Queries

```promql
# Model-A primary, per instance (connector thresholds: ≥0.99 Healthy, ≥0.95 Degraded)
app_request_success_rate

# Batched multi-application query, one row per PET (the anti-fan-out pattern)
avg by (service, env) (app_request_success_rate)
min by (service, env) (app_request_success_rate)          # worst-of fold
avg by (service, env, tenant) (app_request_success_rate)  # include tenant dimension

# Error ratio from counters (exercises rate())
sum by (service,env)(rate(app_requests_total{status="error"}[1m]))
  / sum by (service,env)(rate(app_requests_total[1m]))

# p99 latency (exercises histogram_quantile)
histogram_quantile(0.99, sum by (le,service,env)(rate(app_request_duration_seconds_bucket[1m])))

# Liveness
up{job="synthetic-service"}
```

## Release Label Caveat

> Release is emitted as a `release` label because real apps carry a version label and it was requested. But in the real design, release is not a PET scope dimension: version is correlated by joining Octopus's own deployment records, not by scoping health on the release label. Do not scope health queries by release.

## How to Add a New Collector/Backend

The app has a pluggable sink seam. `internal/sink/sink.go` defines:

- `Sink` interface (Name/Observe)
- `RequestObservation` type

The generator fans every simulated request out to all registered sinks via a `Registry`. Currently, only the Prometheus sink (`internal/sink/prometheus.go`) is implemented.

To add a new backend (e.g., Datadog, Loki):

1. Implement the `Sink` interface in a new file
2. Register it in `cmd/synthetic-service/main.go` via `reg.Add(...)`
3. Inert commented skeletons live in `internal/sink/stubs.go` as reference

Logging goes through `internal/logging`, whose handler is a fan-out seam a future log-shipping sink could subscribe to.

## Testing & Development

```bash
go vet ./... && go test ./...
```

Builds and runs unit tests (ramp function + rolling-window success-rate math). Requires Go 1.25+.

The multi-stage Dockerfile means Docker is the only prerequisite to run the full stack.

## Publishing

The image is published to `ghcr.io/eddymoulton/synthetic-service` by
`.github/workflows/synthetic-service-image.yml` on push to `main` (path-filtered to this
directory) and via manual dispatch. It is built multi-arch (`linux/amd64,linux/arm64`, so it
runs on the arm64 Colima/Lima cluster) and tagged `0.1.<run_number>`, `sha-<short>`, and
`latest`. Pull requests run `go vet`/`go test` without publishing.

## Repository Layout

```
.
├── cmd/
│   └── synthetic-service/
│       └── main.go              # app entry point
├── internal/
│   ├── config/
│   ├── generator/               # request simulation
│   ├── httpapi/
│   │   ├── server.go            # HTTP handlers
│   │   └── ui/
│   │       └── index.html       # control panel UI
│   ├── logging/
│   └── sink/
│       ├── sink.go
│       ├── prometheus.go
│       └── stubs.go             # example skeletons
├── Dockerfile
├── docker-compose.yml
├── prometheus/
│   └── prometheus.yml
└── README.md
```
