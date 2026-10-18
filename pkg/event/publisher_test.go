package event

import (
	"context"
	"testing"
)

type fakePublisher struct{ event Event }

func (p *fakePublisher) Publish(_ context.Context, event Event) error {
	p.event = event
	return nil
}

func TestPublisherSink(t *testing.T) {
	pub := &fakePublisher{}
	sink := PublisherSink{Publisher: pub}
	if err := sink.Emit(context.Background(), Event{Type: "work.created"}); err != nil {
		t.Fatal(err)
	}
	if pub.event.Type != "work.created" {
		t.Fatalf("event = %+v", pub.event)
	}
}
