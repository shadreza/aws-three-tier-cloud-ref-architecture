package api

import (
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"strconv"
	"strings"
	"time"

	"uptime/internal/models"
	"uptime/internal/netguard"
	"uptime/internal/reports"
)

// monitorView is a monitor plus its latest status, as the frontend shows it.
type monitorView struct {
	models.Monitor
	Status        string     `json:"status"` // "up", "down" or "unknown"
	LastCheckedAt *time.Time `json:"last_checked_at"`
	LastLatencyMS *int64     `json:"last_latency_ms"`
	LastError     string     `json:"last_error,omitempty"`
	Uptime24h     *float64   `json:"uptime_24h"`
}

func (s *Server) listMonitors(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	var monitors []models.Monitor
	if err := s.db.WithContext(ctx).Order("id").Find(&monitors).Error; err != nil {
		s.serverError(w, err)
		return
	}

	// The newest result for each monitor.
	var latest []models.CheckResult
	err := s.db.WithContext(ctx).Raw(`
		SELECT r.* FROM check_results r
		JOIN (SELECT monitor_id, MAX(id) AS id FROM check_results GROUP BY monitor_id) newest
		  ON newest.id = r.id`).Scan(&latest).Error
	if err != nil {
		s.serverError(w, err)
		return
	}
	latestByID := make(map[uint]models.CheckResult, len(latest))
	for _, res := range latest {
		latestByID[res.MonitorID] = res
	}

	// How many checks passed in the last 24 hours.
	var counts []struct {
		MonitorID uint
		Checks    int
		UpChecks  int
	}
	err = s.db.WithContext(ctx).Model(&models.CheckResult{}).
		Select("monitor_id, COUNT(*) AS checks, SUM(CASE WHEN is_up THEN 1 ELSE 0 END) AS up_checks").
		Where("checked_at >= ?", time.Now().UTC().Add(-24*time.Hour)).
		Group("monitor_id").
		Scan(&counts).Error
	if err != nil {
		s.serverError(w, err)
		return
	}
	uptimeByID := make(map[uint]float64, len(counts))
	for _, c := range counts {
		uptimeByID[c.MonitorID] = float64(c.UpChecks) / float64(c.Checks) * 100
	}

	views := make([]monitorView, len(monitors))
	for i, m := range monitors {
		v := monitorView{Monitor: m, Status: "unknown"}
		if res, ok := latestByID[m.ID]; ok {
			v.Status = "down"
			if res.IsUp {
				v.Status = "up"
			}
			v.LastCheckedAt = &res.CheckedAt
			v.LastLatencyMS = &res.LatencyMS
			v.LastError = res.Error
		}
		if pct, ok := uptimeByID[m.ID]; ok {
			v.Uptime24h = &pct
		}
		views[i] = v
	}

	writeJSON(w, http.StatusOK, views)
}

type newMonitor struct {
	Name           string `json:"name"`
	URL            string `json:"url"`
	ExpectedStatus int    `json:"expected_status"`
}

// validate checks the input and turns it into a Monitor ready to save.
func (in newMonitor) validate(allowPrivate bool) (models.Monitor, error) {
	name := strings.TrimSpace(in.Name)
	if name == "" {
		return models.Monitor{}, errors.New("name is required")
	}
	if len(name) > 100 {
		return models.Monitor{}, errors.New("name must be 100 characters or less")
	}

	url := strings.TrimSpace(in.URL)
	if len(url) > 2048 {
		return models.Monitor{}, errors.New("URL is too long")
	}
	if err := netguard.ValidateURL(url, allowPrivate); err != nil {
		return models.Monitor{}, err
	}

	status := in.ExpectedStatus
	if status == 0 {
		status = http.StatusOK
	}
	if status < 100 || status > 599 {
		return models.Monitor{}, errors.New("expected status must be between 100 and 599")
	}

	return models.Monitor{Name: name, URL: url, ExpectedStatus: status}, nil
}

