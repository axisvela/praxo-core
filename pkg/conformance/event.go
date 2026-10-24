package conformance

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/axisvela/praxo-core/v2/pkg/event"
)

// CheckEventSink verifies that a sink accepts a well-formed lifecycle event.
// It proves acceptance, not downstream delivery or retention.
func CheckEventSink(ctx context.Context, sink event.Sink) error {
	if sink == nil {
		return errors.New("conformance: event sink is nil")
	}
	token := uniqueName("praxo-conformance-event")
	ev := event.Event{
		Type:      "conformance.event",
		SessionID: token,
		RunID:     token,
		Data:      map[string]any{"token": token},
		At:        time.Now().UTC(),
	}
	if err := sink.Emit(ctx, ev); err != nil {
		return fmt.Errorf("conformance: event emit: %w", err)
	}
	return nil
}
