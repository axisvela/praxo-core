package conformance

import (
	"context"
	"errors"
	"strings"
	"testing"

	"github.com/axisvela/praxo-core/v2/pkg/model"
	"github.com/axisvela/praxo-core/v2/pkg/retriever"
)

type fakeModel struct {
	content string
	calls   []model.ToolCall
	finish  string
	err     error
}

func (m fakeModel) Generate(context.Context, model.Request) (model.Response, error) {
	if m.err != nil {
		return model.Response{}, m.err
	}
	return model.Response{
		Message:      model.Message{Role: model.RoleAssistant, Content: m.content, ToolCalls: m.calls},
		FinishReason: m.finish,
	}, nil
}

type fakeStreamingModel struct {
	fakeModel
	deltas    []string
	streamErr error
	noDeltas  bool
}

func (m fakeStreamingModel) GenerateStream(ctx context.Context, req model.Request, onDelta func(string)) (model.Response, error) {
	if m.streamErr != nil {
		return model.Response{}, m.streamErr
	}
	if !m.noDeltas {
		for _, delta := range m.deltas {
			onDelta(delta)
		}
	}
	return m.fakeModel.Generate(ctx, req)
}

func TestCheckModel(t *testing.T) {
	generator := fakeModel{
		content: "hello",
		finish:  "stop",
		calls:   []model.ToolCall{{Name: "lookup"}},
	}
	cases := []ModelCase{{
		Request:             model.Request{Messages: []model.Message{{Role: model.RoleUser, Content: "hi"}}},
		WantContentContains: "hello",
		WantFinishReason:    "stop",
		WantToolCall:        "lookup",
	}}
	if err := CheckModel(context.Background(), generator, cases...); err != nil {
		t.Fatal(err)
	}
	if err := CheckModel(context.Background(), generator, ModelCase{WantContentContains: "missing"}); err == nil {
		t.Fatal("mismatched content passed")
	}
}

func TestCheckStreamingModel(t *testing.T) {
	generator := fakeStreamingModel{
		fakeModel: fakeModel{content: "hello"},
		deltas:    []string{"he", "llo"},
	}
	if err := CheckStreamingModel(context.Background(), generator, ModelStreamCase{WantContentContains: "hello"}); err != nil {
		t.Fatal(err)
	}
	broken := fakeStreamingModel{
		fakeModel: fakeModel{content: "hello"},
		noDeltas:  true,
	}
	if err := CheckStreamingModel(context.Background(), broken, ModelStreamCase{WantContentContains: "hello"}); err == nil {
		t.Fatal("missing deltas passed")
	}
}

type fakeTool struct{}

func (fakeTool) Name() string        { return "echo" }
func (fakeTool) Description() string { return "Echo a value" }

func (fakeTool) Invoke(_ context.Context, args map[string]any) (any, error) {
	return args["value"], nil
}

type mismatchedSpecTool struct{ fakeTool }

func (mismatchedSpecTool) Spec() model.ToolSpec { return model.ToolSpec{Name: "other"} }

func TestCheckTool(t *testing.T) {
	if err := CheckTool(context.Background(), fakeTool{}, ToolCase{Args: map[string]any{"value": "ok"}}); err != nil {
		t.Fatal(err)
	}
	if err := CheckTool(context.Background(), mismatchedSpecTool{}); err == nil {
		t.Fatal("mismatched spec name passed")
	}
}

type fakeRetriever struct {
	documents []retriever.Document
	err       error
}

func (r fakeRetriever) Retrieve(context.Context, string, int) ([]retriever.Document, error) {
	return r.documents, r.err
}

func TestCheckRetriever(t *testing.T) {
	candidate := fakeRetriever{documents: []retriever.Document{{ID: "doc-1", Content: "found"}}}
	cases := []RetrieverCase{{Query: "find", Limit: 1, WantDocumentID: "doc-1", WantContentContains: "found"}}
	if err := CheckRetriever(context.Background(), candidate, cases...); err != nil {
		t.Fatal(err)
	}
	overLimit := fakeRetriever{documents: []retriever.Document{{ID: "a"}, {ID: "b"}}}
	if err := CheckRetriever(context.Background(), overLimit, RetrieverCase{Query: "find", Limit: 1}); err == nil {
		t.Fatal("limit violation passed")
	}
}

func TestRunCollectsFailures(t *testing.T) {
	err := Run(
		Check{Name: "first", Run: func() error { return errors.New("one") }},
		Check{Name: "second", Run: func() error { return errors.New("two") }},
	)
	if err == nil {
		t.Fatal("expected failures")
	}
	if !strings.Contains(err.Error(), "first") || !strings.Contains(err.Error(), "second") {
		t.Fatalf("error = %q", err)
	}
}
