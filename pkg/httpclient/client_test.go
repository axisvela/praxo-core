package httpclient

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestResponseBodyBound(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write(make([]byte, 2048))
	}))
	defer srv.Close()

	c := New(Config{BaseURL: srv.URL, MaxBodyBytes: 1024})
	_, err := c.Do(context.Background(), Request{Method: http.MethodGet, Path: "/"})
	if !errors.Is(err, ErrBodyTooLarge) {
		t.Fatalf("err = %v, want ErrBodyTooLarge", err)
	}
}

func TestResponseBodyWithinBound(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte("ok"))
	}))
	defer srv.Close()

	c := New(Config{BaseURL: srv.URL, MaxBodyBytes: 1024})
	resp, err := c.Do(context.Background(), Request{Method: http.MethodGet, Path: "/"})
	if err != nil {
		t.Fatal(err)
	}
	if string(resp.Body) != "ok" {
		t.Fatalf("body = %q", resp.Body)
	}
}

func TestDefaultBodyBoundIsApplied(t *testing.T) {
	c := New(Config{BaseURL: "http://example.invalid"})
	if c.cfg.MaxBodyBytes != DefaultMaxBodyBytes {
		t.Fatalf("MaxBodyBytes = %d, want %d", c.cfg.MaxBodyBytes, DefaultMaxBodyBytes)
	}
}
