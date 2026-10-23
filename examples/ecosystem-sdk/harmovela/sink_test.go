package harmovela

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/axisvela/praxo-core/v2/pkg/event"
)

var _ event.Sink = Sink{}

func TestSinkRequiresBaseURL(t *testing.T) {
	if err := (Sink{}).Emit(context.Background(), event.Event{}); !errors.Is(err, ErrBaseURLRequired) {
		t.Fatalf("got %v, want %v", err, ErrBaseURLRequired)
	}
}

func TestSinkPublishesEvent(t *testing.T) {
	var got apiEvent
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/events" {
			http.NotFound(w, r)
			return
		}
		if err := json.NewDecoder(r.Body).Decode(&got); err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
		w.WriteHeader(http.StatusAccepted)
	}))
	defer server.Close()

	sink := Sink{BaseURL: server.URL, Source: "praxo-test", HTTP: server.Client()}
	at := time.Date(2026, 10, 23, 1, 0, 0, 0, time.UTC)
	if err := sink.Emit(context.Background(), event.Event{
		Type:      "tool.call",
		SessionID: "session-1",
		RunID:     "run-1",
		Data:      map[string]any{"tool": "lookup"},
		At:        at,
	}); err != nil {
		t.Fatal(err)
	}
	if got.SpecVersion != "0.2" || got.Type != "tool.call" || got.Source != "praxo-test" {
		t.Fatalf("event = %#v", got)
	}
	if got.CreatedAt != at.Format(time.RFC3339Nano) {
		t.Fatalf("created_at = %q", got.CreatedAt)
	}
	if got.ID == "" || got.ID[:6] != "run-1-" {
		t.Fatalf("id = %q", got.ID)
	}
	if got.Payload["session_id"] != "session-1" || got.Payload["run_id"] != "run-1" {
		t.Fatalf("payload = %#v", got.Payload)
	}
	if got.Payload["tool"] != "lookup" {
		t.Fatalf("payload = %#v", got.Payload)
	}
}
