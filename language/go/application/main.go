package main

import (
	"context"
	"encoding/json"
	"errors"
	"flag"
	"io"
	"log"
	"net/http"
	"os"
	"strings"
	"time"
)

func main() {
	serve := flag.Bool("serve", false, "run the HTTP service")
	addr := flag.String("addr", ":8080", "HTTP listen address")
	tenant := flag.String("tenant", tenantScope, "tenant id")
	service := flag.String("service", serviceScope, "authorized service id")
	intent := flag.String("intent", "Investigate the checkout incident and draft a review-only remediation.", "incident intent")
	flag.Parse()

	runner := NewRunner()
	if *serve {
		log.Printf("praxo ai ops listening on %s", *addr)
		log.Fatal(http.ListenAndServe(*addr, newHandler(runner, *service)))
	}

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()
	report, stats, _, err := runner.Run(ctx, *tenant, *service, *intent)
	if err != nil {
		writeJSON(os.Stderr, 0, errorJSON(err))
		os.Exit(1)
	}
	writeJSON(os.Stdout, 0, map[string]any{
		"report": report,
		"agent":  stats,
	})
}

func newHandler(runner *Runner, service string) http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("POST /api/ops/incidents", func(w http.ResponseWriter, r *http.Request) {
		tenant := r.Header.Get("X-Tenant-Id")
		if tenant == "" {
			writeJSON(w, http.StatusUnauthorized, map[string]any{"error": "TENANT_REQUIRED"})
			return
		}
		if tenant != tenantScope {
			writeJSON(w, http.StatusForbidden, map[string]any{"error": "TENANT_DENIED"})
			return
		}

		var body struct {
			Intent string `json:"intent"`
		}
		decoder := json.NewDecoder(io.LimitReader(r.Body, 1<<20))
		if err := decoder.Decode(&body); err != nil {
			writeJSON(w, http.StatusBadRequest, map[string]any{"error": "INVALID_REQUEST"})
			return
		}
		intent := strings.TrimSpace(body.Intent)
		if intent == "" || len(intent) > 500 {
			writeJSON(w, http.StatusBadRequest, map[string]any{"error": "INVALID_INTENT"})
			return
		}

		report, stats, _, err := runner.Run(r.Context(), tenant, service, intent)
		if err != nil {
			writeJSON(w, errorStatus(err), errorJSON(err))
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{
			"report": report,
			"agent":  stats,
		})
	})
	return mux
}

func errorStatus(err error) int {
	var runErr *RunError
	if errors.As(err, &runErr) {
		switch runErr.Code {
		case "AGENT_POLICY_DENIED", "AGENT_TOOL_NOT_ALLOWED":
			return http.StatusForbidden
		case "TOOL_ERROR":
			return http.StatusServiceUnavailable
		default:
			return http.StatusInternalServerError
		}
	}
	return http.StatusInternalServerError
}

func writeJSON(w io.Writer, status int, value any) {
	if response, ok := w.(http.ResponseWriter); ok {
		response.Header().Set("Content-Type", "application/json")
		if status > 0 {
			response.WriteHeader(status)
		}
	}
	encoder := json.NewEncoder(w)
	encoder.SetEscapeHTML(false)
	encoder.SetIndent("", "  ")
	_ = encoder.Encode(value)
}
