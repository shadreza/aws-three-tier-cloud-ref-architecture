// Package db opens the MySQL connection and creates the tables.
package db

import (
	"context"
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
	dsn := buildDSN(cfg)
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
func buildDSN(cfg config.Config) string {
	c := mysql.NewConfig()
	c.User = cfg.DBUser
	c.Passwd = cfg.DBPassword
	c.Net = "tcp"
	c.Addr = net.JoinHostPort(cfg.DBHost, cfg.DBPort)
	c.DBName = cfg.DBName
	c.ParseTime = true
	c.Loc = time.UTC
	return c.FormatDSN()
}
