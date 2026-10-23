package otel

import (
	"context"
	"errors"
	"strings"
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
	sink.AllowedDataKeys = []string{"tool", "missing"}

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

type sensitiveValue struct {
	formatted *bool
}

func (v sensitiveValue) String() string {
	*v.formatted = true
	return "secret-value"
}

func TestSinkOmitsDataByDefault(t *testing.T) {
	recorder := tracetest.NewSpanRecorder()
	provider := sdktrace.NewTracerProvider(sdktrace.WithSpanProcessor(recorder))
	t.Cleanup(func() { _ = provider.Shutdown(context.Background()) })
	sink := New(provider)
	formatted := false
	if err := sink.Emit(context.Background(), event.Event{
		Type: "tool.call",
		Data: map[string]any{"arguments": sensitiveValue{formatted: &formatted}},
	}); err != nil {
		t.Fatal(err)
	}
	if formatted {
		t.Fatal("unselected event data was formatted")
	}
	spans := recorder.Ended()
	if len(spans) != 1 {
		t.Fatalf("spans = %d", len(spans))
	}
	for _, attr := range spans[0].Attributes() {
		if strings.HasPrefix(string(attr.Key), "praxo.event.data.") {
			t.Fatalf("unexpected data attribute: %s", attr.Key)
		}
	}
}

func TestSinkAllowlistExcludesUnselectedFields(t *testing.T) {
	recorder := tracetest.NewSpanRecorder()
	provider := sdktrace.NewTracerProvider(sdktrace.WithSpanProcessor(recorder))
	t.Cleanup(func() { _ = provider.Shutdown(context.Background()) })
	sink := New(provider)
	sink.AllowedDataKeys = []string{"tool", "missing"}
	if err := sink.Emit(context.Background(), event.Event{
		Type: "tool.call",
		Data: map[string]any{"tool": "lookup", "arguments": "secret", "result": "private"},
	}); err != nil {
		t.Fatal(err)
	}
	attributes := map[string]string{}
	for _, attr := range recorder.Ended()[0].Attributes() {
		attributes[string(attr.Key)] = attr.Value.AsString()
	}
	if attributes["praxo.event.data.tool"] != "lookup" {
		t.Fatalf("attributes = %v", attributes)
	}
	for _, key := range []string{"arguments", "result", "missing"} {
		if _, ok := attributes["praxo.event.data."+key]; ok {
			t.Fatalf("unexpected attribute: %s", key)
		}
	}
}

func TestSinkInheritsParentTrace(t *testing.T) {
	recorder := tracetest.NewSpanRecorder()
	provider := sdktrace.NewTracerProvider(sdktrace.WithSpanProcessor(recorder))
	t.Cleanup(func() { _ = provider.Shutdown(context.Background()) })
	ctx, parent := provider.Tracer("consumer").Start(context.Background(), "parent")
	if err := New(provider).Emit(ctx, event.Event{Type: "run.started"}); err != nil {
		parent.End()
		t.Fatal(err)
	}
	parent.End()
	child := recorder.Ended()[0]
	if child.SpanContext().TraceID() != parent.SpanContext().TraceID() ||
		child.Parent().SpanID() != parent.SpanContext().SpanID() {
		t.Fatal("event span did not inherit parent trace and span")
	}
}
