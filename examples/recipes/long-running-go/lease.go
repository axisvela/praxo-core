package longrunning

import (
	"context"
	"database/sql"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"
)

type Lease interface {
	Acquire(ctx context.Context, owner string) (func(), error)
}

type FileLease struct {
	path  string
	ttl   time.Duration
	retry time.Duration
}

func NewFileLease(path string, ttl time.Duration) *FileLease {
	if ttl <= 0 {
		ttl = 30 * time.Second
	}
	return &FileLease{path: path, ttl: ttl, retry: 10 * time.Millisecond}
}

func (l *FileLease) Acquire(ctx context.Context, owner string) (func(), error) {
	if err := os.MkdirAll(filepath.Dir(l.path), 0o700); err != nil {
		return nil, err
	}
	for {
		file, err := os.OpenFile(l.path, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0o600)
		if err == nil {
			_, writeErr := fmt.Fprintln(file, owner)
			closeErr := file.Close()
			if writeErr != nil {
				_ = os.Remove(l.path)
				return nil, writeErr
			}
			if closeErr != nil {
				_ = os.Remove(l.path)
				return nil, closeErr
			}
			return func() { releaseFileLease(l.path, owner) }, nil
		}
		if !os.IsExist(err) {
			return nil, err
		}
		if info, statErr := os.Stat(l.path); statErr == nil && time.Since(info.ModTime()) > l.ttl {
			_ = os.Remove(l.path)
			continue
		}
		select {
		case <-ctx.Done():
			return nil, ctx.Err()
		case <-time.After(l.retry):
		}
	}
}

func releaseFileLease(path, owner string) {
	data, err := os.ReadFile(path)
	if err != nil {
		return
	}
	if strings.SplitN(string(data), "\n", 2)[0] == owner {
		_ = os.Remove(path)
	}
}

type SQLLease struct {
	db       *sql.DB
	driver   string
	resource string
	ttl      time.Duration
	retry    time.Duration
}

func NewSQLLease(ctx context.Context, db *sql.DB, driver, resource string, ttl time.Duration) (*SQLLease, error) {
	if ttl <= 0 {
		ttl = 30 * time.Second
	}
	lease := &SQLLease{
		db:       db,
		driver:   driver,
		resource: resource,
		ttl:      ttl,
		retry:    10 * time.Millisecond,
	}
	if _, err := db.ExecContext(ctx, rebind("CREATE TABLE IF NOT EXISTS praxo_leases (name TEXT PRIMARY KEY, owner TEXT, expires_at BIGINT NOT NULL DEFAULT 0)", driver)); err != nil {
		return nil, err
	}
	return lease, nil
}

func (l *SQLLease) Acquire(ctx context.Context, owner string) (func(), error) {
	for {
		now := time.Now().UnixMilli()
		deadline := now + l.ttl.Milliseconds()
		if _, err := l.db.ExecContext(ctx, rebind("INSERT INTO praxo_leases(name, owner, expires_at) VALUES(?, NULL, 0) ON CONFLICT(name) DO NOTHING", l.driver), l.resource); err != nil {
			return nil, err
		}
		result, err := l.db.ExecContext(ctx, rebind("UPDATE praxo_leases SET owner=?, expires_at=? WHERE name=? AND (owner IS NULL OR expires_at < ?)", l.driver), owner, deadline, l.resource, now)
		if err != nil {
			return nil, err
		}
		rows, err := result.RowsAffected()
		if err != nil {
			return nil, err
		}
		if rows == 1 {
			return func() {
				_, _ = l.db.ExecContext(context.Background(), rebind("UPDATE praxo_leases SET owner=NULL, expires_at=0 WHERE name=? AND owner=?", l.driver), l.resource, owner)
			}, nil
		}
		select {
		case <-ctx.Done():
			return nil, ctx.Err()
		case <-time.After(l.retry):
		}
	}
}

func rebind(query, driver string) string {
	if driver != "pgx" {
		return query
	}
	var builder strings.Builder
	index := 1
	for _, character := range query {
		if character == '?' {
			fmt.Fprintf(&builder, "$%d", index)
			index++
			continue
		}
		builder.WriteRune(character)
	}
	return builder.String()
}
