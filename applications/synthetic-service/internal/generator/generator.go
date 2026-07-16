// Package generator simulates request traffic against the app: a ramping RPS
// curve, a configurable error rate, and jittered latency. Each simulated
// request is dispatched on its own goroutine, occupies its latency, is reported
// to a sink.Observer, and is logged once.
package generator

import (
	"context"
	"log/slog"
	"math/rand"
	"sync"
	"time"

	"github.com/OctopusDeploy/synthetic-service/internal/config"
	"github.com/OctopusDeploy/synthetic-service/internal/sink"
)

// tickInterval is the fixed loop cadence. tickSeconds is its float64 form for
// the RPS -> per-tick-count math.
const (
	tickInterval = 100 * time.Millisecond
	tickSeconds  = float64(tickInterval) / float64(time.Second)
)

// Generator drives the simulated workload: a ramping RPS curve dispatched on a
// fixed tick, each request rolled for success/error and latency and handed to
// an Observer on its own goroutine.
//
// Requests per tick derive from the effective RPS, and each is dispatched
// concurrently (bounded by a semaphore) rather than run to completion in
// series, so per-request latency never throttles throughput: observed and
// logged counts track MaxRPS regardless of how long each request takes.
//
// rng is mutated only by the Run goroutine, so it needs no locking. The ramp/rps
// state is written by Run and read by EffectiveRPS/RampProgress (usually from an
// HTTP handler goroutine), so it is guarded by mu.
type Generator struct {
	cfg    *config.Config
	obs    sink.Observer
	logger *slog.Logger

	rng *rand.Rand

	mu           sync.Mutex
	rampStart    time.Time
	accumulator  float64 // carried fractional request count between ticks
	effectiveRPS float64
	rampProgress float64

	sem chan struct{}  // bounds concurrently in-flight requests
	wg  sync.WaitGroup // tracks in-flight requests for graceful drain

	// tickC, when non-nil, is Run's tick source instead of a real time.Ticker.
	// It lets tests inject a deterministic sequence of ticks rather than depend
	// on wall-clock ticker delivery; production callers leave it nil.
	tickC <-chan time.Time
}

// New builds a Generator. Randomness is seeded deterministically so the
// generated traffic is reproducible. Concurrency is bounded by
// config.MaxInFlight.
func New(cfg *config.Config, obs sink.Observer, logger *slog.Logger) *Generator {
	return &Generator{
		cfg:    cfg,
		obs:    obs,
		logger: logger,
		rng:    rand.New(rand.NewSource(1)),
		sem:    make(chan struct{}, cfg.MaxInFlight()),
	}
}

// Run drives the workload loop on a fixed 100ms tick until ctx is cancelled,
// then waits for in-flight requests to drain.
func (g *Generator) Run(ctx context.Context) {
	g.mu.Lock()
	g.rampStart = time.Now()
	g.mu.Unlock()

	tickC := g.tickC
	if tickC == nil {
		ticker := time.NewTicker(tickInterval)
		defer ticker.Stop()
		tickC = ticker.C
	}

	for {
		select {
		case <-ctx.Done():
			g.wg.Wait()
			return
		case now := <-tickC:
			g.tick(ctx, now)
		}
	}
}

// tick computes the current effective RPS, works out how many requests to
// dispatch this tick (carrying any fractional remainder forward), rolls each
// one's outcome, and fires it concurrently.
func (g *Generator) tick(ctx context.Context, now time.Time) {
	settings := g.cfg.Settings()

	g.mu.Lock()
	elapsed := now.Sub(g.rampStart).Seconds()
	frac := rampFraction(elapsed, settings.RampSeconds)
	effRPS := settings.MaxRPS * frac

	g.effectiveRPS = effRPS
	g.rampProgress = frac

	var count int
	count, g.accumulator = accumulate(effRPS, tickSeconds, g.accumulator)
	g.mu.Unlock()

	for i := 0; i < count; i++ {
		// The success/latency rolls happen here, on the single Run goroutine,
		// so rng consumption stays ordered and reproducible; only the timed
		// per-request work below runs concurrently.
		success := g.rng.Float64() >= settings.ErrorRate
		latency := settings.LatencyMeanMs + (g.rng.Float64()*2-1)*settings.LatencyJitterMs
		if latency < 0 {
			latency = 0
		}
		g.dispatch(ctx, success, latency)
	}
}

// dispatch runs one simulated request on its own goroutine: it occupies the
// rolled latency, reports the outcome to the sink, and logs it once. A
// semaphore bounds how many requests can be in flight at once; acquiring a slot
// blocks only under genuine overload (in-flight exceeding MaxInFlight).
func (g *Generator) dispatch(ctx context.Context, success bool, latencyMs float64) {
	select {
	case g.sem <- struct{}{}:
	case <-ctx.Done():
		return
	}

	g.wg.Go(func() {
		defer func() { <-g.sem }()

		if latencyMs > 0 {
			timer := time.NewTimer(time.Duration(latencyMs) * time.Millisecond)
			defer timer.Stop()
			select {
			case <-timer.C:
			case <-ctx.Done():
			}
		}

		g.obs.Observe(sink.RequestObservation{Success: success, LatencyMs: latencyMs})

		if success {
			g.logger.Debug("simulated request", "status", "success", "latency_ms", latencyMs)
		} else {
			g.logger.Error("simulated request", "status", "error", "latency_ms", latencyMs)
		}
	})
}

// EffectiveRPS returns the current effective RPS (post-ramp), safe for
// concurrent use.
func (g *Generator) EffectiveRPS() float64 {
	g.mu.Lock()
	defer g.mu.Unlock()
	return g.effectiveRPS
}

// RampProgress returns the current ramp fraction in [0,1], safe for
// concurrent use.
func (g *Generator) RampProgress() float64 {
	g.mu.Lock()
	defer g.mu.Unlock()
	return g.rampProgress
}

// RestartRamp resets the ramp so effective RPS climbs from 0 again, safe for
// concurrent use.
func (g *Generator) RestartRamp() {
	g.mu.Lock()
	defer g.mu.Unlock()
	g.rampStart = time.Now()
	g.rampProgress = 0
	g.effectiveRPS = 0
}

// rampFraction is the pure ramp curve: 0 at elapsed=0, linear to 1 at
// elapsed=rampSeconds, clamped to [0,1] beyond that. A non-positive
// rampSeconds means the ramp completes instantly.
func rampFraction(elapsed, rampSeconds float64) float64 {
	if rampSeconds <= 0 {
		return 1
	}
	frac := elapsed / rampSeconds
	if frac < 0 {
		return 0
	}
	if frac > 1 {
		return 1
	}
	return frac
}

// accumulate returns how many whole requests to dispatch this tick, given the
// rps, tick length in seconds, and the fractional remainder carried from the
// previous tick. Returning the new remainder to carry forward keeps throughput
// matching rps over the long run instead of truncating a fraction every tick.
func accumulate(rps, tickSeconds, carry float64) (count int, remainder float64) {
	total := rps*tickSeconds + carry
	count = int(total)
	remainder = total - float64(count)
	return count, remainder
}
