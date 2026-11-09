package main

import (
	"context"
	"database/sql"
	"errors"
	"flag"
	"fmt"
	"net"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"syscall"
	"time"

	longrunning "example.com/praxo-longrunning"

	_ "github.com/jackc/pgx/v5/stdlib"
	_ "modernc.org/sqlite"
)

func main() {
	addr := flag.String("addr", "127.0.0.1:0", "listen address")
	state := flag.String("state", "", "state file path")
	token := flag.String("token", "", "bearer token")
	verifierSecret := flag.String("verifier-secret", "fixture-effect-secret", "effect verifier secret")
	tlsCert := flag.String("tls-cert", "", "TLS certificate path")
	tlsKey := flag.String("tls-key", "", "TLS key path")
	lockBackend := flag.String("lock-backend", "file", "lease backend: file, sqlite, postgres, or none")
	lockPath := flag.String("lock-path", "", "file lease path; defaults to <state>.lock")
	lockDSN := flag.String("lock-dsn", "", "SQLite or Postgres DSN")
	lockResource := flag.String("lock-resource", "operations", "lease resource name")
	lockTTL := flag.Duration("lock-ttl", 30*time.Second, "lease TTL")
	flag.Parse()

	if *state == "" || *token == "" {
		fmt.Fprintln(os.Stderr, "missing -state or -token")
		os.Exit(2)
	}
	if (*tlsCert == "") != (*tlsKey == "") {
		fmt.Fprintln(os.Stderr, "-tls-cert and -tls-key must be provided together")
		os.Exit(2)
	}
	if err := os.MkdirAll(filepath.Dir(*state), 0o700); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}

	hostname, _ := os.Hostname()
	owner := fmt.Sprintf("%s-%d", hostname, os.Getpid())
	var lease longrunning.Lease
	closeLease := func() {}
	switch *lockBackend {
	case "none":
	case "file":
		path := *lockPath
		if path == "" {
			path = *state + ".lock"
		}
		lease = longrunning.NewFileLease(path, *lockTTL)
	case "sqlite", "postgres":
		if *lockDSN == "" {
			fmt.Fprintln(os.Stderr, "-lock-dsn is required for sqlite/postgres")
			os.Exit(2)
		}
		driver := "sqlite"
		if *lockBackend == "postgres" {
			driver = "pgx"
		}
		db, err := sql.Open(driver, *lockDSN)
		if err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		lease, err = longrunning.NewSQLLease(context.Background(), db, driver, *lockResource, *lockTTL)
		if err != nil {
			fmt.Fprintln(os.Stderr, err)
			_ = db.Close()
			os.Exit(1)
		}
		closeLease = func() { _ = db.Close() }
	default:
		fmt.Fprintln(os.Stderr, "unknown -lock-backend")
		os.Exit(2)
	}
	defer closeLease()

	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, _ *http.Request) {
		fmt.Fprintln(w, "ok")
	})
	mux.HandleFunc("/readyz", func(w http.ResponseWriter, _ *http.Request) {
		info, err := os.Stat(filepath.Dir(*state))
		if err != nil || !info.IsDir() {
			http.Error(w, "state directory unavailable", http.StatusServiceUnavailable)
			return
		}
		fmt.Fprintln(w, "ready")
	})
	mux.Handle("/", longrunning.NewHandlerWithLease(*state, *token, *verifierSecret, lease, owner))

	listener, err := net.Listen("tcp", *addr)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	fmt.Printf("LISTEN=%s\n", listener.Addr().String())

	server := &http.Server{
		Handler:           mux,
		ReadHeaderTimeout: 5 * time.Second,
	}
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	go func() {
		<-ctx.Done()
		shutdown, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		_ = server.Shutdown(shutdown)
	}()

	if *tlsCert != "" {
		err = server.ServeTLS(listener, *tlsCert, *tlsKey)
	} else {
		err = server.Serve(listener)
	}
	if err != nil && !errors.Is(err, http.ErrServerClosed) {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
