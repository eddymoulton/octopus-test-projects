// Package httpapi exposes the app's HTTP surface: the embedded control
// panel, the JSON state API it polls and posts to, and the /metrics and
// /healthz endpoints main.go's http.Server serves.
//
// The server depends only on small consumer-defined interfaces (Generator,
// Metrics) rather than the concrete generator/prometheus-sink types, so this
// package compiles standalone against config + stdlib.
package httpapi

import (
	"embed"
	"encoding/json"
	"log/slog"
	"net/http"

	"github.com/OctopusDeploy/synthetic-service/internal/config"
)

//go:embed ui/index.html
var uiFS embed.FS

// Generator is the workload-generator surface the control panel drives and
// displays. The concrete generator type satisfies this.
type Generator interface {
	// EffectiveRPS is the current simulated request rate (post-ramp).
	EffectiveRPS() float64
	// RampProgress is the startup/restart ramp completion, in [0,1].
	RampProgress() float64
	// RestartRamp resets the ramp to 0 and begins climbing to MaxRPS again.
	RestartRamp()
}

// Metrics is the Prometheus sink surface the control panel exposes. The
// concrete prometheus sink type satisfies this.
type Metrics interface {
	// Handler serves the Prometheus exposition format for GET /metrics.
	Handler() http.Handler
	// ObservedSuccessRate is the rolling success rate over the sink's
	// success-window, as reported by the metrics backend itself.
	ObservedSuccessRate() float64
}

// Server holds the collaborators needed to build the app's HTTP routes.
// It never calls ListenAndServe itself; main.go owns the http.Server.
type Server struct {
	cfg     *config.Config
	gen     Generator
	metrics Metrics
	logger  *slog.Logger
}

// NewServer builds a Server from its collaborators. Call Handler to get the
// routed http.Handler to serve.
func NewServer(cfg *config.Config, gen Generator, metrics Metrics, logger *slog.Logger) *Server {
	return &Server{cfg: cfg, gen: gen, metrics: metrics, logger: logger}
}

// Handler builds the app's routes on a fresh http.ServeMux.
func (s *Server) Handler() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /{$}", s.handleIndex)
	mux.HandleFunc("GET /metrics", s.handleMetrics)
	mux.HandleFunc("GET /api/state", s.handleGetState)
	mux.HandleFunc("POST /api/state", s.handlePostState)
	mux.HandleFunc("POST /api/ramp/restart", s.handleRestartRamp)
	mux.HandleFunc("GET /healthz", s.handleHealthz)
	return mux
}

// handleIndex serves the embedded control panel page.
func (s *Server) handleIndex(w http.ResponseWriter, r *http.Request) {
	b, err := uiFS.ReadFile("ui/index.html")
	if err != nil {
		s.logger.Error("failed to read embedded control panel", "err", err)
		http.Error(w, "control panel unavailable", http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.Write(b)
}

// handleMetrics applies the mode middleware: ModeDown returns 503 so
// Prometheus records up=0. Anything else (including ModeAbsent, which omits
// the app_* series inside metrics.Handler itself) delegates straight through.
func (s *Server) handleMetrics(w http.ResponseWriter, r *http.Request) {
	if s.cfg.Settings().Mode == config.ModeDown {
		http.Error(w, "metrics down", http.StatusServiceUnavailable)
		return
	}
	s.metrics.Handler().ServeHTTP(w, r)
}

// handleGetState reports identity, current settings, and the derived values
// the control panel displays.
func (s *Server) handleGetState(w http.ResponseWriter, r *http.Request) {
	s.writeState(w)
}

// handlePostState decodes a config.SettingsPatch, applies it, and responds
// with the resulting state so the caller can refresh from one round trip.
func (s *Server) handlePostState(w http.ResponseWriter, r *http.Request) {
	var patch config.SettingsPatch
	if err := json.NewDecoder(r.Body).Decode(&patch); err != nil {
		s.logger.Warn("malformed settings patch", "err", err)
		http.Error(w, "malformed json", http.StatusBadRequest)
		return
	}
	s.cfg.Apply(patch)
	s.writeState(w)
}

// handleRestartRamp resets the generator's ramp and responds with the
// resulting state.
func (s *Server) handleRestartRamp(w http.ResponseWriter, r *http.Request) {
	s.gen.RestartRamp()
	s.writeState(w)
}

// handleHealthz is the container liveness check.
func (s *Server) handleHealthz(w http.ResponseWriter, r *http.Request) {
	w.Write([]byte("ok"))
}

// apiIdentity is the JSON shape of the PET identity in /api/state.
type apiIdentity struct {
	Service string `json:"service"`
	Env     string `json:"env"`
	Tenant  string `json:"tenant"`
	Release string `json:"release"`
}

// apiSettings is the JSON shape of the live-editable knobs in /api/state,
// mirroring config.Settings under the same field names config.SettingsPatch
// uses on the way in.
type apiSettings struct {
	MaxRPS               float64     `json:"max_rps"`
	RampSeconds          float64     `json:"ramp_seconds"`
	ErrorRate            float64     `json:"error_rate"`
	LatencyMeanMs        float64     `json:"latency_mean_ms"`
	LatencyJitterMs      float64     `json:"latency_jitter_ms"`
	Mode                 config.Mode `json:"mode"`
	SuccessWindowSeconds int         `json:"success_window_seconds"`
}

// apiState is the full JSON body returned by GET/POST /api/state and by
// POST /api/ramp/restart.
type apiState struct {
	Identity            apiIdentity `json:"identity"`
	Settings            apiSettings `json:"settings"`
	EffectiveRPS        float64     `json:"effective_rps"`
	RampProgress        float64     `json:"ramp_progress"`
	ObservedSuccessRate float64     `json:"observed_success_rate"`
}

// currentState snapshots identity, settings, and the derived values reported
// by the generator and metrics collaborators.
func (s *Server) currentState() apiState {
	id := s.cfg.Identity()
	set := s.cfg.Settings()
	return apiState{
		Identity: apiIdentity{
			Service: id.Service,
			Env:     id.Env,
			Tenant:  id.Tenant,
			Release: id.Release,
		},
		Settings: apiSettings{
			MaxRPS:               set.MaxRPS,
			RampSeconds:          set.RampSeconds,
			ErrorRate:            set.ErrorRate,
			LatencyMeanMs:        set.LatencyMeanMs,
			LatencyJitterMs:      set.LatencyJitterMs,
			Mode:                 set.Mode,
			SuccessWindowSeconds: set.SuccessWindowSeconds,
		},
		EffectiveRPS:        s.gen.EffectiveRPS(),
		RampProgress:        s.gen.RampProgress(),
		ObservedSuccessRate: s.metrics.ObservedSuccessRate(),
	}
}

// writeState encodes currentState as the JSON response body.
func (s *Server) writeState(w http.ResponseWriter) {
	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(s.currentState()); err != nil {
		s.logger.Error("failed to encode state", "err", err)
	}
}
