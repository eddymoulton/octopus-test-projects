// Package logging builds the app's structured logger and defines a fan-out
// seam so a future log-shipping backend (e.g. a LokiSink) can subscribe to the
// same records without touching any call site.
//
// Today the fan-out holds a single stdout JSON handler. More slog.Handlers can
// be supplied via NewWithWriters, and every log call broadcasts to all of them.
// Loki is not wired up yet.
package logging

import (
	"context"
	"io"
	"log/slog"
	"os"
	"strings"
)

// ParseLevel maps an APP_LOG_LEVEL string to an slog.Level, defaulting to
// info for anything unrecognised.
func ParseLevel(s string) slog.Level {
	switch strings.ToLower(strings.TrimSpace(s)) {
	case "debug":
		return slog.LevelDebug
	case "warn", "warning":
		return slog.LevelWarn
	case "error":
		return slog.LevelError
	default:
		return slog.LevelInfo
	}
}

// New returns a JSON slog.Logger writing to stdout at the given level.
func New(level string) *slog.Logger {
	return NewWithWriters(level, os.Stdout)
}

// NewWithWriters is New with explicit writers. Each writer gets its own JSON
// handler and every record is broadcast to all of them, the multi-destination
// seam a future log shipper plugs into. With a single writer it behaves like a
// plain JSON logger.
func NewWithWriters(level string, writers ...io.Writer) *slog.Logger {
	lvl := ParseLevel(level)
	handlers := make([]slog.Handler, 0, len(writers))
	for _, w := range writers {
		handlers = append(handlers, slog.NewJSONHandler(w, &slog.HandlerOptions{Level: lvl}))
	}
	return slog.New(newFanoutHandler(handlers...))
}

// fanoutHandler broadcasts each record to every wrapped handler.
type fanoutHandler struct {
	handlers []slog.Handler
}

func newFanoutHandler(handlers ...slog.Handler) slog.Handler {
	return &fanoutHandler{handlers: handlers}
}

func (h *fanoutHandler) Enabled(ctx context.Context, level slog.Level) bool {
	for _, hh := range h.handlers {
		if hh.Enabled(ctx, level) {
			return true
		}
	}
	return false
}

func (h *fanoutHandler) Handle(ctx context.Context, r slog.Record) error {
	var firstErr error
	for _, hh := range h.handlers {
		if !hh.Enabled(ctx, r.Level) {
			continue
		}
		// Clone so handlers that mutate the record don't interfere with each other.
		if err := hh.Handle(ctx, r.Clone()); err != nil && firstErr == nil {
			firstErr = err
		}
	}
	return firstErr
}

func (h *fanoutHandler) WithAttrs(attrs []slog.Attr) slog.Handler {
	next := make([]slog.Handler, len(h.handlers))
	for i, hh := range h.handlers {
		next[i] = hh.WithAttrs(attrs)
	}
	return &fanoutHandler{handlers: next}
}

func (h *fanoutHandler) WithGroup(name string) slog.Handler {
	next := make([]slog.Handler, len(h.handlers))
	for i, hh := range h.handlers {
		next[i] = hh.WithGroup(name)
	}
	return &fanoutHandler{handlers: next}
}
