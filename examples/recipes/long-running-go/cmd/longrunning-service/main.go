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
	"sync/atomic"
	"syscall"
	"time"

	longrunning "example.com/praxo-longrunning"

	_ "github.com/jackc/pgx/v5/stdlib"
	_ "modernc.org/sqlite"
)

func main() {
	verifierDefault := os.Getenv("PRAXO_VERIFIER_SECRET")
	if verifierDefault == "" {
		verifierDefault = "fixture-effect-secret"
	}
	addr := flag.String("addr", "127.0.0.1:0", "listen address")
	state := flag.String("state", os.Getenv("PRAXO_STATE"), "state file path")
	token := flag.String("token", os.Getenv("PRAXO_TOKEN"), "bearer token")
	tokenFile := flag.String("token-file", os.Getenv("PRAXO_TOKEN_FILE"), "bearer token file; re-read on each request")
	verifierSecret := flag.String("verifier-secret", verifierDefault, "effect verifier secret")
	verifierSecretFile := flag.String("verifier-secret-file", os.Getenv("PRAXO_VERIFIER_SECRET_FILE"), "verifier secret file; re-read on each verification")
	tlsCert := flag.String("tls-cert", "", "TLS certificate path")
	tlsKey := flag.String("tls-key", "", "TLS key path")
	lockBackend := flag.String("lock-backend", "file", "lease backend: file, sqlite, postgres, or none")
	lockPath := flag.String("lock-path", "", "file lease path; defaults to <state>.lock")
	lockDSN := flag.String("lock-dsn", os.Getenv("PRAXO_LOCK_DSN"), "SQLite or Postgres DSN")
	lockResource := flag.String("lock-resource", "operations", "lease resource name")
	lockTTL := flag.Duration("lock-ttl", 30*time.Second, "lease TTL")
	flag.Parse()

	if *state == "" || (*token == "" && *tokenFile == "") {
		fmt.Fprintln(os.Stderr, "missing -state or -token/-token-file")
		os.Exit(2)
	}
	var tokenSource longrunning.SecretSource = longrunning.StaticSecret(*token)
	if *tokenFile != "" {
		secret, err := longrunning.NewFileSecret(*tokenFile)
		if err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		tokenSource = secret
	}
	var verifierSource longrunning.SecretSource = longrunning.StaticSecret(*verifierSecret)
	if *verifierSecretFile != "" {
		secret, err := longrunning.NewFileSecret(*verifierSecretFile)
		if err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		verifierSource = secret
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
	mux.Handle("/", longrunning.NewHandlerWithSecrets(*state, tokenSource, verifierSource, lease, owner))

	var requests, errorsCount, operations atomic.Int64
	mux.HandleFunc("/metrics", func(w http.ResponseWriter, _ *http.Request) {
		fmt.Fprintf(w, "# TYPE praxo_longrunning_http_requests_total counter\npraxo_longrunning_http_requests_total %d\n", requests.Load())
		fmt.Fprintf(w, "# TYPE praxo_longrunning_http_errors_total counter\npraxo_longrunning_http_errors_total %d\n", errorsCount.Load())
		fmt.Fprintf(w, "# TYPE praxo_longrunning_operations_total counter\npraxo_longrunning_operations_total %d\n", operations.Load())
	})
	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		requests.Add(1)
		recorder := &statusRecorder{ResponseWriter: w, status: http.StatusOK}
		mux.ServeHTTP(recorder, r)
		if recorder.status >= http.StatusBadRequest {
			errorsCount.Add(1)
		}
		if r.Method == http.MethodPost && r.URL.Path == "/operations" && recorder.status == http.StatusOK {
			operations.Add(1)
		}
	})

	listener, err := net.Listen("tcp", *addr)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	fmt.Printf("LISTEN=%s\n", listener.Addr().String())

	server := &http.Server{
		Handler:           handler,
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

type statusRecorder struct {
	http.ResponseWriter
	status int
}

func (r *statusRecorder) WriteHeader(status int) {
	r.status = status
	r.ResponseWriter.WriteHeader(status)
}
