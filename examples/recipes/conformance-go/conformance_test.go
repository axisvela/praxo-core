package conformance_recipe

import (
	"context"
	"testing"

	"github.com/axisvela/praxo-core/v2/pkg/conformance"
	"github.com/axisvela/praxo-core/v2/pkg/model"
	"github.com/axisvela/praxo-core/v2/pkg/retriever"
)

type fakeModel struct{}

func (fakeModel) Generate(context.Context, model.Request) (model.Response, error) {
	return model.Response{
		Message:      model.Message{Role: model.RoleAssistant, Content: "hello"},
		FinishReason: "stop",
	}, nil
}

type fakeStreamingModel struct{ fakeModel }

func (fakeStreamingModel) GenerateStream(ctx context.Context, request model.Request, onDelta func(string)) (model.Response, error) {
	onDelta("hel")
	onDelta("lo")
	return fakeModel{}.Generate(ctx, request)
}

type echoTool struct{}

func (echoTool) Name() string        { return "echo" }
func (echoTool) Description() string { return "Echo a value" }

func (echoTool) Invoke(_ context.Context, args map[string]any) (any, error) {
	return args["value"], nil
}

type fakeRetriever struct{}

func (fakeRetriever) Retrieve(_ context.Context, query string, limit int) ([]retriever.Document, error) {
	documents := []retriever.Document{{ID: "doc-1", Content: "found " + query}}
	if limit > 0 && len(documents) > limit {
		documents = documents[:limit]
	}
	return documents, nil
}

func TestConformanceChecks(t *testing.T) {
	ctx := context.Background()
	request := model.Request{Messages: []model.Message{{Role: model.RoleUser, Content: "hi"}}}

	if err := conformance.CheckModel(ctx, fakeModel{}, conformance.ModelCase{
		Request:             request,
		WantContentContains: "hello",
		WantFinishReason:    "stop",
	}); err != nil {
		t.Fatal(err)
	}
	if err := conformance.CheckStreamingModel(ctx, fakeStreamingModel{}, conformance.ModelStreamCase{
		Request:             request,
		WantContentContains: "hello",
	}); err != nil {
		t.Fatal(err)
	}
	if err := conformance.CheckTool(ctx, echoTool{}, conformance.ToolCase{
		Args: map[string]any{"value": "ok"},
	}); err != nil {
		t.Fatal(err)
	}
	if err := conformance.CheckRetriever(ctx, fakeRetriever{}, conformance.RetrieverCase{
		Query:               "find",
		Limit:               1,
		WantDocumentID:       "doc-1",
		WantContentContains: "found",
	}); err != nil {
		t.Fatal(err)
	}
}

func TestConformanceReportsMismatch(t *testing.T) {
	ctx := context.Background()
	request := model.Request{Messages: []model.Message{{Role: model.RoleUser, Content: "hi"}}}

	if err := conformance.CheckModel(ctx, fakeModel{}, conformance.ModelCase{
		Request:             request,
		WantContentContains: "missing",
	}); err == nil {
		t.Fatal("mismatched model case passed")
	}
	if err := conformance.CheckStreamingModel(ctx, fakeStreamingModel{}, conformance.ModelStreamCase{
		Request:             request,
		WantContentContains: "missing",
	}); err == nil {
		t.Fatal("mismatched streaming case passed")
	}
	if err := conformance.CheckTool(ctx, echoTool{}, conformance.ToolCase{
		Args:      map[string]any{"value": "ok"},
		WantError: true,
	}); err == nil {
		t.Fatal("expected tool error was not required")
	}
	if err := conformance.CheckRetriever(ctx, fakeRetriever{}, conformance.RetrieverCase{
		Query:         "find",
		WantDocumentID: "missing",
	}); err == nil {
		t.Fatal("missing retriever document passed")
	}
}