func (s *Server) createMonitor(w http.ResponseWriter, r *http.Request) {
	var in newMonitor
	body := http.MaxBytesReader(w, r.Body, 64<<10)
	if err := json.NewDecoder(body).Decode(&in); err != nil {
		writeError(w, http.StatusBadRequest, "request body must be JSON")
		return
	}

	monitor, err := in.validate(s.allowPrivate)
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	if err := s.db.WithContext(r.Context()).Create(&monitor).Error; err != nil {
		s.serverError(w, err)
		return
	}

	slog.Info("monitor created", "id", monitor.ID, "url", monitor.URL)
	writeJSON(w, http.StatusCreated, monitor)
}

func (s *Server) deleteMonitor(w http.ResponseWriter, r *http.Request) {
	id, ok := monitorID(w, r)
	if !ok {
		return
	}
	res := s.db.WithContext(r.Context()).Delete(&models.Monitor{}, id)
	if res.Error != nil {
		s.serverError(w, res.Error)
		return
	}
	if res.RowsAffected == 0 {
		writeError(w, http.StatusNotFound, "monitor not found")
		return
	}
	slog.Info("monitor deleted", "id", id)
	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) listResults(w http.ResponseWriter, r *http.Request) {
	id, ok := monitorID(w, r)
	if !ok || !s.monitorExists(w, r, id) {
		return
	}

	limit := 50
	if v := r.URL.Query().Get("limit"); v != "" {
		n, err := strconv.Atoi(v)
		if err != nil || n < 1 || n > 500 {
			writeError(w, http.StatusBadRequest, "limit must be between 1 and 500")
			return
		}
		limit = n
	}

	results := []models.CheckResult{}
	err := s.db.WithContext(r.Context()).
		Where("monitor_id = ?", id).
		Order("id DESC").
		Limit(limit).
		Find(&results).Error
	if err != nil {
		s.serverError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, results)
}

func (s *Server) listDaily(w http.ResponseWriter, r *http.Request) {
	id, ok := monitorID(w, r)
	if !ok || !s.monitorExists(w, r, id) {
		return
	}

	summaries := []models.DailySummary{}
	err := s.db.WithContext(r.Context()).
		Where("monitor_id = ?", id).
		Order("day DESC").
		Limit(30).
		Find(&summaries).Error
	if err != nil {
		s.serverError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, summaries)
}

func (s *Server) listReports(w http.ResponseWriter, r *http.Request) {
	names, err := s.reports.List(r.Context())
	if err != nil {
		s.serverError(w, err)
		return
	}
	type report struct {
		Name string `json:"name"`
		Day  string `json:"day"`
	}
	out := make([]report, len(names))
	for i, n := range names {
		out[i] = report{Name: n, Day: strings.TrimSuffix(n, ".csv")}
	}
	writeJSON(w, http.StatusOK, out)
}

func (s *Server) getReport(w http.ResponseWriter, r *http.Request) {
	name := r.PathValue("name")
	if !reports.ValidName(name) {
		writeError(w, http.StatusBadRequest, reports.ErrInvalidName.Error())
		return
	}
	f, err := s.reports.Open(r.Context(), name)
	if err != nil {
		writeError(w, http.StatusNotFound, "report not found")
		return
	}
	defer f.Close()

	w.Header().Set("Content-Type", "text/csv; charset=utf-8")
	w.Header().Set("Content-Disposition", `attachment; filename="uptime-`+name+`"`)
	io.Copy(w, f)
}

func monitorID(w http.ResponseWriter, r *http.Request) (uint, bool) {
	id, err := strconv.ParseUint(r.PathValue("id"), 10, 32)
	if err != nil || id == 0 {
		writeError(w, http.StatusBadRequest, "monitor id must be a positive number")
		return 0, false
	}
	return uint(id), true
}

func (s *Server) monitorExists(w http.ResponseWriter, r *http.Request, id uint) bool {
	var count int64
	if err := s.db.WithContext(r.Context()).Model(&models.Monitor{}).Where("id = ?", id).Count(&count).Error; err != nil {
		s.serverError(w, err)
		return false
	}
	if count == 0 {
		writeError(w, http.StatusNotFound, "monitor not found")
		return false
	}
	return true
}

// serverError logs the real error and sends the user a plain message.
// Database errors can contain details we do not want to show.
func (s *Server) serverError(w http.ResponseWriter, err error) {
	slog.Error("request failed", "error", err)
	writeError(w, http.StatusInternalServerError, "something went wrong on our side")
}
