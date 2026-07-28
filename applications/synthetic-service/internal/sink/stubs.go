package sink

// This file is the seam for future telemetry backends. Nothing here is
// implemented or registered; it exists so the shape of "add another sink" is
// obvious and doesn't require touching the generator or PrometheusSink.
//
// To wire a real backend once one of these is implemented, register it
// alongside the Prometheus sink in cmd/synthetic-service/main.go:
//
//	reg := sink.NewRegistry(promSink)
//	reg.Add(NewDatadogSink(...))
//	reg.Add(NewLokiSink(...))
//
// DatadogSink would push RequestObservations to a StatsD/DogStatsD agent
// (e.g. via github.com/DataDog/datadog-go/statsd) instead of serving a pull
// scrape: counters via Count/Incr, latency via Histogram or Timing, tagged
// with the same PET identity (project/environment/tenant/release) carried as
// constant labels on the Prometheus collectors.
//
// type DatadogSink struct {
// 	// client   *statsd.Client
// 	// id       config.Identity
// 	// cfg      *config.Config
// }
//
// func NewDatadogSink(id config.Identity, cfg *config.Config /*, addr string */) *DatadogSink {
// 	return &DatadogSink{}
// }
//
// func (d *DatadogSink) Name() string { return "datadog" }
//
// func (d *DatadogSink) Observe(obs RequestObservation) {
// 	// d.client.Incr("app.requests_total", tagsFor(d.id, obs), 1)
// 	// d.client.Histogram("app.request_duration_seconds", obs.LatencyMs/1000, tagsFor(d.id, obs), 1)
// }

// LokiSink would push a structured log line per observation to a Loki push
// endpoint (e.g. via github.com/grafana/loki-client-go/loki), carrying the
// PET identity as stream labels and success/latency as line fields. This
// reproduces log-based health signals distinct from the metrics path above.
//
// type LokiSink struct {
// 	// client   *loki.Client
// 	// id       config.Identity
// }
//
// func NewLokiSink(id config.Identity /*, pushURL string */) *LokiSink {
// 	return &LokiSink{}
// }
//
// func (l *LokiSink) Name() string { return "loki" }
//
// func (l *LokiSink) Observe(obs RequestObservation) {
// 	// l.client.Handle(model.LabelSet{"service": model.LabelValue(l.id.Service), ...}, time.Now(), line)
// }
