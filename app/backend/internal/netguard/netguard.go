// Package netguard stops the checker from reaching private networks.
//
// Anyone who can add a monitor chooses a URL that our server will visit.
// Without this guard they could point it at http://169.254.170.2 (the ECS
// task metadata endpoint), at our database, or at anything else inside the
// VPC. That attack is called SSRF (server-side request forgery).
package netguard

import (
	"errors"
	"fmt"
	"net"
	"net/url"
	"strings"
	"syscall"
)

// 100.64.0.0/10 is shared address space used inside some cloud networks.
var sharedAddressSpace = &net.IPNet{IP: net.IPv4(100, 64, 0, 0), Mask: net.CIDRMask(10, 32)}

// IsBlocked reports whether ip is private, internal or otherwise not a
// normal public internet address.
func IsBlocked(ip net.IP) bool {
	return ip.IsLoopback() ||
		ip.IsPrivate() ||
		ip.IsLinkLocalUnicast() || // includes 169.254.0.0/16, the metadata endpoints
		ip.IsLinkLocalMulticast() ||
		ip.IsMulticast() ||
		ip.IsUnspecified() ||
		sharedAddressSpace.Contains(ip)
}

// DialControl is plugged into net.Dialer. It runs after the DNS lookup and
// right before the connection opens, so it checks the real IP address.
// Checking only the hostname in the URL is not enough: a public-looking name
// can point to a private IP.
func DialControl(network, address string, _ syscall.RawConn) error {
	host, _, err := net.SplitHostPort(address)
	if err != nil {
		return err
	}
	ip := net.ParseIP(host)
	if ip == nil || IsBlocked(ip) {
		return fmt.Errorf("blocked: %s is a private or internal address", host)
	}
	return nil
}

// ValidateURL gives a friendly error early, when a monitor is created.
// DialControl is still the real protection at check time.
func ValidateURL(raw string, allowPrivate bool) error {
	u, err := url.Parse(strings.TrimSpace(raw))
	if err != nil {
		return errors.New("that is not a valid URL")
	}
	if u.Scheme != "http" && u.Scheme != "https" {
		return errors.New("URL must start with http:// or https://")
	}
	if u.Hostname() == "" {
		return errors.New("URL needs a host, like example.com")
	}
	if u.User != nil {
		return errors.New("URL must not contain a username or password")
	}
	if allowPrivate {
		return nil
	}

	host := strings.ToLower(u.Hostname())
	if host == "localhost" || strings.HasSuffix(host, ".localhost") {
		return errors.New("private and internal addresses are not allowed")
	}
	if ip := net.ParseIP(host); ip != nil && IsBlocked(ip) {
		return errors.New("private and internal addresses are not allowed")
	}
	return nil
}
