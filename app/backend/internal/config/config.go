// Package config reads all settings from environment variables.
//
// Locally the values come from compose.yaml. On AWS they will come from the
// ECS task definition. The code does not care where they come from.
package config

import (
	"errors"
	"fmt"
	"os"
	"strconv"
	"time"
)

type Config struct {
	DBHost     string
	DBPort     string
	DBUser     string
	DBPassword string
	DBName     string
	// Path to a CA bundle. When set, the connection to MySQL uses TLS and
	// checks the server certificate against it (RDS on AWS).
	DBTLSCA string

	HTTPPort   string
	AdminToken string

	CheckTimeout        time.Duration
	CheckConcurrency    int
	AllowPrivateTargets bool

	// Reports go to S3 when ReportBucket is set, otherwise to ReportDir.
	ReportDir     string
	ReportBucket  string
	ReportPrefix  string
	RetentionDays int

	// Only used by the dev-scheduler command.
	DevCheckEvery  time.Duration
	DevRollupEvery time.Duration
}

func Load() (Config, error) {
	var errs []error

	c := Config{
		DBHost:     getString("DB_HOST", "localhost"),
		DBPort:     getString("DB_PORT", "3306"),
		DBUser:     getString("DB_USER", "uptime"),
		DBPassword: getString("DB_PASSWORD", ""),
		DBName:     getString("DB_NAME", "uptime"),
		DBTLSCA:    getString("DB_TLS_CA", ""),

		HTTPPort:   getString("HTTP_PORT", "8080"),
		AdminToken: getString("ADMIN_TOKEN", ""),

		CheckTimeout:        getDuration("CHECK_TIMEOUT", 10*time.Second, &errs),
		CheckConcurrency:    getInt("CHECK_CONCURRENCY", 10, &errs),
		AllowPrivateTargets: getBool("ALLOW_PRIVATE_TARGETS", false, &errs),

		ReportDir:     getString("REPORT_DIR", "./reports"),
		ReportBucket:  getString("REPORT_BUCKET", ""),
		ReportPrefix:  getString("REPORT_PREFIX", "reports/"),
		RetentionDays: getInt("RETENTION_DAYS", 30, &errs),

		DevCheckEvery:  getDuration("DEV_CHECK_EVERY", time.Minute, &errs),
		DevRollupEvery: getDuration("DEV_ROLLUP_EVERY", 5*time.Minute, &errs),
	}

	if c.CheckConcurrency < 1 {
		errs = append(errs, errors.New("CHECK_CONCURRENCY must be at least 1"))
	}
	if c.RetentionDays < 1 {
		errs = append(errs, errors.New("RETENTION_DAYS must be at least 1"))
	}

	return c, errors.Join(errs...)
}

func getString(key, fallback string) string {
	if v, ok := os.LookupEnv(key); ok && v != "" {
		return v
	}
	return fallback
}

func getInt(key string, fallback int, errs *[]error) int {
	v := os.Getenv(key)
	if v == "" {
		return fallback
	}
	n, err := strconv.Atoi(v)
	if err != nil {
		*errs = append(*errs, fmt.Errorf("%s must be a whole number, got %q", key, v))
		return fallback
	}
	return n
}

func getBool(key string, fallback bool, errs *[]error) bool {
	v := os.Getenv(key)
	if v == "" {
		return fallback
	}
	b, err := strconv.ParseBool(v)
	if err != nil {
		*errs = append(*errs, fmt.Errorf("%s must be true or false, got %q", key, v))
		return fallback
	}
	return b
}

func getDuration(key string, fallback time.Duration, errs *[]error) time.Duration {
	v := os.Getenv(key)
	if v == "" {
		return fallback
	}
	d, err := time.ParseDuration(v)
	if err != nil {
		*errs = append(*errs, fmt.Errorf("%s must be a duration like 30s or 5m, got %q", key, v))
		return fallback
	}
	return d
}
