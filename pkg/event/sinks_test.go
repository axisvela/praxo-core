package event

import (
	"context"
	"testing"
)

func TestMultiSink(t *testing.T) {
	var got []string
	sink := FuncSink(func(_ context.Context, e Event) error {
		got = append(got, e.Type)
		return nil
	})
	if err := (MultiSink{sink, sink}).Emit(context.Background(), Event{Type: "work.created"}); err != nil {
		t.Fatal(err)
	}
	if len(got) != 2 {
		t.Fatalf("got = %+v", got)
	}
}

func TestFilterSink(t *testing.T) {
	var got []string
	sink := FilterSink{
		Sink: FuncSink(func(_ context.Context, e Event) error {
			got = append(got, e.Type)
			return nil
		}),
		Predicate: func(e Event) bool { return e.Type == "work.stalled" },
	}
	_ = sink.Emit(context.Background(), Event{Type: "work.created"})
	_ = sink.Emit(context.Background(), Event{Type: "work.stalled"})
	if len(got) != 1 || got[0] != "work.stalled" {
		t.Fatalf("got = %+v", got)
	}
}
