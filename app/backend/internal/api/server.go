// Package api is the HTTP API the frontend talks to.
package api

import (
	"context"
	"crypto/subtle"
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"
	"time"

	"gorm.io/gorm"

	"uptime/internal/reports"
)

type Server struct {
	db           *gorm.DB
	reports      reports.Store
	adminToken   string
	allowPrivate bool
}

func NewServer(gdb *gorm.DB, store reports.Store, adminToken string, allowPrivate bool) *Server {
	return &Server{db: gdb, reports: store, adminToken: adminToken, allowPrivate: allowPrivate}
}

// Routes lists every endpoint. Reading is open to everyone. Changing data
// needs the admin token.
func (s *Server) Routes() http.Handler {
	mux := http.NewServeMux()

	mux.HandleFunc("GET /api/health", s.health)
	mux.HandleFunc("GET /api/ready", s.ready)

	mux.HandleFunc("GET /api/monitors", s.listMonitors)
	mux.HandleFunc("POST /api/monitors", s.requireAdmin(s.createMonitor))
	mux.HandleFunc("DELETE /api/monitors/{id}", s.requireAdmin(s.deleteMonitor))
	mux.HandleFunc("GET /api/monitors/{id}/results", s.listResults)
	mux.HandleFunc("GET /api/monitors/{id}/daily", s.listDaily)

	mux.HandleFunc("GET /api/reports", s.listReports)
	mux.HandleFunc("GET /api/reports/{name}", s.getReport)

	return logRequests(mux)
}

// Run serves HTTP until ctx is cancelled, then gives open requests up to
// 10 seconds to finish. ECS sends SIGTERM before stopping a task, so this
// matters during deploys.
func Run(ctx context.Context, addr string, handler http.Handler) error {
	srv := &http.Server{
		Addr:              addr,
		Handler:           handler,
		ReadHeaderTimeout: 5 * time.Second,
	}

	errCh := make(chan error, 1)
	go func() {
		slog.Info("api listening", "addr", addr)
		errCh <- srv.ListenAndServe()
	}()

	select {
	case err := <-errCh:
		return err
	case <-ctx.Done():
	}

	slog.Info("shutting down api")
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := srv.Shutdown(shutdownCtx); err != nil {
		return err
	}
	if err := <-errCh; !errors.Is(err, http.ErrServerClosed) {
		return err
	}
	return nil
}

// health says "the process is alive". It does not touch the database, so a
// database problem does not make the load balancer kill healthy containers.
func (s *Server) health(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

// ready says "I can do real work", which means the database answers.
func (s *Server) ready(w http.ResponseWriter, r *http.Request) {
	sqlDB, err := s.db.DB()
	if err == nil {
		ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
		defer cancel()
		err = sqlDB.PingContext(ctx)
	}
	if err != nil {
		slog.Warn("not ready", "error", err)
		writeError(w, http.StatusServiceUnavailable, "database is not reachable")
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "ready"})
}

func (s *Server) requireAdmin(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		want := "Bearer " + s.adminToken
		got := r.Header.Get("Authorization")
		if subtle.ConstantTimeCompare([]byte(got), []byte(want)) != 1 {
			writeError(w, http.StatusUnauthorized, "admin token is missing or wrong")
			return
		}
		next(w, r)
	}
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(v)
}

func writeError(w http.ResponseWriter, status int, message string) {
	writeJSON(w, status, map[string]string{"error": message})
}

type statusRecorder struct {
	http.ResponseWriter
	status int
}

func (r *statusRecorder) WriteHeader(status int) {
	r.status = status
	r.ResponseWriter.WriteHeader(status)
}

// logRequests writes one log line per request. Health checks are skipped
// because the load balancer calls them every few seconds.
func logRequests(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/api/health" {
			next.ServeHTTP(w, r)
			return
		}
		start := time.Now()
		rec := &statusRecorder{ResponseWriter: w, status: http.StatusOK}
		next.ServeHTTP(rec, r)
		slog.Info("request",
			"method", r.Method,
			"path", r.URL.Path,
			"status", rec.status,
			"duration_ms", time.Since(start).Milliseconds(),
		)
	})
}
