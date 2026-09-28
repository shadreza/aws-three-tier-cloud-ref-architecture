// Package checker visits every monitor once and saves what happened.
package checker

import (
	"context"
	"errors"
	"io"
	"log/slog"
	"net"
	"net/http"
	"sync"
	"time"

	"gorm.io/gorm"

	"uptime/internal/config"
	"uptime/internal/models"
	"uptime/internal/netguard"
)

type Checker struct {
	db          *gorm.DB
	client      *http.Client
	concurrency int
}

func New(gdb *gorm.DB, cfg config.Config) *Checker {
	dialer := &net.Dialer{Timeout: 5 * time.Second}
	if !cfg.AllowPrivateTargets {
		dialer.Control = netguard.DialControl
	}

	transport := &http.Transport{
		Proxy:               nil, // never send checks through a proxy, it would hide the real IP from the guard
		DialContext:         dialer.DialContext,
		TLSHandshakeTimeout: 5 * time.Second,
		DisableKeepAlives:   true,
	}

	client := &http.Client{
		Timeout:   cfg.CheckTimeout,
		Transport: transport,
		CheckRedirect: func(req *http.Request, via []*http.Request) error {
			if len(via) >= 5 {
				return errors.New("too many redirects")
			}
			return nil
		},
	}

	return &Checker{db: gdb, client: client, concurrency: cfg.CheckConcurrency}
}

// RunOnce checks all monitors, a few at a time, then saves every result in
// one insert.
func (c *Checker) RunOnce(ctx context.Context) error {
	var monitors []models.Monitor
	if err := c.db.WithContext(ctx).Find(&monitors).Error; err != nil {
		return err
	}
	if len(monitors) == 0 {
		slog.Info("no monitors to check")
		return nil
	}

	results := make([]models.CheckResult, len(monitors))
	slots := make(chan struct{}, c.concurrency)
	var wg sync.WaitGroup

	for i, m := range monitors {
		wg.Add(1)
		slots <- struct{}{}
		go func() {
			defer wg.Done()
			defer func() { <-slots }()
			results[i] = c.checkOne(ctx, m)
		}()
	}
	wg.Wait()

	if err := c.db.WithContext(ctx).Create(&results).Error; err != nil {
		return err
	}

	up := 0
	for _, r := range results {
		if r.IsUp {
			up++
		}
	}
	slog.Info("check finished", "monitors", len(results), "up", up, "down", len(results)-up)
	return nil
}

func (c *Checker) checkOne(ctx context.Context, m models.Monitor) models.CheckResult {
	result := models.CheckResult{MonitorID: m.ID, CheckedAt: time.Now().UTC()}

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, m.URL, nil)
	if err != nil {
		result.Error = shorten(err.Error())
		return result
	}
	req.Header.Set("User-Agent", "uptime-checker/1.0")

	start := time.Now()
	resp, err := c.client.Do(req)
	if err != nil {
		result.LatencyMS = time.Since(start).Milliseconds()
		result.Error = shorten(err.Error())
		return result
	}
	defer resp.Body.Close()

	// Read (up to 1 MB of) the body so the timing includes the download.
	io.Copy(io.Discard, io.LimitReader(resp.Body, 1<<20))

	result.LatencyMS = time.Since(start).Milliseconds()
	result.StatusCode = resp.StatusCode
	result.IsUp = resp.StatusCode == m.ExpectedStatus
	if !result.IsUp {
		result.Error = "unexpected status " + resp.Status
	}
	return result
}

func shorten(s string) string {
	if len(s) > 500 {
		return s[:500]
	}
	return s
}
