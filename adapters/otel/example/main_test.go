package main

import (
	"context"
	"strings"
	"testing"

	"go.opentelemetry.io/otel/sdk/trace/tracetest"
)

func TestRunEmitsEventSpansWithAllowlistedData(t *testing.T) {
	exporter := tracetest.NewInMemoryExporter()
	provider := newProvider(exporter)
	defer provider.Shutdown(context.Background())
	if err := run(context.Background(), provider); err != nil {
		t.Fatal(err)
	}
	spans := exporter.GetSpans()
	if len(spans) != 3 {
		t.Fatalf("spans = %d, want run.started, tool.call, run.completed", len(spans))
	}
	names := map[string]bool{}
	for _, span := range spans {
		names[span.Name] = true
	}
	for _, want := range []string{"praxo.run.started", "praxo.tool.call", "praxo.run.completed"} {
		if !names[want] {
			t.Fatalf("missing span %s: %v", want, names)
		}
	}
	for _, span := range spans {
		if span.Name != "praxo.tool.call" {
			continue
		}
		attributes := map[string]string{}
		for _, item := range span.Attributes {
			key := string(item.Key)
			attributes[key] = item.Value.AsString()
			if strings.Contains(key, "arguments") || strings.Contains(key, "result") {
				t.Fatalf("sensitive data attribute exported: %s", key)
			}
		}
		if attributes["praxo.event.data.name"] != "clock.now" {
			t.Fatalf("allowlisted name missing: %v", attributes)
		}
		return
	}
	t.Fatal("tool.call span not found")
}
