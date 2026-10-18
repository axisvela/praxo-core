package middleware

import (
	"context"
	"strings"
	"testing"

	"github.com/axisvela/praxo-core/v2/pkg/agent/types"
	"github.com/axisvela/praxo-core/v2/pkg/model"
)

func TestContextEditingClearsOldToolResults(t *testing.T) {
	mw := ContextEditingMiddleware(ContextEdit{KeepToolResults: 1})
	req := &model.Request{Messages: []model.Message{
		{Role: model.RoleTool, ToolID: "t1", Content: "old-1"},
		{Role: model.RoleTool, ToolID: "t2", Content: "old-2"},
		{Role: model.RoleTool, ToolID: "t3", Content: "keep"},
	}}
	if err := mw.BeforeModel(context.Background(), &types.ModelCall{RunID: "r", Request: req}); err != nil {
		t.Fatal(err)
	}
	if strings.Contains(req.Messages[0].Content, "old-1") || strings.Contains(req.Messages[1].Content, "old-2") {
		t.Fatalf("old tool results not cleared: %+v", req.Messages)
	}
	if req.Messages[2].Content != "keep" {
		t.Fatalf("recent tool result changed: %+v", req.Messages)
	}
	if !strings.Contains(req.Messages[0].Content, "cleared") {
		t.Fatalf("placeholder missing: %q", req.Messages[0].Content)
	}
}

func TestContextEditingKeepsNonToolMessages(t *testing.T) {
	mw := ContextEditingMiddleware(ContextEdit{KeepToolResults: 0})
	req := &model.Request{Messages: []model.Message{
		{Role: model.RoleUser, Content: "question"},
		{Role: model.RoleTool, ToolID: "t1", Content: "result"},
	}}
	if err := mw.BeforeModel(context.Background(), &types.ModelCall{RunID: "r", Request: req}); err != nil {
		t.Fatal(err)
	}
	if req.Messages[1].Content != "result" {
		t.Fatalf("zero keep should be a no-op: %+v", req.Messages)
	}
}
