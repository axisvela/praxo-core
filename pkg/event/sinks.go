package event

import "context"

// MultiSink fans out each event to every sink.
type MultiSink []Sink

// Emit implements Sink.
func (m MultiSink) Emit(ctx context.Context, event Event) error {
	for _, sink := range m {
		if sink == nil {
			continue
		}
		if err := sink.Emit(ctx, event); err != nil {
			return err
		}
	}
	return nil
}

// Predicate decides whether an event should reach the wrapped sink.
type Predicate func(Event) bool

// FilterSink forwards only matching events.
type FilterSink struct {
	Sink      Sink
	Predicate Predicate
}

// Emit implements Sink.
func (f FilterSink) Emit(ctx context.Context, event Event) error {
	if f.Sink == nil {
		return nil
	}
	if f.Predicate != nil && !f.Predicate(event) {
		return nil
	}
	return f.Sink.Emit(ctx, event)
}
