// Command uptime is one program with several jobs. Each ECS task (or Docker
// Compose service) runs the same image and picks a job by name:
//
//	uptime api            run the HTTP API
//	uptime migrate        create or update the database tables
//	uptime seed           add a few example monitors
//	uptime check          check every monitor once, then exit
//	uptime rollup         build daily summaries and the CSV report, then exit
//	uptime dev-scheduler  run check and rollup on a timer (local only)
package main

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"os"
	"os/signal"
	"syscall"
	"time"

	"gorm.io/gorm"

	"uptime/internal/api"
	"uptime/internal/checker"
	"uptime/internal/config"
	"uptime/internal/db"
	"uptime/internal/models"
	"uptime/internal/reports"
	"uptime/internal/rollup"
)

const usage = `usage: uptime <command>

commands:
  api            run the HTTP API
  migrate        create or update the database tables
  seed           add a few example monitors
  check          check every monitor once, then exit
  rollup         build daily summaries and the CSV report, then exit
  dev-scheduler  run check and rollup on a timer (local only)
`

var commands = map[string]func(context.Context, config.Config, *gorm.DB) error{
	"api":           runAPI,
	"migrate":       runMigrate,
	"seed":          runSeed,
	"check":         runCheck,
	"rollup":        runRollup,
	"dev-scheduler": runDevScheduler,
}

func main() {
	slog.SetDefault(slog.New(slog.NewJSONHandler(os.Stdout, nil)))

	if len(os.Args) < 2 {
		fmt.Fprint(os.Stderr, usage)
		os.Exit(2)
	}
	name := os.Args[1]
	command, ok := commands[name]
	if !ok {
		fmt.Fprintf(os.Stderr, "unknown command %q\n\n%s", name, usage)
		os.Exit(2)
	}

	// Stop cleanly on Ctrl+C locally, or SIGTERM from ECS.
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	if err := start(ctx, command); err != nil {
		slog.Error("command failed", "command", name, "error", err)
		os.Exit(1)
	}
}

func start(ctx context.Context, command func(context.Context, config.Config, *gorm.DB) error) error {
	cfg, err := config.Load()
	if err != nil {
		return fmt.Errorf("bad settings: %w", err)
	}
	gdb, err := db.Open(ctx, cfg)
	if err != nil {
		return err
	}
	return command(ctx, cfg, gdb)
}

func runAPI(ctx context.Context, cfg config.Config, gdb *gorm.DB) error {
	if cfg.AdminToken == "" {
		return errors.New("ADMIN_TOKEN must be set")
	}
	server := api.NewServer(gdb, reports.Dir{Path: cfg.ReportDir}, cfg.AdminToken, cfg.AllowPrivateTargets)
	return api.Run(ctx, ":"+cfg.HTTPPort, server.Routes())
}

func runMigrate(ctx context.Context, cfg config.Config, gdb *gorm.DB) error {
	if err := db.Migrate(gdb.WithContext(ctx)); err != nil {
		return err
	}
	slog.Info("database tables are up to date")
	return nil
}

func runSeed(ctx context.Context, cfg config.Config, gdb *gorm.DB) error {
	var count int64
	if err := gdb.WithContext(ctx).Model(&models.Monitor{}).Count(&count).Error; err != nil {
		return err
	}
	if count > 0 {
		slog.Info("monitors already exist, skipping seed", "count", count)
		return nil
	}

	examples := []models.Monitor{
		{Name: "Example website", URL: "https://example.com", ExpectedStatus: 200},
		{Name: "Broken on purpose", URL: "https://this-site-does-not-exist.invalid", ExpectedStatus: 200},
	}
	// Our own API is on a private Docker network, so only add it when
	// private targets are allowed (local development).
	if cfg.AllowPrivateTargets {
		examples = append(examples, models.Monitor{Name: "Our own API", URL: "http://api:8080/api/ready", ExpectedStatus: 200})
	}

	if err := gdb.WithContext(ctx).Create(&examples).Error; err != nil {
		return err
	}
	slog.Info("example monitors added", "count", len(examples))
	return nil
}

func runCheck(ctx context.Context, cfg config.Config, gdb *gorm.DB) error {
	return runLocked(ctx, gdb, "uptime-check", func() error {
		return checker.New(gdb, cfg).RunOnce(ctx)
	})
}

func runRollup(ctx context.Context, cfg config.Config, gdb *gorm.DB) error {
	return runLocked(ctx, gdb, "uptime-rollup", func() error {
		return rollup.Run(ctx, gdb, reports.Dir{Path: cfg.ReportDir}, cfg.RetentionDays, time.Now())
	})
}

// runDevScheduler stands in for EventBridge Scheduler on your laptop. On AWS
// this command is not used: EventBridge starts `check` and `rollup` as
// separate ECS tasks instead.
func runDevScheduler(ctx context.Context, cfg config.Config, gdb *gorm.DB) error {
	slog.Info("dev scheduler started", "check_every", cfg.DevCheckEvery.String(), "rollup_every", cfg.DevRollupEvery.String())

	check := func() {
		if err := runCheck(ctx, cfg, gdb); err != nil {
			slog.Error("check failed", "error", err)
		}
	}
	roll := func() {
		if err := runRollup(ctx, cfg, gdb); err != nil {
			slog.Error("rollup failed", "error", err)
		}
	}

	check()
	roll()

	checkTicker := time.NewTicker(cfg.DevCheckEvery)
	defer checkTicker.Stop()
	rollupTicker := time.NewTicker(cfg.DevRollupEvery)
	defer rollupTicker.Stop()

	for {
		select {
		case <-ctx.Done():
			slog.Info("dev scheduler stopped")
			return nil
		case <-checkTicker.C:
			check()
		case <-rollupTicker.C:
			roll()
		}
	}
}

// runLocked makes sure only one copy of a job runs at a time. If another copy
// is busy, this run is skipped. That is not an error.
func runLocked(ctx context.Context, gdb *gorm.DB, lockName string, fn func() error) error {
	err := db.WithLock(ctx, gdb, lockName, fn)
	if errors.Is(err, db.ErrLocked) {
		slog.Info("skipping run, previous one still going", "job", lockName)
		return nil
	}
	return err
}
