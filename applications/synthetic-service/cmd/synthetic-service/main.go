// Command synthetic-service is one instance of the Live Application Status
// synthetic app: a fake service that simulates request traffic and exposes
// Prometheus metrics labelled by its PET identity (Project/Environment/Tenant
// plus Release).
//
// One process is one PET. Run several via docker-compose for a matrix of
// Healthy/Degraded/Unhealthy/Unknown instances. See README.md.
//
// It wires config -> logging -> sinks -> generator -> HTTP server with graceful
// shutdown. The -healthcheck flag turns the binary into its own liveness probe
// (the distroless image has no shell or curl), which the compose healthcheck
// invokes.
package main

import (
	"context"
	"errors"
	"flag"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/OctopusDeploy/synthetic-service/internal/config"
	"github.com/OctopusDeploy/synthetic-service/internal/generator"
	"github.com/OctopusDeploy/synthetic-service/internal/httpapi"
	"github.com/OctopusDeploy/synthetic-service/internal/logging"
	"github.com/OctopusDeploy/synthetic-service/internal/sink"
)

func main() {
	healthcheck := flag.Bool("healthcheck", false, "probe /healthz on the local listen address and exit 0 (healthy) or 1 (unhealthy)")
	flag.Parse()

	cfg := config.Load()

	if *healthcheck {
		os.Exit(runHealthcheck(cfg.HTTPAddr()))
	}

	id := cfg.Identity()

	// Base logger carries the PET identity on every line, so downstream call
	// sites only add per-event attrs (status, latency_ms, ...).
	logger := logging.New(cfg.LogLevel()).With(
		"service", id.Service,
		"env", id.Env,
		"release", id.Release,
	)
	if id.Tenant != "" {
		logger = logger.With("tenant", id.Tenant)
	}

	// Wire the fan-out seam. Only the Prometheus sink is implemented today; add
	// more here via reg.Add(...) (see internal/sink/stubs.go).
	promSink := sink.NewPrometheusSink(id, cfg)
	reg := sink.NewRegistry(promSink)

	gen := generator.New(cfg, reg, logger)
	srv := httpapi.NewServer(cfg, gen, promSink, logger)

	// Cancel everything on SIGINT/SIGTERM.
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	var wg sync.WaitGroup
	wg.Go(func() {
		gen.Run(ctx) // blocks until ctx is cancelled
	})

	httpServer := &http.Server{
		Addr:              cfg.HTTPAddr(),
		Handler:           srv.Handler(),
		ReadHeaderTimeout: 5 * time.Second,
	}

	// Graceful shutdown: when the signal fires, drain the HTTP server.
	go func() {
		<-ctx.Done()
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		if err := httpServer.Shutdown(shutdownCtx); err != nil {
			logger.Error("http server shutdown error", "err", err)
		}
	}()

	logger.Info("synthetic-service starting",
		"addr", cfg.HTTPAddr(),
		"mode", cfg.Settings().Mode,
		"max_rps", cfg.Settings().MaxRPS,
	)

	if err := httpServer.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
		logger.Error("http server error", "err", err)
	}

	stop()    // ensure the generator's context is cancelled
	wg.Wait() // wait for the generator loop to exit cleanly
	logger.Info("synthetic-service stopped")
}

// runHealthcheck probes the local /healthz endpoint and returns a process exit
// code: 0 if healthy (HTTP 200), else 1. The container healthcheck uses it
// because the distroless image ships no shell or curl.
func runHealthcheck(addr string) int {
	host := addr
	if strings.HasPrefix(host, ":") {
		host = "127.0.0.1" + host
	}
	client := &http.Client{Timeout: 2 * time.Second}
	resp, err := client.Get("http://" + host + "/healthz")
	if err != nil {
		return 1
	}
	defer resp.Body.Close()
	if resp.StatusCode == http.StatusOK {
		return 0
	}
	return 1
}
