package main

import (
	"context"
	"net/http"
	"os"
	"strings"
	"testing"
	"time"
)

func contains(values []string, want string) bool {
	for _, value := range values {
		if value == want {
			return true
		}
	}
	return false
}

func ollamaAvailable(t *testing.T) {
	t.Helper()
	if os.Getenv("PRAXO_OLLAMA_MODEL") == "" {
		t.Skip("set PRAXO_OLLAMA_MODEL, for example qwen3.5:4b")
	}
	if os.Getenv("PRAXO_OLLAMA_BASE_URL") != "" {
		return
	}
	client := &http.Client{
		Timeout:   5 * time.Second,
		Transport: &http.Transport{Proxy: nil},
	}
	response, err := client.Get("http://127.0.0.1:11434/api/tags")
	if err != nil {
		t.Skipf("ollama is not reachable: %v", err)
	}
	defer response.Body.Close()
	if response.StatusCode >= 300 {
		t.Skipf("ollama returned %s", response.Status)
	}
}

func TestRepresentativeChain(t *testing.T) {
	ollamaAvailable(t)
	baseURL := os.Getenv("PRAXO_OLLAMA_BASE_URL")
	if baseURL == "" {
		baseURL = "http://127.0.0.1:11434/v1"
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
	defer cancel()
	result, err := runChain(ctx, config{
		BaseURL: baseURL,
		Model:   os.Getenv("PRAXO_OLLAMA_MODEL"),
		APIKey:  os.Getenv("PRAXO_OLLAMA_API_KEY"),
	})
	if err != nil {
		t.Fatal(err)
	}
	if strings.TrimSpace(result.Output) == "" {
		t.Fatalf("empty model output: %#v", result)
	}
	if result.Effects["parent"] != 1 || result.Effects["child"] != 1 {
		t.Fatalf("effects = %#v", result.Effects)
	}
	if result.ChildCalls < 2 {
		t.Fatalf("child calls = %d", result.ChildCalls)
	}
	if result.DeniedEffect != 0 {
		t.Fatalf("denied path produced %d effects", result.DeniedEffect)
	}
	if !strings.Contains(result.DenialError, "denied") &&
		!strings.Contains(result.DenialError, "policy") {
		t.Fatalf("denial error = %q", result.DenialError)
	}
	for _, span := range []string{"praxo.run.started", "praxo.tool.call", "praxo.run.completed"} {
		if !contains(result.Spans, span) {
			t.Fatalf("missing span %s in %#v", span, result.Spans)
		}
	}
	for _, kind := range []string{"run.started", "tool.call", "run.completed"} {
		if !contains(result.Events, kind) {
			t.Fatalf("missing event %s in %#v", kind, result.Events)
		}
	}
}

func TestDenialZeroEffect(t *testing.T) {
	effects := newEffectLog()
	record, cleanup, err := newMCPRecord(context.Background(), effects)
	if err != nil {
		t.Fatal(err)
	}
	defer cleanup()
	count, message, err := runDenial(context.Background(), record, effects, nil)
	if err == nil {
		t.Fatal("denial path unexpectedly succeeded")
	}
	if count != 0 {
		t.Fatalf("denied path produced %d effects", count)
	}
	if !strings.Contains(message, "denied") && !strings.Contains(message, "policy") {
		t.Fatalf("denial error = %q", message)
	}
}
