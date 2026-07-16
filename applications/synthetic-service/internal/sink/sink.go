// Package sink defines the fan-out seam between the workload generator and the
// metric/telemetry backends.
//
// The generator emits one RequestObservation per simulated request; every
// registered Sink receives it. Only the Prometheus sink is implemented today
// (see prometheus.go). Datadog/Loki placeholders in stubs.go show exactly where
// a future backend plugs in without touching the generator.
package sink

// RequestObservation is a single simulated request's outcome. It is the unit of
// data that flows from the generator to every sink.
type RequestObservation struct {
	Success   bool
	LatencyMs float64
}

// Sink consumes RequestObservations. Implementations must be safe for
// concurrent use: Observe runs on the generator goroutine while a metrics
// scrape may read the same underlying state.
type Sink interface {
	// Name identifies the sink in logs and diagnostics.
	Name() string
	// Observe records one simulated request. Called once per request.
	Observe(RequestObservation)
}

// Observer is the write side the generator depends on. Registry satisfies it,
// so the generator never needs to know about individual sinks.
type Observer interface {
	Observe(RequestObservation)
}

// Registry is an ordered set of Sinks that fans out each observation to all of
// them. It implements Observer. Registration happens at startup (single
// goroutine) before the generator begins calling Observe.
type Registry struct {
	sinks []Sink
}

// NewRegistry builds a Registry seeded with the given sinks.
func NewRegistry(sinks ...Sink) *Registry {
	return &Registry{sinks: append([]Sink(nil), sinks...)}
}

// Add registers an additional sink. Call before the generator starts.
func (r *Registry) Add(s Sink) { r.sinks = append(r.sinks, s) }

// Sinks returns the registered sinks in registration order.
func (r *Registry) Sinks() []Sink { return r.sinks }

// Observe fans the observation out to every registered sink, in order.
func (r *Registry) Observe(obs RequestObservation) {
	for _, s := range r.sinks {
		s.Observe(obs)
	}
}
