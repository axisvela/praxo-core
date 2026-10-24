package httpclient

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"sync/atomic"
	"testing"
)

func TestGETRetriesServerErrors(t *testing.T) {
	var calls atomic.Int32
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		if calls.Add(1) < 3 {
			http.Error(w, "temporary", http.StatusServiceUnavailable)
			return
		}
		_, _ = w.Write([]byte("ok"))
	}))
	defer srv.Close()

	c := New(Config{BaseURL: srv.URL, MaxAttempts: 3})
	resp, err := c.Do(context.Background(), Request{Method: http.MethodGet, Path: "/"})
	if err != nil {
		t.Fatal(err)
	}
	if calls.Load() != 3 || string(resp.Body) != "ok" {
		t.Fatalf("calls = %d body = %q", calls.Load(), resp.Body)
	}
}

func TestPOSTDoesNotRetryServerErrors(t *testing.T) {
	var calls atomic.Int32
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		calls.Add(1)
		http.Error(w, "temporary", http.StatusServiceUnavailable)
	}))
	defer srv.Close()

	c := New(Config{BaseURL: srv.URL, MaxAttempts: 3})
	resp, err := c.Do(context.Background(), Request{Method: http.MethodPost, Path: "/"})
	if err != nil {
		t.Fatal(err)
	}
	if resp.Status != http.StatusServiceUnavailable {
		t.Fatalf("status = %d", resp.Status)
	}
	if calls.Load() != 1 {
		t.Fatalf("POST retried %d times", calls.Load())
	}
}

func TestCancellationStopsRetryBackoff(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		cancel()
		http.Error(w, "temporary", http.StatusServiceUnavailable)
	}))
	defer srv.Close()

	c := New(Config{BaseURL: srv.URL, MaxAttempts: 3})
	_, err := c.Do(ctx, Request{Method: http.MethodGet, Path: "/"})
	if !errors.Is(err, context.Canceled) {
		t.Fatalf("err = %v, want context.Canceled", err)
	}
}

func TestNegativeMaxBodyDisablesBound(t *testing.T) {
	payload := make([]byte, 2048)
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write(payload)
	}))
	defer srv.Close()

	c := New(Config{BaseURL: srv.URL, MaxBodyBytes: -1})
	resp, err := c.Do(context.Background(), Request{Method: http.MethodGet, Path: "/"})
	if err != nil {
		t.Fatal(err)
	}
	if len(resp.Body) != len(payload) {
		t.Fatalf("body length = %d", len(resp.Body))
	}
}

func TestRequestHeadersOverrideConfig(t *testing.T) {
	var got string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		got = r.Header.Get("X-Test")
		_, _ = w.Write([]byte("ok"))
	}))
	defer srv.Close()

	c := New(Config{BaseURL: srv.URL, Headers: map[string]string{"X-Test": "config"}})
	if _, err := c.Do(context.Background(), Request{
		Method: http.MethodGet, Path: "/", Headers: map[string]string{"X-Test": "request"},
	}); err != nil {
		t.Fatal(err)
	}
	if got != "request" {
		t.Fatalf("header = %q", got)
	}
}

func TestDecodeJSONRejectsMalformedBody(t *testing.T) {
	var out map[string]any
	if err := (&Response{Body: []byte("{")}).DecodeJSON(&out); err == nil {
		t.Fatal("expected a decode error")
	}
}

func TestBaseURLPathJoin(t *testing.T) {
	var got string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		got = r.URL.Path
		_, _ = w.Write([]byte("ok"))
	}))
	defer srv.Close()

	c := New(Config{BaseURL: srv.URL + "/v1/"})
	if _, err := c.Do(context.Background(), Request{Method: http.MethodGet, Path: "/models"}); err != nil {
		t.Fatal(err)
	}
	if got != "/v1/models" {
		t.Fatalf("path = %q", got)
	}
}
