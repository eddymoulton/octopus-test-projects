package generator

import (
	"context"
	"io"
	"log/slog"
	"sync/atomic"
	"testing"
	"time"

	"github.com/OctopusDeploy/synthetic-service/internal/config"
	"github.com/OctopusDeploy/synthetic-service/internal/sink"
)

// countingObserver counts observations across all dispatch goroutines.
type countingObserver struct{ n atomic.Int64 }

func (c *countingObserver) Observe(sink.RequestObservation) { c.n.Add(1) }

// TestConcurrentDispatchTracksMaxRPS verifies that per-request latency does not
// throttle throughput. Each request occupies 150ms; a serial dispatcher would
// manage only one tick's worth of requests before ctx expires, whereas
// concurrent dispatch processes every tick and the observed count tracks MaxRPS.
//
// The test drives the tick source directly (via the unexported tickC field)
// rather than let Run create a real 100ms ticker: a real ticker's channel
// buffers one tick, so a loaded CI runner can coalesce or drop ticks, making the
// count depend on scheduling rather than generator behaviour. Feeding ticks
// ourselves makes the dispatched count an exact function of the ticks we send.
// With APP_RAMP_SECONDS=0 the ramp completes instantly, so effective RPS is
// exactly MaxRPS (100) every tick; at a 100ms cadence that's exactly 10
// requests/tick with no fractional carry (100 * 0.1 == 10.0). Ten ticks dispatch
// exactly 100 requests when dispatch is concurrent, and fewer if it regresses to
// serializing on per-request latency.
func TestConcurrentDispatchTracksMaxRPS(t *testing.T) {
	t.Setenv("APP_MAX_RPS", "100")
	t.Setenv("APP_RAMP_SECONDS", "0")
	t.Setenv("APP_LATENCY_MEAN_MS", "150")
	t.Setenv("APP_LATENCY_JITTER_MS", "0")
	t.Setenv("APP_ERROR_RATE", "0")
	cfg := config.Load()

	obs := &countingObserver{}
	logger := slog.New(slog.NewTextHandler(io.Discard, nil))
	g := New(cfg, obs, logger)

	// Inject a deterministic tick source: the test controls exactly when each
	// tick fires instead of racing a real ticker against a timeout.
	tickC := make(chan time.Time)
	g.tickC = tickC

	// Generous relative to the microseconds concurrent dispatch needs to consume
	// 10 ticks, but far shorter than the ~1.5s ten ticks would take if dispatch
	// regressed to serial (10 requests/tick * 150ms each, serialized within
	// tick()'s loop), so this stays a meaningful bound rather than a rubber stamp.
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()

	done := make(chan struct{})
	go func() {
		defer close(done)
		g.Run(ctx) // returns after ctx expires and in-flight requests drain
	}()

	const ticks = 10
	go func() {
		for i := 0; i < ticks; i++ {
			select {
			case tickC <- time.Now():
			case <-ctx.Done():
				return // Run stopped consuming (e.g. stuck serializing); stop feeding.
			}
		}
	}()

	select {
	case <-done:
	case <-time.After(5 * time.Second):
		t.Fatal("Generator.Run did not return within 5s of ctx expiring")
	}

	got := obs.n.Load()
	const want = int64(ticks * 10)
	if got != want {
		t.Fatalf("observed %d requests over %d ticks; want exactly %d -- if dispatch had serialized on per-request latency, ctx would have expired before all ticks were processed, yielding far fewer", got, ticks, want)
	}
}
