// Package config owns the app's identity and runtime knobs.
//
// Identity (the PET: Project/Environment/Tenant plus Release) is fixed at
// startup from environment variables and never mutated. Settings are the
// live-editable knobs the control panel drives, guarded by a mutex because the
// generator and sinks read them while the HTTP API writes them.
package config

import (
	"os"
	"strconv"
	"strings"
	"sync"
)

// Mode controls how the app presents its metrics, reproducing the scrape-time
// conditions the Live Application Status connector must handle.
type Mode string

const (
	// ModeNormal serves the full app_* metric surface.
	ModeNormal Mode = "normal"
	// ModeAbsent still serves /metrics but omits the app_* workload series, so a
	// grouped query returns no row for this PET (empty result -> Unknown,
	// distinct from Unhealthy).
	ModeAbsent Mode = "absent"
	// ModeDown makes /metrics return HTTP 503 so Prometheus records up=0 and the
	// series go stale after the lookback window.
	ModeDown Mode = "down"
)

// ParseMode normalises a string to a Mode, falling back to ModeNormal for any
// unrecognised value.
func ParseMode(s string) Mode {
	switch Mode(strings.ToLower(strings.TrimSpace(s))) {
	case ModeAbsent:
		return ModeAbsent
	case ModeDown:
		return ModeDown
	default:
		return ModeNormal
	}
}

// Identity is the PET tuple plus release. It is fixed at startup and never
// mutated, so it needs no locking.
type Identity struct {
	Service string // APP_PROJECT     -> service label
	Env     string // APP_ENVIRONMENT -> env label
	Tenant  string // APP_TENANT      -> tenant label (omitted entirely when empty)
	Release string // APP_RELEASE     -> release label (version carrier, NOT a PET scope dimension)
}

// Settings are the runtime-mutable knobs the control panel can drive.
type Settings struct {
	MaxRPS               float64 // target request rate at full ramp
	RampSeconds          float64 // linear ramp 0->max on startup / ramp-restart
	ErrorRate            float64 // fraction of simulated requests that fail, in [0,1]
	LatencyMeanMs        float64 // mean synthetic latency
	LatencyJitterMs      float64 // +/- jitter on latency
	Mode                 Mode    // normal | absent | down
	SuccessWindowSeconds int     // rolling window for the success-rate gauge
}

// Config holds the fixed identity, the mutable settings (mutex-guarded), and
// startup-only process settings. All settings access goes through the accessor
// methods so reads and writes stay race-free.
type Config struct {
	identity Identity

	mu       sync.RWMutex
	settings Settings

	logLevel    string
	httpAddr    string
	maxInFlight int
}

// Load builds a Config from the environment, applying the documented defaults
// for any unset variable.
func Load() *Config {
	return &Config{
		identity: Identity{
			Service: getEnv("APP_PROJECT", "checkout"),
			Env:     getEnv("APP_ENVIRONMENT", "production"),
			Tenant:  getEnv("APP_TENANT", ""),
			Release: getEnv("APP_RELEASE", "1.0.0"),
		},
		settings: Settings{
			MaxRPS:               maxF(0, getEnvFloat("APP_MAX_RPS", 50)),
			RampSeconds:          maxF(0, getEnvFloat("APP_RAMP_SECONDS", 10)),
			ErrorRate:            clamp01(getEnvFloat("APP_ERROR_RATE", 0.005)),
			LatencyMeanMs:        maxF(0, getEnvFloat("APP_LATENCY_MEAN_MS", 80)),
			LatencyJitterMs:      maxF(0, getEnvFloat("APP_LATENCY_JITTER_MS", 40)),
			Mode:                 ParseMode(getEnv("APP_MODE", string(ModeNormal))),
			SuccessWindowSeconds: maxI(1, getEnvInt("APP_SUCCESS_WINDOW_SECONDS", 60)),
		},
		logLevel:    getEnv("APP_LOG_LEVEL", "info"),
		httpAddr:    getEnv("APP_HTTP_ADDR", ":8080"),
		maxInFlight: maxI(1, getEnvInt("APP_MAX_INFLIGHT", 4096)),
	}
}

func (c *Config) Identity() Identity { return c.identity }

func (c *Config) LogLevel() string { return c.logLevel }

func (c *Config) HTTPAddr() string { return c.httpAddr }

// MaxInFlight caps the generator's worker fan-out so a high rps x latency
// product can't spawn an unbounded number of goroutines.
func (c *Config) MaxInFlight() int { return c.maxInFlight }

// Settings returns a snapshot of the current runtime knobs.
func (c *Config) Settings() Settings {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return c.settings
}

// SettingsPatch is a partial update to Settings: nil fields are left unchanged.
// It is the JSON body accepted by POST /api/state.
type SettingsPatch struct {
	MaxRPS               *float64 `json:"max_rps,omitempty"`
	RampSeconds          *float64 `json:"ramp_seconds,omitempty"`
	ErrorRate            *float64 `json:"error_rate,omitempty"`
	LatencyMeanMs        *float64 `json:"latency_mean_ms,omitempty"`
	LatencyJitterMs      *float64 `json:"latency_jitter_ms,omitempty"`
	Mode                 *Mode    `json:"mode,omitempty"`
	SuccessWindowSeconds *int     `json:"success_window_seconds,omitempty"`
}

// Apply merges the patch into the current settings, validating/clamping each
// field, and returns the resulting Settings.
func (c *Config) Apply(p SettingsPatch) Settings {
	c.mu.Lock()
	defer c.mu.Unlock()
	if p.MaxRPS != nil {
		c.settings.MaxRPS = maxF(0, *p.MaxRPS)
	}
	if p.RampSeconds != nil {
		c.settings.RampSeconds = maxF(0, *p.RampSeconds)
	}
	if p.ErrorRate != nil {
		c.settings.ErrorRate = clamp01(*p.ErrorRate)
	}
	if p.LatencyMeanMs != nil {
		c.settings.LatencyMeanMs = maxF(0, *p.LatencyMeanMs)
	}
	if p.LatencyJitterMs != nil {
		c.settings.LatencyJitterMs = maxF(0, *p.LatencyJitterMs)
	}
	if p.Mode != nil {
		c.settings.Mode = ParseMode(string(*p.Mode))
	}
	if p.SuccessWindowSeconds != nil {
		c.settings.SuccessWindowSeconds = maxI(1, *p.SuccessWindowSeconds)
	}
	return c.settings
}

func getEnv(key, def string) string {
	if v, ok := os.LookupEnv(key); ok {
		return v
	}
	return def
}

func getEnvFloat(key string, def float64) float64 {
	if v, ok := os.LookupEnv(key); ok {
		if f, err := strconv.ParseFloat(strings.TrimSpace(v), 64); err == nil {
			return f
		}
	}
	return def
}

func getEnvInt(key string, def int) int {
	if v, ok := os.LookupEnv(key); ok {
		if n, err := strconv.Atoi(strings.TrimSpace(v)); err == nil {
			return n
		}
	}
	return def
}

func clamp01(f float64) float64 {
	if f < 0 {
		return 0
	}
	if f > 1 {
		return 1
	}
	return f
}

func maxF(lo, f float64) float64 {
	if f < lo {
		return lo
	}
	return f
}

func maxI(lo, n int) int {
	if n < lo {
		return lo
	}
	return n
}
