// Package models holds the database tables. GORM creates the tables from
// these structs when you run the migrate command.
package models

import "time"

// Monitor is one web address we keep an eye on.
type Monitor struct {
	ID             uint      `gorm:"primaryKey" json:"id"`
	Name           string    `gorm:"size:100;not null" json:"name"`
	URL            string    `gorm:"size:2048;not null" json:"url"`
	ExpectedStatus int       `gorm:"not null;default:200" json:"expected_status"`
	CreatedAt      time.Time `json:"created_at"`
}

// CheckResult is what happened when the checker visited a monitor once.
type CheckResult struct {
	ID         uint      `gorm:"primaryKey" json:"id"`
	MonitorID  uint      `gorm:"not null;index:idx_results_monitor_time,priority:1" json:"monitor_id"`
	CheckedAt  time.Time `gorm:"not null;index:idx_results_monitor_time,priority:2;index:idx_results_time" json:"checked_at"`
	IsUp       bool      `gorm:"not null" json:"is_up"`
	StatusCode int       `json:"status_code"`
	LatencyMS  int64     `json:"latency_ms"`
	Error      string    `gorm:"size:500" json:"error,omitempty"`

	// Deleting a monitor also deletes its results.
	Monitor Monitor `gorm:"constraint:OnDelete:CASCADE" json:"-"`
}

// DailySummary is one monitor's numbers for one day. The rollup job fills it.
type DailySummary struct {
	MonitorID    uint      `gorm:"primaryKey;autoIncrement:false" json:"monitor_id"`
	Day          time.Time `gorm:"primaryKey;type:date" json:"day"`
	Checks       int       `json:"checks"`
	UpChecks     int       `json:"up_checks"`
	UptimePct    float64   `json:"uptime_pct"`
	AvgLatencyMS int64     `json:"avg_latency_ms"`

	Monitor Monitor `gorm:"constraint:OnDelete:CASCADE" json:"-"`
}

// All lists every table, in the order they should be created.
func All() []any {
	return []any{&Monitor{}, &CheckResult{}, &DailySummary{}}
}
