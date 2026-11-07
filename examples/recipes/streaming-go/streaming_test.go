package streaming_recipe

import (
	"context"
	"errors"
	"testing"

	"github.com/axisvela/praxo-core/v2/pkg/agent"
	"github.com/axisvela/praxo-core/v2/pkg/model"
)

type streamingModel struct {
	content string
	err     error
	cancel  context.CancelFunc
}

func (m *streamingModel) Generate(context.Context, model.Request) (model.Response, error) {
	if m.err != nil {
		return model.Response{}, m.err
	}
	return model.Response{Message: model.Message{Role: model.RoleAssistant, Content: m.content}}, nil
}

func (m *streamingModel) GenerateStream(ctx context.Context, request model.Request, onDelta func(string)) (model.Response, error) {
	if m.err != nil {
		return model.Response{}, m.err
	}
	for _, delta := range []string{"he", "llo"} {
		if err := ctx.Err(); err != nil {
			return model.Response{}, err
		}
		onDelta(delta)
	}
	return m.Generate(ctx, request)
}

type cancellingModel struct {
	cancel context.CancelFunc
	deltas []string
}

func (m *cancellingModel) Generate(context.Context, model.Request) (model.Response, error) {
	return model.Response{Message: model.Message{Role: model.RoleAssistant, Content: "hello"}}, nil
}

func (m *cancellingModel) GenerateStream(ctx context.Context, _ model.Request, onDelta func(string)) (model.Response, error) {
	onDelta("first")
	m.deltas = append(m.deltas, "first")
	m.cancel()
	if err := ctx.Err(); err != nil {
		return model.Response{}, err
	}
	onDelta("second")
	m.deltas = append(m.deltas, "second")
	return model.Response{Message: model.Message{Role: model.RoleAssistant, Content: "hello"}}, nil
}

func TestStreamingDeltasAndFinalOutput(t *testing.T) {
	var deltas []string
	ag, err := agent.New(agent.Options{
		Model:    &streamingModel{content: "hello"},
		MaxSteps: 1,
		OnDelta:  func(delta string) { deltas = append(deltas, delta) },
	})
	if err != nil {
		t.Fatal(err)
	}
	result, err := ag.Run(context.Background(), agent.Session{ID: "stream"}, "go")
	if err != nil {
		t.Fatal(err)
	}
	if result.Output != "hello" || len(deltas) != 2 || deltas[0] != "he" || deltas[1] != "llo" {
		t.Fatalf("output=%q deltas=%v", result.Output, deltas)
	}
}

func TestStreamingErrorIsSurfaced(t *testing.T) {
	sentinel := errors.New("stream failed")
	ag, err := agent.New(agent.Options{
		Model:    &streamingModel{err: sentinel},
		MaxSteps: 1,
		OnDelta:  func(string) {},
	})
	if err != nil {
		t.Fatal(err)
	}
	if _, err := ag.Run(context.Background(), agent.Session{ID: "stream"}, "go"); !errors.Is(err, sentinel) {
		t.Fatalf("err = %v, want sentinel", err)
	}
}

func TestStreamingCancellationStopsDeltas(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	streamer := &cancellingModel{cancel: cancel}
	ag, err := agent.New(agent.Options{
		Model:    streamer,
		MaxSteps: 1,
		OnDelta:  func(string) {},
	})
	if err != nil {
		t.Fatal(err)
	}
	if _, err := ag.Run(ctx, agent.Session{ID: "stream"}, "go"); !errors.Is(err, context.Canceled) {
		t.Fatalf("err = %v, want context.Canceled", err)
	}
	if len(streamer.deltas) != 1 || streamer.deltas[0] != "first" {
		t.Fatalf("deltas = %v, want [first]", streamer.deltas)
	}
}

func TestTypedStreamParts(t *testing.T) {
	var kinds []agent.StreamKind
	ag, err := agent.New(agent.Options{
		Model:    &streamingModel{content: "hello"},
		MaxSteps: 1,
		OnDelta:  func(string) {},
		OnStream: func(part agent.StreamPart) error {
			kinds = append(kinds, part.Kind)
			return nil
		},
	})
	if err != nil {
		t.Fatal(err)
	}
	if _, err := ag.Run(context.Background(), agent.Session{ID: "stream"}, "go"); err != nil {
		t.Fatal(err)
	}
	seen := map[agent.StreamKind]bool{}
	for _, kind := range kinds {
		seen[kind] = true
	}
	for _, want := range []agent.StreamKind{agent.StreamValues, agent.StreamMessages} {
		if !seen[want] {
			t.Fatalf("missing stream kind %q in %v", want, kinds)
		}
	}
}
