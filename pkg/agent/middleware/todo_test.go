package middleware

import (
	"context"
	"strings"
	"testing"

	"github.com/axisvela/praxo-core/v2/pkg/agent/types"
	"github.com/axisvela/praxo-core/v2/pkg/model"
)

func TestTodoToolWritesList(t *testing.T) {
	list := NewTodoList()
	tool := TodoTool{List: list}
	_, err := tool.Invoke(context.Background(), map[string]any{
		"todos": []any{
			map[string]any{"id": "1", "content": "plan", "status": "in_progress"},
			map[string]any{"id": "2", "content": "verify", "status": "pending"},
		},
	})
	if err != nil {
		t.Fatal(err)
	}
	items := list.Items()
	if len(items) != 2 || items[0].Status != TodoInProgress || items[1].Content != "verify" {
		t.Fatalf("items = %+v", items)
	}
}

func TestTodoToolRejectsBadStatus(t *testing.T) {
	tool := TodoTool{List: NewTodoList()}
	_, err := tool.Invoke(context.Background(), map[string]any{
		"todos": []any{map[string]any{"id": "1", "content": "plan", "status": "done"}},
	})
	if err == nil {
		t.Fatal("expected invalid status error")
	}
}

func TestTodoMiddlewareInjectsPrompt(t *testing.T) {
	list := NewTodoList()
	list.Write([]TodoItem{{ID: "1", Content: "plan", Status: TodoInProgress}})
	mw := TodoMiddleware(list)
	req := &model.Request{Messages: []model.Message{{Role: model.RoleUser, Content: "go"}}}
	if err := mw.BeforeModel(context.Background(), &types.ModelCall{RunID: "r", Request: req}); err != nil {
		t.Fatal(err)
	}
	found := false
	for _, message := range req.Messages {
		if message.Role == model.RoleSystem && strings.Contains(message.Content, "plan") {
			found = true
		}
	}
	if !found {
		t.Fatalf("todo prompt missing: %+v", req.Messages)
	}
}
