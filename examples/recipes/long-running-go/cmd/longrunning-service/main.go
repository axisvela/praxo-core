package main

import (
	"context"
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
)

func main() {
	addr := flag.String("addr", "127.0.0.1:0", "listen address")
	state := flag.String("state", "", "state file path")
	token := flag.String("token", "", "bearer token")
	verifierSecret := flag.String("verifier-secret", "fixture-effect-secret", "effect verifier secret")
	tlsCert := flag.String("tls-cert", "", "TLS certificate path")
	tlsKey := flag.String("tls-key", "", "TLS key path")
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
	mux.Handle("/", longrunning.NewHandler(*state, *token, *verifierSecret))

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
