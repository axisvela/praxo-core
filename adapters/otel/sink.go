// Package otel adapts PRAXO-CORE events to OpenTelemetry spans.
package otel

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/axisvela/praxo-core/v2/pkg/event"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/trace"
)

// ErrTracerRequired is returned when the sink has no tracer.
var ErrTracerRequired = errors.New("otel: tracer is required")

// Sink implements event.Sink with OpenTelemetry spans.
type Sink struct {
	Tracer          trace.Tracer
	AllowedDataKeys []string
}

// New returns a sink using the provider's PRAXO-CORE tracer.
func New(provider trace.TracerProvider) Sink {
	if provider == nil {
		return Sink{}
	}
	return Sink{Tracer: provider.Tracer("github.com/axisvela/praxo-core")}
}

// Emit records one event as a span.
func (s Sink) Emit(ctx context.Context, ev event.Event) error {
	if s.Tracer == nil {
		return ErrTracerRequired
	}
	_, span := s.Tracer.Start(ctx, "praxo."+ev.Type)
	defer span.End()

	span.SetAttributes(attribute.String("praxo.event.type", ev.Type))
	if ev.SessionID != "" {
		span.SetAttributes(attribute.String("praxo.session.id", ev.SessionID))
	}
	if ev.RunID != "" {
		span.SetAttributes(attribute.String("praxo.run.id", ev.RunID))
	}
	if !ev.At.IsZero() {
		span.SetAttributes(attribute.String("praxo.event.at", ev.At.UTC().Format(time.RFC3339Nano)))
	}
	for _, key := range s.AllowedDataKeys {
		if value, ok := ev.Data[key]; ok {
			span.SetAttributes(attribute.String("praxo.event.data."+key, fmt.Sprint(value)))
		}
	}
	return nil
}
