package reports

import (
	"context"
	"io"
	"os"
	"path/filepath"
	"slices"
	"testing"
)

func TestValidName(t *testing.T) {
	tests := []struct {
		name  string
		valid bool
	}{
		{"2026-01-31.csv", true},
		{"2026-1-31.csv", false},
		{"2026-01-31.txt", false},
		{"../2026-01-31.csv", false},
		{"a/2026-01-31.csv", false},
		{"2026-01-31.csv/", false},
		{"", false},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := ValidName(tt.name); got != tt.valid {
				t.Errorf("ValidName(%q) = %v, want %v", tt.name, got, tt.valid)
			}
		})
	}
}

func TestDir(t *testing.T) {
	ctx := context.Background()
	// A folder that does not exist yet, like before the first rollup.
	d := Dir{Path: filepath.Join(t.TempDir(), "reports")}

	names, err := d.List(ctx)
	if err != nil || len(names) != 0 {
		t.Fatalf("empty store: got %v, %v", names, err)
	}

	for _, n := range []string{"2026-01-30.csv", "2026-01-31.csv", "2026-01-29.csv"} {
		if err := d.Save(ctx, n, []byte("old")); err != nil {
			t.Fatalf("save %s: %v", n, err)
		}
	}
	// Saving again replaces the file (rollup runs many times a day).
	if err := d.Save(ctx, "2026-01-31.csv", []byte("new")); err != nil {
		t.Fatalf("save again: %v", err)
	}
	// Stray files are not reports.
	os.WriteFile(filepath.Join(d.Path, "notes.txt"), []byte("x"), 0o644)

	names, err = d.List(ctx)
	if err != nil {
		t.Fatalf("list: %v", err)
	}
	want := []string{"2026-01-31.csv", "2026-01-30.csv", "2026-01-29.csv"}
	if !slices.Equal(names, want) {
		t.Errorf("List = %v, want %v", names, want)
	}

	f, err := d.Open(ctx, "2026-01-31.csv")
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	defer f.Close()
	if b, _ := io.ReadAll(f); string(b) != "new" {
		t.Errorf("content = %q, want %q", b, "new")
	}

	if _, err := d.Open(ctx, "../secret.csv"); err != ErrInvalidName {
		t.Errorf("Open with bad name: got %v, want ErrInvalidName", err)
	}
	if err := d.Save(ctx, "../x.csv", nil); err != ErrInvalidName {
		t.Errorf("Save with bad name: got %v, want ErrInvalidName", err)
	}
}
