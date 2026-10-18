package agent

import (
	"context"
	"errors"
	"testing"

	"github.com/axisvela/praxo-core/v2/pkg/model"
	"github.com/axisvela/praxo-core/v2/pkg/tool"
)

func TestAgentStreamsTypedParts(t *testing.T) {
	registry := tool.NewRegistry()
	registry.Register(&echoTool{})
	var parts []StreamPart
	ag := &Agent{
		Model:    &fakeModel{},
		Tools:    registry,
		MaxSteps: 4,
		OnStream: func(part StreamPart) error {
			parts = append(parts, part)
			return nil
		},
	}
	if _, err := ag.Run(context.Background(), Session{ID: "s"}, "go"); err != nil {
		t.Fatal(err)
	}
	seen := make(map[StreamKind]bool)
	for _, part := range parts {
		seen[part.Kind] = true
		if part.RunID == "" || part.SessionID != "s" {
			t.Fatalf("part missing identity: %+v", part)
		}
	}
	for _, kind := range []StreamKind{StreamValues, StreamUpdates, StreamMessages, StreamTasks, StreamCheckpoint} {
		if !seen[kind] {
			t.Fatalf("missing stream kind %q in %+v", kind, seen)
		}
	}
}

func TestAgentStreamErrorAbortsRun(t *testing.T) {
	sentinel := errors.New("stream down")
	ag := &Agent{
		Model: &fakeModel{},
		OnStream: func(StreamPart) error {
			return sentinel
		},
	}
	if _, err := ag.Run(context.Background(), Session{ID: "s"}, "go"); !errors.Is(err, sentinel) {
		t.Fatalf("err = %v, want sentinel", err)
	}
}

func TestAgentStreamMessageData(t *testing.T) {
	registry := tool.NewRegistry()
	registry.Register(&echoTool{})
	var message model.Message
	ag := &Agent{
		Model: &fakeModel{},
		Tools: registry,
		OnStream: func(part StreamPart) error {
			if part.Kind == StreamMessages {
				message, _ = part.Data.(model.Message)
			}
			return nil
		},
	}
	if _, err := ag.Run(context.Background(), Session{ID: "s"}, "go"); err != nil {
		t.Fatal(err)
	}
	if message.Content != "final" {
		t.Fatalf("message = %+v", message)
	}
}
