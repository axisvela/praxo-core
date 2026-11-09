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
	tokenFile := flag.String("token-file", os.Getenv("PRAXO_VERIFIER_TOKEN_FILE"), "bearer token file; re-read on each request")
	secret := flag.String("secret", os.Getenv("PRAXO_VERIFIER_SECRET"), "receipt signing secret")
	secretFile := flag.String("secret-file", os.Getenv("PRAXO_VERIFIER_SECRET_FILE"), "signing secret file; re-read on each verification")
	flag.Parse()

	if (*token == "" && *tokenFile == "") || (*secret == "" && *secretFile == "") {
		fmt.Fprintln(os.Stderr, "missing -token/-token-file or -secret/-secret-file")
		os.Exit(2)
	}
	var tokenSource longrunning.SecretSource = longrunning.StaticSecret(*token)
	if *tokenFile != "" {
		value, err := longrunning.NewFileSecret(*tokenFile)
		if err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		tokenSource = value
	}
	var secretSource longrunning.SecretSource = longrunning.StaticSecret(*secret)
	if *secretFile != "" {
		value, err := longrunning.NewFileSecret(*secretFile)
		if err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		secretSource = value
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, _ *http.Request) {
		fmt.Fprintln(w, "ok")
	})
	mux.HandleFunc("/readyz", func(w http.ResponseWriter, _ *http.Request) {
		fmt.Fprintln(w, "ready")
	})
	mux.Handle("/", longrunning.NewVerifierHandlerWithSecrets(secretSource, tokenSource))

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
