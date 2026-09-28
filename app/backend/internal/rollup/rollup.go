// Package rollup turns raw check results into daily summaries and a CSV
// report, then deletes raw results that are too old to keep.
package rollup

import (
	"bytes"
	"context"
	"encoding/csv"
	"fmt"
	"log/slog"
	"math"
	"strconv"
	"time"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"

	"uptime/internal/models"
	"uptime/internal/reports"
)

// Run summarises yesterday and today. Doing yesterday again is on purpose:
// results that arrived just before midnight get counted. Running it twice is
// safe because each summary row is overwritten, not added again.
func Run(ctx context.Context, gdb *gorm.DB, store reports.Store, retentionDays int, now time.Time) error {
	today := now.UTC().Truncate(24 * time.Hour)

	for _, day := range []time.Time{today.AddDate(0, 0, -1), today} {
		if err := summariseDay(ctx, gdb, store, day); err != nil {
			return fmt.Errorf("summarise %s: %w", day.Format(time.DateOnly), err)
		}
	}

	cutoff := now.UTC().AddDate(0, 0, -retentionDays)
	res := gdb.WithContext(ctx).Where("checked_at < ?", cutoff).Delete(&models.CheckResult{})
	if res.Error != nil {
		return fmt.Errorf("delete old results: %w", res.Error)
	}
	slog.Info("old results deleted", "older_than", cutoff.Format(time.DateOnly), "rows", res.RowsAffected)
	return nil
}

type dayTotals struct {
	MonitorID  uint
	Checks     int
	UpChecks   int
	AvgLatency float64
}

func summariseDay(ctx context.Context, gdb *gorm.DB, store reports.Store, day time.Time) error {
	var totals []dayTotals
	err := gdb.WithContext(ctx).Model(&models.CheckResult{}).
		Select("monitor_id, COUNT(*) AS checks, SUM(CASE WHEN is_up THEN 1 ELSE 0 END) AS up_checks, AVG(latency_ms) AS avg_latency").
		Where("checked_at >= ? AND checked_at < ?", day, day.AddDate(0, 0, 1)).
		Group("monitor_id").
		Scan(&totals).Error
	if err != nil {
		return err
	}
	if len(totals) == 0 {
		slog.Info("no results for day, nothing to summarise", "day", day.Format(time.DateOnly))
		return nil
	}

	summaries := make([]models.DailySummary, len(totals))
	for i, t := range totals {
		summaries[i] = models.DailySummary{
			MonitorID:    t.MonitorID,
			Day:          day,
			Checks:       t.Checks,
			UpChecks:     t.UpChecks,
			UptimePct:    math.Round(float64(t.UpChecks)/float64(t.Checks)*10000) / 100,
			AvgLatencyMS: int64(math.Round(t.AvgLatency)),
		}
	}

	// Insert, or overwrite the row if this monitor already has one for the day.
	err = gdb.WithContext(ctx).Clauses(clause.OnConflict{UpdateAll: true}).Create(&summaries).Error
	if err != nil {
		return err
	}

	data, err := buildCSV(ctx, gdb, summaries)
	if err != nil {
		return err
	}
	name := day.Format(time.DateOnly) + ".csv"
	if err := store.Save(ctx, name, data); err != nil {
		return err
	}

	slog.Info("day summarised", "day", day.Format(time.DateOnly), "monitors", len(summaries), "report", name)
	return nil
}

func buildCSV(ctx context.Context, gdb *gorm.DB, summaries []models.DailySummary) ([]byte, error) {
	var monitors []models.Monitor
	if err := gdb.WithContext(ctx).Find(&monitors).Error; err != nil {
		return nil, err
	}
	byID := make(map[uint]models.Monitor, len(monitors))
	for _, m := range monitors {
		byID[m.ID] = m
	}

	var buf bytes.Buffer
	w := csv.NewWriter(&buf)
	w.Write([]string{"day", "monitor", "url", "checks", "up_checks", "uptime_pct", "avg_latency_ms"})
	for _, s := range summaries {
		m := byID[s.MonitorID]
		w.Write([]string{
			s.Day.Format(time.DateOnly),
			m.Name,
			m.URL,
			strconv.Itoa(s.Checks),
			strconv.Itoa(s.UpChecks),
			strconv.FormatFloat(s.UptimePct, 'f', 2, 64),
			strconv.FormatInt(s.AvgLatencyMS, 10),
		})
	}
	w.Flush()
	return buf.Bytes(), w.Error()
}
