// Package openaicompat adapts OpenAI-compatible chat completion endpoints to
// the PRAXO-CORE model seam.
package openaicompat

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"github.com/axisvela/praxo-core/v2/pkg/model"
)

// ErrBaseURLRequired is returned when the adapter has no endpoint.
var ErrBaseURLRequired = errors.New("openaicompat: base URL is required")

// Adapter implements model.Model for OpenAI-compatible endpoints.
type Adapter struct {
	BaseURL string
	APIKey  string
	Model   string
	HTTP    *http.Client
}

// Generate sends one chat completion request.
func (a Adapter) Generate(ctx context.Context, req model.Request) (model.Response, error) {
	if a.BaseURL == "" {
		return model.Response{}, ErrBaseURLRequired
	}
	body := apiRequest{
		Model:       a.Model,
		Messages:    apiMessages(req.Messages),
		Tools:       apiTools(req.Tools),
		ToolChoice:  req.ToolChoice,
		Temperature: req.Temperature,
	}
	raw, err := json.Marshal(body)
	if err != nil {
		return model.Response{}, err
	}
	url := strings.TrimRight(a.BaseURL, "/") + "/chat/completions"
	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(raw))
	if err != nil {
		return model.Response{}, err
	}
	httpReq.Header.Set("Content-Type", "application/json")
	if a.APIKey != "" {
		httpReq.Header.Set("Authorization", "Bearer "+a.APIKey)
	}
	client := a.HTTP
	if client == nil {
		client = &http.Client{Timeout: 120 * time.Second}
	}
	resp, err := client.Do(httpReq)
	if err != nil {
		return model.Response{}, err
	}
	defer resp.Body.Close()
	payload, err := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if err != nil {
		return model.Response{}, err
	}
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return model.Response{}, fmt.Errorf("openaicompat: %s: %s", resp.Status, strings.TrimSpace(string(payload)))
	}
	var decoded apiResponse
	if err := json.Unmarshal(payload, &decoded); err != nil {
		return model.Response{}, err
	}
	if decoded.Error != nil {
		return model.Response{}, fmt.Errorf("openaicompat: %s", decoded.Error.Message)
	}
	if len(decoded.Choices) == 0 {
		return model.Response{}, fmt.Errorf("openaicompat: empty response")
	}
	choice := decoded.Choices[0]
	message := model.Message{Role: model.RoleAssistant, Content: choice.Message.Content}
	for _, call := range choice.Message.ToolCalls {
		arguments := map[string]any{}
		if call.Function.Arguments != "" {
			if err := json.Unmarshal([]byte(call.Function.Arguments), &arguments); err != nil {
				return model.Response{}, fmt.Errorf("openaicompat: tool %s arguments: %w", call.Function.Name, err)
			}
		}
		message.ToolCalls = append(message.ToolCalls, model.ToolCall{
			ID:        call.ID,
			Name:      call.Function.Name,
			Arguments: arguments,
		})
	}
	return model.Response{
		Message: message,
		Usage: model.Usage{
			InputTokens:  decoded.Usage.PromptTokens,
			OutputTokens: decoded.Usage.CompletionTokens,
		},
		FinishReason: choice.FinishReason,
	}, nil
}

type apiRequest struct {
	Model       string       `json:"model"`
	Messages    []apiMessage `json:"messages"`
	Tools       []apiTool    `json:"tools,omitempty"`
	ToolChoice  string       `json:"tool_choice,omitempty"`
	Temperature float64      `json:"temperature,omitempty"`
}

type apiMessage struct {
	Role       string        `json:"role"`
	Content    string        `json:"content,omitempty"`
	ToolCalls  []apiToolCall `json:"tool_calls,omitempty"`
	ToolCallID string        `json:"tool_call_id,omitempty"`
}

type apiToolCall struct {
	ID       string          `json:"id"`
	Type     string          `json:"type"`
	Function apiFunctionCall `json:"function"`
}

type apiFunctionCall struct {
	Name      string `json:"name"`
	Arguments string `json:"arguments"`
}

type apiTool struct {
	Type     string      `json:"type"`
	Function apiFunction `json:"function"`
}

type apiFunction struct {
	Name        string         `json:"name"`
	Description string         `json:"description"`
	Parameters  map[string]any `json:"parameters,omitempty"`
}

type apiResponse struct {
	Choices []struct {
		Message      apiMessage `json:"message"`
		FinishReason string     `json:"finish_reason"`
	} `json:"choices"`
	Usage struct {
		PromptTokens     int64 `json:"prompt_tokens"`
		CompletionTokens int64 `json:"completion_tokens"`
	} `json:"usage"`
	Error *struct {
		Message string `json:"message"`
	} `json:"error"`
}

func apiMessages(messages []model.Message) []apiMessage {
	out := make([]apiMessage, 0, len(messages))
	for _, message := range messages {
		item := apiMessage{
			Role:       message.Role,
			Content:    message.Content,
			ToolCallID: message.ToolID,
		}
		for _, call := range message.ToolCalls {
			arguments, _ := json.Marshal(call.Arguments)
			item.ToolCalls = append(item.ToolCalls, apiToolCall{
				ID:   call.ID,
				Type: "function",
				Function: apiFunctionCall{
					Name:      call.Name,
					Arguments: string(arguments),
				},
			})
		}
		out = append(out, item)
	}
	return out
}

func apiTools(specs []model.ToolSpec) []apiTool {
	out := make([]apiTool, 0, len(specs))
	for _, spec := range specs {
		out = append(out, apiTool{
			Type: "function",
			Function: apiFunction{
				Name:        spec.Name,
				Description: spec.Description,
				Parameters:  spec.Parameters,
			},
		})
	}
	return out
}
