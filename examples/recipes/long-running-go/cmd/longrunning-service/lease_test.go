package main

import (
	"context"
	"database/sql"
	"path/filepath"
	"testing"
	"time"

	longrunning "example.com/praxo-longrunning"

	_ "modernc.org/sqlite"
)

func TestSQLLeaseSerializes(t *testing.T) {
	db := openSQLite(t, "lease.db")
	lease, err := longrunning.NewSQLLease(context.Background(), db, "sqlite", "operations", time.Second)
	if err != nil {
		t.Fatal(err)
	}
	release, err := lease.Acquire(context.Background(), "a")
	if err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 100*time.Millisecond)
	defer cancel()
	if _, err := lease.Acquire(ctx, "b"); err == nil {
		t.Fatal("second SQL lease acquisition succeeded")
	}
	release()
	release, err = lease.Acquire(context.Background(), "b")
	if err != nil {
		t.Fatal(err)
	}
	release()
}

func TestSQLLeaseExpires(t *testing.T) {
	db := openSQLite(t, "lease.db")
	lease, err := longrunning.NewSQLLease(context.Background(), db, "sqlite", "operations", 50*time.Millisecond)
	if err != nil {
		t.Fatal(err)
	}
	release, err := lease.Acquire(context.Background(), "a")
	if err != nil {
		t.Fatal(err)
	}
	defer release()
	time.Sleep(60 * time.Millisecond)
	releaseB, err := lease.Acquire(context.Background(), "b")
	if err != nil {
		t.Fatal(err)
	}
	releaseB()
}

func openSQLite(t *testing.T, name string) *sql.DB {
	t.Helper()
	path := filepath.Join(t.TempDir(), name)
	db, err := sql.Open("sqlite", "file:"+path+"?_pragma=busy_timeout(5000)")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = db.Close() })
	return db
}
