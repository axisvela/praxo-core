package event

import "context"

// Publisher publishes events to a bus such as Harmovela or Argus.
type Publisher interface {
	Publish(ctx context.Context, event Event) error
}

// PublisherSink adapts a Publisher to the Sink interface.
type PublisherSink struct {
	Publisher Publisher
}

// Emit implements Sink.
func (s PublisherSink) Emit(ctx context.Context, event Event) error {
	if s.Publisher == nil {
		return nil
	}
	return s.Publisher.Publish(ctx, event)
}
