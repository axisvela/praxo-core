package otel

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/axisvela/praxo-core/v2/pkg/event"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	"go.opentelemetry.io/otel/sdk/trace/tracetest"
)

var _ event.Sink = Sink{}

func TestSinkRequiresTracer(t *testing.T) {
	if err := (Sink{}).Emit(context.Background(), event.Event{}); !errors.Is(err, ErrTracerRequired) {
		t.Fatalf("got %v, want %v", err, ErrTracerRequired)
	}
}

func TestSinkRecordsSpan(t *testing.T) {
	recorder := tracetest.NewSpanRecorder()
	provider := sdktrace.NewTracerProvider(sdktrace.WithSpanProcessor(recorder))
	sink := New(provider)

	at := time.Date(2026, 10, 22, 12, 0, 0, 0, time.UTC)
	if err := sink.Emit(context.Background(), event.Event{
		Type:      "tool.call",
		SessionID: "session-1",
		RunID:     "run-1",
		Data:      map[string]any{"tool": "lookup"},
		At:        at,
	}); err != nil {
		t.Fatal(err)
	}

	spans := recorder.Ended()
	if len(spans) != 1 {
		t.Fatalf("spans = %d", len(spans))
	}
	span := spans[0]
	if span.Name() != "praxo.tool.call" {
		t.Fatalf("name = %q", span.Name())
	}
	attributes := map[string]string{}
	for _, item := range span.Attributes() {
		attributes[string(item.Key)] = item.Value.AsString()
	}
	if attributes["praxo.event.type"] != "tool.call" {
		t.Fatalf("attributes = %#v", attributes)
	}
	if attributes["praxo.session.id"] != "session-1" || attributes["praxo.run.id"] != "run-1" {
		t.Fatalf("attributes = %#v", attributes)
	}
	if attributes["praxo.event.data.tool"] != "lookup" {
		t.Fatalf("attributes = %#v", attributes)
	}
	if attributes["praxo.event.at"] != at.Format(time.RFC3339Nano) {
		t.Fatalf("attributes = %#v", attributes)
	}
}
