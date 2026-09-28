// Package db opens the MySQL connection and creates the tables.
package db

import (
	"context"
	"crypto/tls"
	"crypto/x509"
	"fmt"
	"log"
	"log/slog"
	"net"
	"os"
	"time"

	"github.com/go-sql-driver/mysql"
	gormmysql "gorm.io/driver/mysql"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"

	"uptime/internal/config"
	"uptime/internal/models"
)

// Open connects to MySQL. It tries a few times because the database can take
// a little while to accept connections when it has just started.
func Open(ctx context.Context, cfg config.Config) (*gorm.DB, error) {
	dsn, err := buildDSN(cfg)
	if err != nil {
		return nil, err
	}
	gormLogger := logger.New(log.New(os.Stdout, "", log.LstdFlags), logger.Config{
		SlowThreshold:             500 * time.Millisecond,
		LogLevel:                  logger.Warn,
		IgnoreRecordNotFoundError: true,
	})

	var lastErr error
	for attempt := 1; attempt <= 10; attempt++ {
		gdb, err := gorm.Open(gormmysql.Open(dsn), &gorm.Config{Logger: gormLogger})
		if err == nil {
			sqlDB, dbErr := gdb.DB()
			if dbErr != nil {
				return nil, dbErr
			}
			if err = sqlDB.PingContext(ctx); err == nil {
				sqlDB.SetMaxOpenConns(10)
				sqlDB.SetMaxIdleConns(5)
				sqlDB.SetConnMaxLifetime(5 * time.Minute)
				return gdb, nil
			}
		}

		lastErr = err
		slog.Warn("database not ready yet, trying again", "attempt", attempt, "error", err)
		select {
		case <-ctx.Done():
			return nil, ctx.Err()
		case <-time.After(3 * time.Second):
		}
	}
	return nil, fmt.Errorf("connect to database: %w", lastErr)
}

// Migrate creates any missing tables and columns. It never drops anything.
func Migrate(gdb *gorm.DB) error {
	return gdb.AutoMigrate(models.All()...)
}

// buildDSN uses the driver's own formatter so passwords with odd characters
// (RDS generates those) are escaped correctly.
func buildDSN(cfg config.Config) (string, error) {
	c := mysql.NewConfig()
	c.User = cfg.DBUser
	c.Passwd = cfg.DBPassword
	c.Net = "tcp"
	c.Addr = net.JoinHostPort(cfg.DBHost, cfg.DBPort)
	c.DBName = cfg.DBName
	c.ParseTime = true
	c.Loc = time.UTC

	if cfg.DBTLSCA != "" {
		// RDS certificates are signed by Amazon's own CA, which is not in the
		// usual trust store, so we load its bundle. Checking the name as well
		// means a machine pretending to be the database is refused.
		pem, err := os.ReadFile(cfg.DBTLSCA)
		if err != nil {
			return "", fmt.Errorf("read DB_TLS_CA: %w", err)
		}
		roots := x509.NewCertPool()
		if !roots.AppendCertsFromPEM(pem) {
			return "", fmt.Errorf("DB_TLS_CA %s has no certificates", cfg.DBTLSCA)
		}
		err = mysql.RegisterTLSConfig("custom", &tls.Config{
			RootCAs:    roots,
			ServerName: cfg.DBHost,
			MinVersion: tls.VersionTLS12,
		})
		if err != nil {
			return "", fmt.Errorf("register TLS config: %w", err)
		}
		c.TLSConfig = "custom"
	}
	return c.FormatDSN(), nil
}
