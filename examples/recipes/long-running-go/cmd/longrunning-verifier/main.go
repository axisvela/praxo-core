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
	"syscall"
	"time"

	longrunning "example.com/praxo-longrunning"
)

func main() {
	addr := flag.String("addr", "127.0.0.1:0", "listen address")
	token := flag.String("token", os.Getenv("PRAXO_VERIFIER_TOKEN"), "bearer token")
	secret := flag.String("secret", os.Getenv("PRAXO_VERIFIER_SECRET"), "receipt signing secret")
	flag.Parse()

	if *token == "" || *secret == "" {
		fmt.Fprintln(os.Stderr, "missing -token or -secret")
		os.Exit(2)
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, _ *http.Request) {
		fmt.Fprintln(w, "ok")
	})
	mux.HandleFunc("/readyz", func(w http.ResponseWriter, _ *http.Request) {
		fmt.Fprintln(w, "ready")
	})
	mux.Handle("/", longrunning.NewVerifierHandler(*secret, *token))

	listener, err := net.Listen("tcp", *addr)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	fmt.Printf("LISTEN=%s\n", listener.Addr().String())

	server := &http.Server{Handler: mux, ReadHeaderTimeout: 5 * time.Second}
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	go func() {
		<-ctx.Done()
		shutdown, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		_ = server.Shutdown(shutdown)
	}()

	if err := server.Serve(listener); err != nil && !errors.Is(err, http.ErrServerClosed) {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
