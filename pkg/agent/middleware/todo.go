package middleware

import (
	"context"
	"fmt"
	"strings"
	"sync"

	"github.com/axisvela/praxo-core/pkg/agent/types"
	"github.com/axisvela/praxo-core/pkg/model"
)

// TodoStatus is the lifecycle state of one todo item.
type TodoStatus string

const (
	// TodoPending is not started.
	TodoPending TodoStatus = "pending"
	// TodoInProgress is currently active.
	TodoInProgress TodoStatus = "in_progress"
	// TodoCompleted is finished.
	TodoCompleted TodoStatus = "completed"
	// TodoCancelled is intentionally dropped.
	TodoCancelled TodoStatus = "cancelled"
)

// TodoItem is one planned work item.
type TodoItem struct {
	ID      string     `json:"id"`
	Content string     `json:"content"`
	Status  TodoStatus `json:"status"`
}

// TodoList is a concurrency-safe todo store shared by the tool and middleware.
type TodoList struct {
	mu    sync.RWMutex
	items []TodoItem
}

// NewTodoList returns an empty todo list.
func NewTodoList() *TodoList {
	return &TodoList{}
}

// Write replaces the list contents.
func (l *TodoList) Write(items []TodoItem) {
	l.mu.Lock()
	defer l.mu.Unlock()
	l.items = append([]TodoItem(nil), items...)
}

// Items returns a copy of the current items.
func (l *TodoList) Items() []TodoItem {
	l.mu.RLock()
	defer l.mu.RUnlock()
	return append([]TodoItem(nil), l.items...)
}

// TodoTool is the model-facing write_todos tool.
type TodoTool struct {
	List *TodoList
}

// Name implements tool.Tool.
func (TodoTool) Name() string { return "write_todos" }

// Description implements tool.Tool.
func (TodoTool) Description() string {
	return "Replace the current todo list with the supplied items."
}

// Spec implements tool.SpecProvider.
func (TodoTool) Spec() model.ToolSpec {
	return model.ToolSpec{
		Name:        "write_todos",
		Description: "Replace the current todo list with the supplied items.",
		Risk:        "low",
		Parameters: map[string]any{
			"type":     "object",
			"required": []any{"todos"},
			"properties": map[string]any{
				"todos": map[string]any{
					"type": "array",
					"items": map[string]any{
						"type":     "object",
						"required": []any{"id", "content", "status"},
						"properties": map[string]any{
							"id":      map[string]any{"type": "string"},
							"content": map[string]any{"type": "string"},
							"status": map[string]any{"type": "string", "enum": []any{
								string(TodoPending), string(TodoInProgress), string(TodoCompleted), string(TodoCancelled),
							}},
						},
					},
				},
			},
		},
	}
}

// Invoke implements tool.Tool.
func (t TodoTool) Invoke(_ context.Context, args map[string]any) (any, error) {
	if t.List == nil {
		return nil, fmt.Errorf("write_todos: todo list is required")
	}
	raw, ok := args["todos"]
	if !ok {
		return nil, fmt.Errorf("write_todos: todos is required")
	}
	items, err := decodeTodos(raw)
	if err != nil {
		return nil, err
	}
	t.List.Write(items)
	return t.List.Items(), nil
}

func decodeTodos(raw any) ([]TodoItem, error) {
	list, ok := raw.([]any)
	if !ok {
		if typed, ok := raw.([]TodoItem); ok {
			return validateTodos(typed)
		}
		return nil, fmt.Errorf("write_todos: todos must be an array")
	}
	items := make([]TodoItem, 0, len(list))
	for _, entry := range list {
		item, ok := entry.(map[string]any)
		if !ok {
			return nil, fmt.Errorf("write_todos: todo entry must be an object")
		}
		itemID, _ := item["id"].(string)
		content, _ := item["content"].(string)
		status, _ := item["status"].(string)
		items = append(items, TodoItem{ID: itemID, Content: content, Status: TodoStatus(status)})
	}
	return validateTodos(items)
}

func validateTodos(items []TodoItem) ([]TodoItem, error) {
	for _, item := range items {
		if strings.TrimSpace(item.ID) == "" || strings.TrimSpace(item.Content) == "" {
			return nil, fmt.Errorf("write_todos: id and content are required")
		}
		switch item.Status {
		case TodoPending, TodoInProgress, TodoCompleted, TodoCancelled:
		default:
			return nil, fmt.Errorf("write_todos: invalid status %q", item.Status)
		}
	}
	return items, nil
}

// TodoMiddleware injects the current todo list before each model call.
func TodoMiddleware(list *TodoList) types.Middleware {
	return types.Middleware{
		Name: "todo",
		BeforeModel: func(_ context.Context, call *types.ModelCall) error {
			if call.Request == nil || list == nil {
				return nil
			}
			prompt := "Current todo list:\n"
			items := list.Items()
			if len(items) == 0 {
				prompt += "(empty; use write_todos to plan multi-step work)"
			} else {
				for _, item := range items {
					prompt += fmt.Sprintf("- [%s] %s (%s)\n", item.Status, item.Content, item.ID)
				}
			}
			call.Request.Messages = append(call.Request.Messages, model.Message{
				Role: model.RoleSystem, Content: strings.TrimSpace(prompt),
			})
			return nil
		},
	}
}
