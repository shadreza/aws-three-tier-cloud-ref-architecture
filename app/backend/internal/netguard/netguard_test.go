package netguard

import (
	"net"
	"testing"
)

func TestIsBlocked(t *testing.T) {
	tests := []struct {
		ip      string
		blocked bool
	}{
		{"8.8.8.8", false},
		{"93.184.215.14", false},
		{"2606:4700::1111", false},
		{"127.0.0.1", true},
		{"10.0.1.5", true},
		{"172.16.0.1", true},
		{"192.168.1.1", true},
		{"169.254.169.254", true}, // EC2 metadata
		{"169.254.170.2", true},   // ECS task metadata
		{"100.64.0.1", true},
		{"0.0.0.0", true},
		{"::1", true},
		{"fd00::1", true},
		{"::ffff:10.0.0.1", true}, // IPv4 hidden inside IPv6
	}

	for _, tt := range tests {
		t.Run(tt.ip, func(t *testing.T) {
			if got := IsBlocked(net.ParseIP(tt.ip)); got != tt.blocked {
				t.Errorf("IsBlocked(%s) = %v, want %v", tt.ip, got, tt.blocked)
			}
		})
	}
}

func TestDialControl(t *testing.T) {
	if err := DialControl("tcp", "8.8.8.8:443", nil); err != nil {
		t.Errorf("public address should pass, got %v", err)
	}
	if err := DialControl("tcp", "10.0.0.5:3306", nil); err == nil {
		t.Error("private address should be blocked")
	}
}

func TestValidateURL(t *testing.T) {
	tests := []struct {
		url          string
		allowPrivate bool
		ok           bool
	}{
		{"https://example.com", false, true},
		{"http://example.com/health", false, true},
		{"ftp://example.com", false, false},
		{"example.com", false, false},
		{"https://", false, false},
		{"https://user:pass@example.com", false, false},
		{"http://localhost:8080", false, false},
		{"http://127.0.0.1", false, false},
		{"http://169.254.170.2/v2/metadata", false, false},
		{"http://api:8080/api/health", true, true},
		{"http://localhost:8080", true, true},
	}

	for _, tt := range tests {
		t.Run(tt.url, func(t *testing.T) {
			err := ValidateURL(tt.url, tt.allowPrivate)
			if tt.ok && err != nil {
				t.Errorf("expected ok, got %v", err)
			}
			if !tt.ok && err == nil {
				t.Error("expected an error, got none")
			}
		})
	}
}
