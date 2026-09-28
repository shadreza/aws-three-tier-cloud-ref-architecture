package api

import "testing"

func TestNewMonitorValidate(t *testing.T) {
	tests := []struct {
		name    string
		in      newMonitor
		wantErr bool
	}{
		{"good", newMonitor{Name: "Example", URL: "https://example.com"}, false},
		{"spaces are trimmed", newMonitor{Name: "  Example  ", URL: " https://example.com "}, false},
		{"missing name", newMonitor{URL: "https://example.com"}, true},
		{"bad scheme", newMonitor{Name: "x", URL: "ftp://example.com"}, true},
		{"private address", newMonitor{Name: "x", URL: "http://10.0.0.1"}, true},
		{"status too high", newMonitor{Name: "x", URL: "https://example.com", ExpectedStatus: 700}, true},
		{"custom status", newMonitor{Name: "x", URL: "https://example.com", ExpectedStatus: 204}, false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			m, err := tt.in.validate(false)
			if tt.wantErr {
				if err == nil {
					t.Fatal("expected an error, got none")
				}
				return
			}
			if err != nil {
				t.Fatalf("unexpected error: %v", err)
			}
			if m.Name != "Example" && m.Name != "x" {
				t.Errorf("name not trimmed: %q", m.Name)
			}
			if m.ExpectedStatus == 0 {
				t.Error("expected status should default to 200")
			}
		})
	}
}
