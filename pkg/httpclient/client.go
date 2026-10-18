// Package httpclient provides a shared, retry-capable HTTP transport for
// boundary adapters and provider clients.
package httpclient

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
)

// Config configures a shared HTTP client.
type Config struct {
	BaseURL     string
	APIKey      string
	Headers     map[string]string
	Timeout     time.Duration
	MaxAttempts int
	TraceID     string
}

// Request is an HTTP request for a boundary adapter.
type Request struct {
	Method  string
	Path    string
	Body    []byte
	Headers map[string]string
}

// Response is a decoded HTTP response.
type Response struct {
	Status  int
	Body    []byte
	Headers http.Header
}

// Client is a shared, retry-capable HTTP transport.
type Client struct {
	cfg        Config
	httpClient *http.Client
}

// New creates a Client with sane defaults.
func New(cfg Config) *Client {
	if cfg.Timeout == 0 {
		cfg.Timeout = 30 * time.Second
	}
	if cfg.MaxAttempts == 0 {
		cfg.MaxAttempts = 3
	}
	return &Client{cfg: cfg, httpClient: &http.Client{Timeout: cfg.Timeout}}
}

// BaseURL returns the configured base URL so an SDK client can be built against
// the same endpoint.
func (c *Client) BaseURL() string { return c.cfg.BaseURL }

// HTTPClient returns the underlying *http.Client (timeout configured).
func (c *Client) HTTPClient() *http.Client { return c.httpClient }

// MaxAttempts returns the configured attempt bound so an SDK client can
// reproduce the shared transport's retry policy.
func (c *Client) MaxAttempts() int { return c.cfg.MaxAttempts }

// RequestHeaders returns the static headers every request carries (bearer auth,
// trace id and configured headers), so an SDK client can reproduce them.
func (c *Client) RequestHeaders() map[string]string {
	out := make(map[string]string, len(c.cfg.Headers)+2)
	for k, v := range c.cfg.Headers {
		out[k] = v
	}
	if c.cfg.APIKey != "" {
		out["Authorization"] = "Bearer " + c.cfg.APIKey
	}
	if c.cfg.TraceID != "" {
		out["X-Trace-ID"] = c.cfg.TraceID
	}
	if len(out) == 0 {
		return nil
	}
	return out
}

// Do performs a request with retries for idempotent methods on 5xx and transport errors.
func (c *Client) Do(ctx context.Context, req Request) (*Response, error) {
	idempotent := isIdempotentMethod(req.Method)
	attempts := c.cfg.MaxAttempts
	if attempts < 1 {
		attempts = 1
	}
	for i := 0; i < attempts; i++ {
		resp, err := c.doOnce(ctx, req)
		if err != nil {
			if !idempotent || i == attempts-1 {
				return nil, err
			}
			if !sleep(ctx, backoff(i)) {
				return nil, ctx.Err()
			}
			continue
		}
		if resp.Status >= 500 && idempotent {
			if i == attempts-1 {
				return nil, fmt.Errorf("httpclient: request failed with status %d after %d attempts", resp.Status, attempts)
			}
			if !sleep(ctx, backoff(i)) {
				return nil, ctx.Err()
			}
			continue
		}
		return resp, nil
	}
	return nil, fmt.Errorf("httpclient: request failed after %d attempts", attempts)
}

func (c *Client) doOnce(ctx context.Context, req Request) (*Response, error) {
	var body io.Reader
	if req.Body != nil {
		body = bytes.NewReader(req.Body)
	}
	fullURL := strings.TrimRight(c.cfg.BaseURL, "/") + "/" + strings.TrimLeft(req.Path, "/")
	httpReq, err := http.NewRequestWithContext(ctx, req.Method, fullURL, body)
	if err != nil {
		return nil, fmt.Errorf("httpclient: build request: %w", err)
	}
	if req.Body != nil {
		httpReq.Header.Set("Content-Type", "application/json")
	}
	if c.cfg.APIKey != "" {
		httpReq.Header.Set("Authorization", "Bearer "+c.cfg.APIKey)
	}
	if c.cfg.TraceID != "" {
		httpReq.Header.Set("X-Trace-ID", c.cfg.TraceID)
	}
	for k, v := range c.cfg.Headers {
		httpReq.Header.Set(k, v)
	}
	for k, v := range req.Headers {
		httpReq.Header.Set(k, v)
	}
	resp, err := c.httpClient.Do(httpReq)
	if err != nil {
		return nil, fmt.Errorf("httpclient: %w", err)
	}
	defer resp.Body.Close()
	raw, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("httpclient: read body: %w", err)
	}
	return &Response{Status: resp.StatusCode, Body: raw, Headers: resp.Header}, nil
}

// DecodeJSON unmarshals a response body into out.
func (r *Response) DecodeJSON(out any) error {
	return json.Unmarshal(r.Body, out)
}

func backoff(i int) time.Duration {
	return time.Duration(i+1) * 100 * time.Millisecond
}

// isIdempotentMethod reports whether a request method is safe to re-send.
func isIdempotentMethod(method string) bool {
	switch method {
	case http.MethodGet, http.MethodPut, http.MethodDelete, http.MethodHead, http.MethodOptions:
		return true
	}
	return false
}

func sleep(ctx context.Context, d time.Duration) bool {
	select {
	case <-ctx.Done():
		return false
	case <-time.After(d):
		return true
	}
}
