// Package harmovela publishes PRAXO-CORE events to the Harmovela HTTP API.
package harmovela

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"github.com/axisvela/praxo-core/v2/pkg/event"
)

// ErrBaseURLRequired is returned when the sink has no Harmovela endpoint.
var ErrBaseURLRequired = errors.New("harmovela: base URL is required")

// Sink implements event.Sink over the Harmovela HTTP events API.
type Sink struct {
	BaseURL     string
	Source      string
	SpecVersion string
	HTTP        *http.Client
}

// Emit publishes one event.
func (s Sink) Emit(ctx context.Context, ev event.Event) error {
	if s.BaseURL == "" {
		return ErrBaseURLRequired
	}
	at := ev.At
	if at.IsZero() {
		at = time.Now().UTC()
	}
	payload := make(map[string]any, len(ev.Data)+2)
	for key, value := range ev.Data {
		payload[key] = value
	}
	if ev.SessionID != "" {
		payload["session_id"] = ev.SessionID
	}
	if ev.RunID != "" {
		payload["run_id"] = ev.RunID
	}
	envelope := apiEvent{
		SpecVersion: s.specVersion(),
		ID:          eventID(ev, at),
		Type:        ev.Type,
		Source:      s.source(),
		CreatedAt:   at.UTC().Format(time.RFC3339Nano),
		Payload:     payload,
	}
	raw, err := json.Marshal(envelope)
	if err != nil {
		return err
	}
	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, strings.TrimRight(s.BaseURL, "/")+"/events", bytes.NewReader(raw))
	if err != nil {
		return err
	}
	httpReq.Header.Set("content-type", "application/json")
	client := s.HTTP
	if client == nil {
		client = &http.Client{Timeout: 30 * time.Second}
	}
	resp, err := client.Do(httpReq)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		body, _ := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
		return fmt.Errorf("harmovela: %s: %s", resp.Status, strings.TrimSpace(string(body)))
	}
	return nil
}

func (s Sink) source() string {
	if s.Source == "" {
		return "praxo-core"
	}
	return s.Source
}

func (s Sink) specVersion() string {
	if s.SpecVersion == "" {
		return "0.2"
	}
	return s.SpecVersion
}

func eventID(ev event.Event, at time.Time) string {
	prefix := ev.RunID
	if prefix == "" {
		prefix = ev.SessionID
	}
	if prefix == "" {
		prefix = "event"
	}
	return fmt.Sprintf("%s-%d", prefix, at.UnixNano())
}

type apiEvent struct {
	SpecVersion string         `json:"spec_version"`
	ID          string         `json:"id"`
	Type        string         `json:"type"`
	Source      string         `json:"source"`
	CreatedAt   string         `json:"created_at"`
	Payload     map[string]any `json:"payload"`
}
