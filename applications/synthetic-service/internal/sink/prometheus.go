package sink

import (
	"net/http"
	"sync"
	"time"

	"github.com/OctopusDeploy/synthetic-service/internal/config"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	dto "github.com/prometheus/client_model/go"
)

// workloadMetricNames are the app_* series dropped from the scrape in
// config.ModeAbsent. app_up and app_build_info are kept so the app still looks
// "present" but reports no workload for this PET, reproducing the empty-result
// -> Unknown path.
var workloadMetricNames = map[string]bool{
	"app_requests_total":           true,
	"app_request_duration_seconds": true,
	"app_request_success_rate":     true,
}

// SourceLabelValue is stamped onto every series this app emits, as the
// constant `source` label. Nothing this service produces is real traffic, so
// the marker is fixed rather than configurable: any scrape carrying it is a
// local synthetic test instance and must never be read as a real application's
// health.
const SourceLabelValue = "local-test"

// PrometheusSink is the only real sink today: it maintains a private
// prometheus.Registry (deliberately not the global DefaultRegisterer, so the
// scrape surface is exactly the app_* metrics below, with no go_*/process_*
// noise) and a rolling-window success-rate tracker consulted by both the
// success-rate gauge and the /api/state endpoint.
type PrometheusSink struct {
	cfg *config.Config

	registry *prometheus.Registry

	requestsTotal   *prometheus.CounterVec
	requestDuration prometheus.Histogram
	successRate     prometheus.Gauge
	up              prometheus.Gauge
	buildInfo       prometheus.Gauge

	window *successWindow
}

// NewPrometheusSink builds the private registry and registers the fixed set
// of app_* collectors with the PET identity applied as constant labels
// (tenant omitted entirely when id.Tenant is empty), plus the fixed source
// marker identifying the series as synthetic.
func NewPrometheusSink(id config.Identity, cfg *config.Config) *PrometheusSink {
	constLabels := prometheus.Labels{
		"service": id.Service,
		"env":     id.Env,
		"release": id.Release,
		"source":  SourceLabelValue,
	}
	if id.Tenant != "" {
		constLabels["tenant"] = id.Tenant
	}

	p := &PrometheusSink{
		cfg:      cfg,
		registry: prometheus.NewRegistry(),
		requestsTotal: prometheus.NewCounterVec(prometheus.CounterOpts{
			Name:        "app_requests_total",
			Help:        "Total simulated requests handled, by outcome.",
			ConstLabels: constLabels,
		}, []string{"status"}),
		requestDuration: prometheus.NewHistogram(prometheus.HistogramOpts{
			Name:        "app_request_duration_seconds",
			Help:        "Simulated request duration in seconds.",
			ConstLabels: constLabels,
			Buckets:     []float64{.005, .01, .025, .05, .1, .25, .5, 1, 2},
		}),
		successRate: prometheus.NewGauge(prometheus.GaugeOpts{
			Name:        "app_request_success_rate",
			Help:        "Rolling-window fraction of requests that succeeded, in [0,1].",
			ConstLabels: constLabels,
		}),
		up: prometheus.NewGauge(prometheus.GaugeOpts{
			Name:        "app_up",
			Help:        "Self-reported liveness; 1 once the app has started.",
			ConstLabels: constLabels,
		}),
		buildInfo: prometheus.NewGauge(prometheus.GaugeOpts{
			Name:        "app_build_info",
			Help:        "Constant 1; release is carried as a constant label (see constLabels) for version tracking.",
			ConstLabels: constLabels,
		}),
		window: newSuccessWindow(),
	}

	p.registry.MustRegister(p.requestsTotal, p.requestDuration, p.successRate, p.up, p.buildInfo)

	p.up.Set(1)
	p.buildInfo.Set(1)

	return p
}

// Name identifies this sink in logs and diagnostics.
func (p *PrometheusSink) Name() string { return "prometheus" }

// Observe records one simulated request: increments the counter, observes
// the latency histogram, and feeds the rolling success-rate window.
func (p *PrometheusSink) Observe(obs RequestObservation) {
	status := "error"
	if obs.Success {
		status = "success"
	}
	p.requestsTotal.WithLabelValues(status).Inc()
	p.requestDuration.Observe(obs.LatencyMs / 1000)

	windowSeconds := p.cfg.Settings().SuccessWindowSeconds
	rate := p.window.record(time.Now(), obs.Success, windowSeconds)
	p.successRate.Set(rate)
}

// ObservedSuccessRate returns the current rolling-window success rate in
// [0,1], the same value last set on the app_request_success_rate gauge.
func (p *PrometheusSink) ObservedSuccessRate() float64 {
	return p.window.rate(time.Now(), p.cfg.Settings().SuccessWindowSeconds)
}

// Handler returns the promhttp handler for this sink's private registry. In
// config.ModeAbsent the gatherer drops the app_* workload series (but keeps
// app_up/app_build_info), reproducing a scrape that succeeds but returns no
// row for this PET.
func (p *PrometheusSink) Handler() http.Handler {
	return promhttp.HandlerFor(p.filteredGatherer(), promhttp.HandlerOpts{})
}

func (p *PrometheusSink) filteredGatherer() prometheus.Gatherer {
	return gathererFunc(func() ([]*dto.MetricFamily, error) {
		families, err := p.registry.Gather()
		if err != nil {
			return nil, err
		}
		if p.cfg.Settings().Mode != config.ModeAbsent {
			return families, nil
		}
		kept := families[:0]
		for _, fam := range families {
			if workloadMetricNames[fam.GetName()] {
				continue
			}
			kept = append(kept, fam)
		}
		return kept, nil
	})
}

// gathererFunc adapts a plain function to prometheus.Gatherer.
type gathererFunc func() ([]*dto.MetricFamily, error)

func (f gathererFunc) Gather() ([]*dto.MetricFamily, error) { return f() }

// successWindow tracks per-second success/total counts over a rolling
// window, guarded by a mutex since Observe (generator goroutine) and
// ObservedSuccessRate/Gather (HTTP goroutine) run concurrently.
type successWindow struct {
	mu      sync.Mutex
	buckets map[int64]*windowBucket
}

type windowBucket struct {
	successes int
	total     int
}

func newSuccessWindow() *successWindow {
	return &successWindow{buckets: make(map[int64]*windowBucket)}
}

// record adds one observation at time now and returns the resulting windowed
// rate for the given window length in seconds.
func (w *successWindow) record(now time.Time, success bool, windowSeconds int) float64 {
	sec := now.Unix()

	w.mu.Lock()
	defer w.mu.Unlock()

	b, ok := w.buckets[sec]
	if !ok {
		b = &windowBucket{}
		w.buckets[sec] = b
	}
	b.total++
	if success {
		b.successes++
	}

	return w.rateLocked(sec, windowSeconds)
}

// rate returns the current windowed success rate as of now, without
// recording a new observation.
func (w *successWindow) rate(now time.Time, windowSeconds int) float64 {
	w.mu.Lock()
	defer w.mu.Unlock()
	return w.rateLocked(now.Unix(), windowSeconds)
}

// rateLocked computes the windowed rate and prunes buckets that have aged
// out of the window. Callers must hold w.mu.
func (w *successWindow) rateLocked(nowSec int64, windowSeconds int) float64 {
	oldest := nowSec - int64(windowSeconds) + 1

	var successes, total int
	for sec, b := range w.buckets {
		if sec < oldest {
			delete(w.buckets, sec)
			continue
		}
		successes += b.successes
		total += b.total
	}

	if total == 0 {
		return 1.0
	}
	return float64(successes) / float64(total)
}
