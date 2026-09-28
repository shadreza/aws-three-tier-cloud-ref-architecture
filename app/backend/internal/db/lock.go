package db

import (
	"context"
	"database/sql"
	"errors"
	"fmt"

	"gorm.io/gorm"
)

// ErrLocked means another copy of the job is still running.
var ErrLocked = errors.New("another run is still in progress")

// WithLock runs fn only if no other process holds the named lock.
//
// Scheduled jobs can overlap: if a check run is slow, the next one may start
// before it ends. MySQL's GET_LOCK gives us a simple "only one at a time" rule
// that works across containers. The lock belongs to one connection, so we
// hold a single connection for the whole run.
func WithLock(ctx context.Context, gdb *gorm.DB, name string, fn func() error) error {
	sqlDB, err := gdb.DB()
	if err != nil {
		return err
	}
	conn, err := sqlDB.Conn(ctx)
	if err != nil {
		return fmt.Errorf("get connection for lock: %w", err)
	}
	defer conn.Close()

	var got sql.NullInt64
	if err := conn.QueryRowContext(ctx, "SELECT GET_LOCK(?, 0)", name).Scan(&got); err != nil {
		return fmt.Errorf("take lock %q: %w", name, err)
	}
	if !got.Valid || got.Int64 != 1 {
		return ErrLocked
	}
	defer conn.ExecContext(context.Background(), "SELECT RELEASE_LOCK(?)", name)

	return fn()
}
