package sink

import (
	"math"
	"testing"
	"time"

	"github.com/OctopusDeploy/synthetic-service/internal/config"
	"github.com/prometheus/client_golang/prometheus"
)

const windowSeconds = 60

var base = time.Date(2024, 1, 1, 0, 0, 0, 0, time.UTC)

func almostEqual(a, b float64) bool {
	return math.Abs(a-b) < 1e-9
}

func TestSuccessWindow_EmptyWindowIsFullySuccessful(t *testing.T) {
	w := newSuccessWindow()

	got := w.rate(base, windowSeconds)

	if got != 1.0 {
		t.Fatalf("empty window rate = %v, want 1.0", got)
	}
}

func TestSuccessWindow_AllSuccessIsOne(t *testing.T) {
	w := newSuccessWindow()

	for i := 0; i < 10; i++ {
		w.record(base.Add(time.Duration(i)*time.Second), true, windowSeconds)
	}

	got := w.rate(base.Add(9*time.Second), windowSeconds)

	if got != 1.0 {
		t.Fatalf("all-success rate = %v, want 1.0", got)
	}
}

func TestSuccessWindow_MixedRate(t *testing.T) {
	w := newSuccessWindow()

	for i := 0; i < 97; i++ {
		w.record(base, true, windowSeconds)
	}
	for i := 0; i < 3; i++ {
		w.record(base, false, windowSeconds)
	}

	got := w.rate(base, windowSeconds)

	if !almostEqual(got, 0.97) {
		t.Fatalf("mixed rate = %v, want ~0.97", got)
	}
}

func TestSuccessWindow_ExcludesObservationsOlderThanWindow(t *testing.T) {
	w := newSuccessWindow()

	// All failures, far in the past: outside the window once we advance now.
	for i := 0; i < 100; i++ {
		w.record(base, false, windowSeconds)
	}

	// All successes, recorded windowSeconds+ later than the failures above.
	later := base.Add(time.Duration(windowSeconds+30) * time.Second)
	for i := 0; i < 5; i++ {
		w.record(later, true, windowSeconds)
	}

	got := w.rate(later, windowSeconds)

	if got != 1.0 {
		t.Fatalf("rate after old failures aged out = %v, want 1.0 (stale failures should be excluded)", got)
	}
}

func TestSuccessWindow_BoundaryIsInclusiveOfWindowStart(t *testing.T) {
	w := newSuccessWindow()

	w.record(base, false, windowSeconds)

	// Exactly windowSeconds-1 later: the base second is still the oldest
	// second inside an inclusive [now-window+1, now] range.
	stillInWindow := base.Add(time.Duration(windowSeconds-1) * time.Second)
	got := w.rate(stillInWindow, windowSeconds)
	if got != 0.0 {
		t.Fatalf("rate at window boundary = %v, want 0.0 (failure still in window)", got)
	}

	// One second further: the base second has now aged out.
	justOutside := base.Add(time.Duration(windowSeconds) * time.Second)
	got = w.rate(justOutside, windowSeconds)
	if got != 1.0 {
		t.Fatalf("rate just past window boundary = %v, want 1.0 (failure aged out)", got)
	}
}

// gatheredFamilyNames gathers from g and returns the set of metric-family names.
func gatheredFamilyNames(t *testing.T, g prometheus.Gatherer) map[string]bool {
	t.Helper()
	fams, err := g.Gather()
	if err != nil {
		t.Fatalf("gather: %v", err)
	}
	names := make(map[string]bool, len(fams))
	for _, f := range fams {
		names[f.GetName()] = true
	}
	return names
}

// TestNewPrometheusSink_ConstructsWithTenantAndRelease is a regression test:
// app_build_info once declared release as a variable label while release was
// also a constant label on every metric, which made MustRegister panic at
// startup whenever the release/tenant identity was set. Constructing the sink
// and exposing the full family set must not panic.
func TestNewPrometheusSink_ConstructsWithTenantAndRelease(t *testing.T) {
	cfg := config.Load()
	id := config.Identity{Service: "checkout", Env: "production", Tenant: "acme", Release: "1.4.2"}

	p := NewPrometheusSink(id, cfg) // must not panic
	p.Observe(RequestObservation{Success: true, LatencyMs: 50})
	p.Observe(RequestObservation{Success: false, LatencyMs: 120})

	names := gatheredFamilyNames(t, p.registry)
	for _, want := range []string{
		"app_requests_total",
		"app_request_duration_seconds",
		"app_request_success_rate",
		"app_up",
		"app_build_info",
	} {
		if !names[want] {
			t.Errorf("missing metric family %q", want)
		}
	}
}

// TestNewPrometheusSink_OmitsTenantWhenEmpty verifies the PET contract that the
// tenant label is omitted entirely (not emitted as tenant="") when unset.
func TestNewPrometheusSink_OmitsTenantWhenEmpty(t *testing.T) {
	cfg := config.Load()
	id := config.Identity{Service: "checkout", Env: "staging", Release: "2.0.0"} // no tenant

	p := NewPrometheusSink(id, cfg)
	p.Observe(RequestObservation{Success: true, LatencyMs: 50})

	fams, err := p.registry.Gather()
	if err != nil {
		t.Fatalf("gather: %v", err)
	}
	for _, f := range fams {
		for _, m := range f.GetMetric() {
			for _, lp := range m.GetLabel() {
				if lp.GetName() == "tenant" {
					t.Errorf("metric %q carries a tenant label (%q) but tenant was unset", f.GetName(), lp.GetValue())
				}
			}
		}
	}
}

// TestPrometheusSink_AbsentModeDropsWorkloadSeries verifies the absent-mode
// gatherer keeps only app_up/app_build_info (the empty-result -> Unknown path).
func TestPrometheusSink_AbsentModeDropsWorkloadSeries(t *testing.T) {
	cfg := config.Load()
	absent := config.ModeAbsent
	cfg.Apply(config.SettingsPatch{Mode: &absent})

	id := config.Identity{Service: "payments", Env: "staging", Release: "1.0.0"}
	p := NewPrometheusSink(id, cfg)
	p.Observe(RequestObservation{Success: true, LatencyMs: 50})

	names := gatheredFamilyNames(t, p.filteredGatherer())

	for _, dropped := range []string{"app_requests_total", "app_request_duration_seconds", "app_request_success_rate"} {
		if names[dropped] {
			t.Errorf("absent mode still exposes workload series %q", dropped)
		}
	}
	for _, kept := range []string{"app_up", "app_build_info"} {
		if !names[kept] {
			t.Errorf("absent mode dropped %q, which must stay present", kept)
		}
	}
}
