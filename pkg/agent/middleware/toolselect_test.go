package middleware

import (
	"context"
	"errors"
	"testing"

	"github.com/axisvela/praxo-core/v2/internal/runid"
	"github.com/axisvela/praxo-core/v2/pkg/agent/types"
	"github.com/axisvela/praxo-core/v2/pkg/model"
)

type fakeSelector struct {
	names []string
	err   error
	query string
	tools []model.ToolSpec
}

func (f *fakeSelector) Select(_ context.Context, query string, tools []model.ToolSpec) ([]string, error) {
	f.query = query
	f.tools = tools
	return f.names, f.err
}

func TestToolSelectionMiddlewareFiltersRequest(t *testing.T) {
	selector := &fakeSelector{names: []string{"echo"}}
	mw := ToolSelectionMiddleware(selector)
	req := &model.Request{
		Messages: []model.Message{{Role: model.RoleUser, Content: "use echo"}},
		Tools:    []model.ToolSpec{{Name: "echo"}, {Name: "other"}},
	}
	if err := mw.BeforeModel(context.Background(), &types.ModelCall{RunID: "r1", Request: req}); err != nil {
		t.Fatal(err)
	}
	if selector.query != "use echo" || len(selector.tools) != 2 {
		t.Fatalf("query=%q tools=%+v", selector.query, selector.tools)
	}
	if len(req.Tools) != 1 || req.Tools[0].Name != "echo" {
		t.Fatalf("tools = %+v", req.Tools)
	}
}

func TestToolSelectionMiddlewareRejectsUnselectedTool(t *testing.T) {
	mw := ToolSelectionMiddleware(&fakeSelector{names: []string{"echo"}})
	req := &model.Request{
		Messages: []model.Message{{Role: model.RoleUser, Content: "use echo"}},
		Tools:    []model.ToolSpec{{Name: "echo"}, {Name: "other"}},
	}
	if err := mw.BeforeModel(context.Background(), &types.ModelCall{RunID: "r2", Request: req}); err != nil {
		t.Fatal(err)
	}
	err := mw.BeforeTool(context.Background(), &types.ToolCall{RunID: "r2", Call: &model.ToolCall{Name: "other"}})
	if !errors.Is(err, ErrToolNotSelected) {
		t.Fatalf("err = %v, want ErrToolNotSelected", err)
	}
	if err := mw.BeforeTool(context.Background(), &types.ToolCall{RunID: "r2", Call: &model.ToolCall{Name: "echo"}}); err != nil {
		t.Fatalf("selected tool rejected: %v", err)
	}
}

func TestToolSelectionMiddlewareNoSelectionAllowsAll(t *testing.T) {
	mw := ToolSelectionMiddleware(&fakeSelector{})
	if err := mw.BeforeTool(context.Background(), &types.ToolCall{RunID: "r3", Call: &model.ToolCall{Name: "echo"}}); err != nil {
		t.Fatalf("err = %v", err)
	}
}

func TestToolSelectionMiddlewareCleansFailedRunWithoutResult(t *testing.T) {
	ctx := runid.With(context.Background(), "failed")
	mw := ToolSelectionMiddleware(&fakeSelector{names: []string{"echo"}})
	if err := mw.BeforeModel(ctx, &types.ModelCall{RunID: "failed", Request: &model.Request{}}); err != nil {
		t.Fatal(err)
	}
	call := &types.ToolCall{RunID: "failed", Call: &model.ToolCall{Name: "other"}}
	if err := mw.BeforeTool(ctx, call); !errors.Is(err, ErrToolNotSelected) {
		t.Fatalf("selection error = %v", err)
	}
	if err := mw.AfterRun(ctx, nil, context.Canceled); err != nil {
		t.Fatal(err)
	}
	if err := mw.BeforeTool(ctx, call); err != nil {
		t.Fatalf("failed run selection was retained: %v", err)
	}
}
