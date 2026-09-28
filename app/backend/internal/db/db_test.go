package db

import (
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/pem"
	"math/big"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"uptime/internal/config"
)

func TestBuildDSN(t *testing.T) {
	cfg := config.Config{DBHost: "db.example", DBPort: "3306", DBUser: "u", DBPassword: "p@ss:word/", DBName: "uptime"}

	dsn, err := buildDSN(cfg)
	if err != nil {
		t.Fatal(err)
	}
	if strings.Contains(dsn, "tls=") {
		t.Errorf("no CA set, but DSN asks for TLS: %s", dsn)
	}

	// A throwaway CA certificate stands in for the RDS bundle.
	key, _ := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	tmpl := &x509.Certificate{
		SerialNumber:          big.NewInt(1),
		Subject:               pkix.Name{CommonName: "test CA"},
		NotBefore:             time.Now(),
		NotAfter:              time.Now().Add(time.Hour),
		IsCA:                  true,
		BasicConstraintsValid: true,
	}
	der, err := x509.CreateCertificate(rand.Reader, tmpl, tmpl, &key.PublicKey, key)
	if err != nil {
		t.Fatal(err)
	}
	ca := filepath.Join(t.TempDir(), "ca.pem")
	os.WriteFile(ca, pem.EncodeToMemory(&pem.Block{Type: "CERTIFICATE", Bytes: der}), 0o644)

	cfg.DBTLSCA = ca
	dsn, err = buildDSN(cfg)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(dsn, "tls=custom") {
		t.Errorf("CA set, but DSN does not use TLS: %s", dsn)
	}

	cfg.DBTLSCA = filepath.Join(t.TempDir(), "missing.pem")
	if _, err := buildDSN(cfg); err == nil {
		t.Error("missing CA file should be an error")
	}
}
