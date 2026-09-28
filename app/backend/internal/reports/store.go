// Package reports stores the daily CSV reports. Everything goes through the
// Store interface, so the local folder can later be swapped for S3 without
// touching the API or the rollup job.
package reports

import (
	"context"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"regexp"
	"slices"
)

// ErrInvalidName is returned for any name that is not YYYY-MM-DD.csv.
var ErrInvalidName = errors.New("report name must look like 2026-01-31.csv")

// ErrNotFound means there is no report with that name.
var ErrNotFound = errors.New("report not found")

// Only this exact shape is allowed, so a name can never contain "/" or ".."
// and escape the reports folder.
var namePattern = regexp.MustCompile(`^\d{4}-\d{2}-\d{2}\.csv$`)

// ValidName reports whether name is a safe report file name.
func ValidName(name string) bool {
	return namePattern.MatchString(name)
}

// Store is where reports live.
type Store interface {
	// Save writes a report, replacing it if it already exists.
	Save(ctx context.Context, name string, data []byte) error
	// List returns report names, newest first.
	List(ctx context.Context) ([]string, error)
	// Open returns the report's contents, or ErrNotFound. The caller must
	// close it.
	Open(ctx context.Context, name string) (io.ReadCloser, error)
}

// Dir keeps reports as files in a local folder (a Docker volume locally).
type Dir struct {
	Path string
}

func (d Dir) Save(ctx context.Context, name string, data []byte) error {
	if !ValidName(name) {
		return ErrInvalidName
	}
	if err := os.MkdirAll(d.Path, 0o755); err != nil {
		return fmt.Errorf("create reports folder: %w", err)
	}

	// Write to a temporary file, then rename it. A rename is atomic, so the
	// API never serves a half-written report while rollup is running.
	tmp, err := os.CreateTemp(d.Path, ".tmp-*")
	if err != nil {
		return fmt.Errorf("create temp report: %w", err)
	}
	defer os.Remove(tmp.Name()) // no-op after a successful rename

	if _, err := tmp.Write(data); err != nil {
		tmp.Close()
		return fmt.Errorf("write report %s: %w", name, err)
	}
	if err := tmp.Close(); err != nil {
		return fmt.Errorf("close report %s: %w", name, err)
	}
	if err := os.Rename(tmp.Name(), filepath.Join(d.Path, name)); err != nil {
		return fmt.Errorf("save report %s: %w", name, err)
	}
	return nil
}

func (d Dir) List(ctx context.Context) ([]string, error) {
	entries, err := os.ReadDir(d.Path)
	if errors.Is(err, os.ErrNotExist) {
		return []string{}, nil // no rollup has run yet
	}
	if err != nil {
		return nil, fmt.Errorf("read reports folder: %w", err)
	}

	names := []string{}
	for _, e := range entries {
		if !e.IsDir() && ValidName(e.Name()) {
			names = append(names, e.Name())
		}
	}
	// YYYY-MM-DD sorts by date as plain text.
	slices.Sort(names)
	slices.Reverse(names)
	return names, nil
}

func (d Dir) Open(ctx context.Context, name string) (io.ReadCloser, error) {
	if !ValidName(name) {
		return nil, ErrInvalidName
	}
	f, err := os.Open(filepath.Join(d.Path, name))
	if errors.Is(err, os.ErrNotExist) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("open report %s: %w", name, err)
	}
	return f, nil
}
