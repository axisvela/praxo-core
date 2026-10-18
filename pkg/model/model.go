// Package model defines the provider-neutral model abstraction.
package model

import (
	"context"
	"fmt"
)

// Role is a message role.
type Role = string

const (
	RoleSystem    Role = "system"
	RoleUser      Role = "user"
	RoleAssistant Role = "assistant"
	RoleTool      Role = "tool"
)

// TaskClass is a coarse routing class.
type TaskClass string

const (
	TaskClassify  TaskClass = "classify"
	TaskSummarize TaskClass = "summarize"
	TaskChat      TaskClass = "chat"
	TaskCoding    TaskClass = "coding"
	TaskReasoning TaskClass = "reasoning"
	TaskVision    TaskClass = "vision"
)

// ContentBlock is one multi-modal content block.
type ContentBlock struct {
	Type     string `json:"type"`
	Text     string `json:"text,omitempty"`
	ImageURL string `json:"image_url,omitempty"`
	Data     string `json:"data,omitempty"`
}

// ToolCall is a model-requested tool invocation.
type ToolCall struct {
	ID        string         `json:"id"`
	Name      string         `json:"name"`
	Arguments map[string]any `json:"arguments"`
}

// Message is one conversation message.
type Message struct {
	Role          Role           `json:"role"`
	Content       string         `json:"content,omitempty"`
	ContentBlocks []ContentBlock `json:"contentBlocks,omitempty"`
	ToolCalls     []ToolCall     `json:"toolCalls,omitempty"`
	ToolID        string         `json:"toolId,omitempty"`
}

// StreamEvent is one streamed response fragment.
type StreamEvent struct {
	Delta string `json:"delta"`
	Done  bool   `json:"done"`
}

// ToolSpec describes a tool exposed to the model.
type ToolSpec struct {
	Name        string         `json:"name"`
	Description string         `json:"description"`
	Parameters  map[string]any `json:"parameters,omitempty"`
	Risk        string         `json:"risk,omitempty"`
}

// ResponseFormat requests provider-side structured output.
type ResponseFormat struct {
	Name   string         `json:"name,omitempty"`
	Schema map[string]any `json:"schema,omitempty"`
}

// ToolChoice values control whether the model may call tools.
const (
	ToolChoiceAuto     = "auto"
	ToolChoiceNone     = "none"
	ToolChoiceRequired = "required"
)

// Request is one model generation request.
type Request struct {
	Model          string          `json:"model,omitempty"`
	Messages       []Message       `json:"messages"`
	Tools          []ToolSpec      `json:"tools,omitempty"`
	ToolChoice     string          `json:"toolChoice,omitempty"`
	ResponseFormat *ResponseFormat `json:"responseFormat,omitempty"`
	Temperature    float64         `json:"temperature,omitempty"`
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

// StreamingModel is a model that can report text fragments while generating.
// Implementations must still return the complete response (including tool
// calls) when the stream finishes.
type StreamingModel interface {
	Model
	GenerateStream(ctx context.Context, req Request, onDelta func(delta string)) (Response, error)
}

// Provider is the chat-oriented provider contract.
type Provider interface {
	Chat(messages []Message) ([]Message, error)
	ChatStream(messages []Message) (<-chan StreamEvent, error)
}

// ModelRouter selects a provider for a task class.
type ModelRouter interface {
	Route(class TaskClass) (Provider, error)
}

// EchoProvider returns the input messages unchanged.
type EchoProvider struct{}

// Chat implements Provider.
func (EchoProvider) Chat(messages []Message) ([]Message, error) {
	return messages, nil
}

// ChatStream implements Provider.
func (EchoProvider) ChatStream(messages []Message) (<-chan StreamEvent, error) {
	ch := make(chan StreamEvent, len(messages))
	go func() {
		defer close(ch)
		for _, message := range messages {
			ch <- StreamEvent{Delta: message.Content, Done: true}
		}
	}()
	return ch, nil
}

// SingleProviderRouter always returns one provider.
type SingleProviderRouter struct {
	Provider Provider
}

// Route implements ModelRouter.
func (r SingleProviderRouter) Route(_ TaskClass) (Provider, error) {
	if r.Provider == nil {
		return nil, fmt.Errorf("no provider configured")
	}
	return r.Provider, nil
}
