// Package model defines the provider-neutral model abstraction.
package model

import "context"

// Role is a message role.
type Role string

const (
	RoleSystem    Role = "system"
	RoleUser      Role = "user"
	RoleAssistant Role = "assistant"
	RoleTool      Role = "tool"
)

// ToolCall is a model-requested tool invocation.
type ToolCall struct {
	ID        string         `json:"id"`
	Name      string         `json:"name"`
	Arguments map[string]any `json:"arguments"`
}

// Message is one conversation message.
type Message struct {
	Role      Role       `json:"role"`
	Content   string     `json:"content,omitempty"`
	ToolCalls []ToolCall `json:"toolCalls,omitempty"`
	ToolID    string     `json:"toolId,omitempty"`
}

// ToolSpec describes a tool exposed to the model.
type ToolSpec struct {
	Name        string         `json:"name"`
	Description string         `json:"description"`
	Parameters  map[string]any `json:"parameters,omitempty"`
}

// Request is one model generation request.
type Request struct {
	Model       string     `json:"model,omitempty"`
	Messages    []Message  `json:"messages"`
	Tools       []ToolSpec `json:"tools,omitempty"`
	Temperature float64    `json:"temperature,omitempty"`
}

// Usage is normalized token usage.
type Usage struct {
	InputTokens  int64 `json:"inputTokens"`
	OutputTokens int64 `json:"outputTokens"`
	CachedTokens int64 `json:"cachedTokens,omitempty"`
}

// Response is one model generation result.
type Response struct {
	Message      Message `json:"message"`
	Usage        Usage   `json:"usage"`
	FinishReason string  `json:"finishReason,omitempty"`
}

// Model generates a response for a request.
type Model interface {
	Generate(ctx context.Context, req Request) (Response, error)
}
