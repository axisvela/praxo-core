package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/axisvela/praxo-core/v2/pkg/agent"
	"github.com/axisvela/praxo-core/v2/pkg/event"
	"github.com/axisvela/praxo-core/v2/pkg/model"
	"github.com/axisvela/praxo-core/v2/pkg/policy"
	"github.com/axisvela/praxo-core/v2/pkg/tool"
)

type chatModel struct {
	BaseURL string
	APIKey  string
	Model   string
	HTTP    *http.Client
}

func (m chatModel) Generate(ctx context.Context, req model.Request) (model.Response, error) {
	body := apiRequest{
		Model:       m.Model,
		Messages:    apiMessages(req.Messages),
		Tools:       apiTools(req.Tools),
		ToolChoice:  req.ToolChoice,
		Temperature: req.Temperature,
	}
	raw, err := json.Marshal(body)
	if err != nil {
		return model.Response{}, err
	}
	url := strings.TrimRight(m.BaseURL, "/") + "/chat/completions"
	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(raw))
	if err != nil {
		return model.Response{}, err
	}
	httpReq.Header.Set("Content-Type", "application/json")
	if m.APIKey != "" {
		httpReq.Header.Set("Authorization", "Bearer "+m.APIKey)
	}
	client := m.HTTP
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
		return model.Response{}, fmt.Errorf("quickstart: %s: %s", resp.Status, strings.TrimSpace(string(payload)))
	}
	var decoded apiResponse
	if err := json.Unmarshal(payload, &decoded); err != nil {
		return model.Response{}, err
	}
	if decoded.Error != nil {
		return model.Response{}, fmt.Errorf("quickstart: %s", decoded.Error.Message)
	}
	if len(decoded.Choices) == 0 {
		return model.Response{}, fmt.Errorf("quickstart: empty response")
	}
	choice := decoded.Choices[0]
	message := model.Message{Role: model.RoleAssistant, Content: choice.Message.Content}
	for _, call := range choice.Message.ToolCalls {
		arguments := map[string]any{}
		if call.Function.Arguments != "" {
			if err := json.Unmarshal([]byte(call.Function.Arguments), &arguments); err != nil {
				return model.Response{}, fmt.Errorf("quickstart: tool %s arguments: %w", call.Function.Name, err)
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

type timeTool struct{}

func (timeTool) Name() string { return "get_time" }

func (timeTool) Description() string { return "Return the current local time in RFC3339 format." }

func (timeTool) Spec() model.ToolSpec {
	return model.ToolSpec{
		Name:        "get_time",
		Description: "Return the current local time in RFC3339 format.",
		Parameters: map[string]any{
			"type":       "object",
			"properties": map[string]any{},
		},
	}
}

func (timeTool) Invoke(context.Context, map[string]any) (any, error) {
	return time.Now().Format(time.RFC3339), nil
}

func main() {
	baseURL := envOr("PRAXO_BASE_URL", "http://localhost:11434/v1")
	modelName := envOr("PRAXO_MODEL", "llama3.2")
	prompt := envOr("PRAXO_PROMPT", "What time is it? Use the get_time tool.")

	tools := tool.NewRegistry()
	tools.Register(timeTool{})

	ag, err := agent.New(agent.Options{
		Model: chatModel{
			BaseURL: baseURL,
			APIKey:  os.Getenv("PRAXO_API_KEY"),
			Model:   modelName,
			HTTP:    &http.Client{Timeout: 120 * time.Second},
		},
		SystemPrompt: "You are a concise assistant. Use tools when they help.",
		Tools:        tools,
		MaxSteps:     4,
		Events: event.FuncSink(func(_ context.Context, ev event.Event) error {
			fmt.Println("event:", ev.Type)
			return nil
		}),
		Policy: policy.FuncHook(func(context.Context, policy.Action) (policy.Decision, error) {
			return policy.Decision{Allowed: true}, nil
		}),
	})
	if err != nil {
		log.Fatal(err)
	}
	result, err := ag.Run(context.Background(), agent.Session{
		ID:          "quickstart",
		TenantID:    "local",
		WorkspaceID: "default",
	}, prompt)
	if err != nil {
		log.Fatalf("quickstart: %v\n\nConfigure PRAXO_BASE_URL (current %s), PRAXO_MODEL (current %s), and PRAXO_API_KEY as needed.", err, baseURL, modelName)
	}
	fmt.Println(result.Output)
}

func envOr(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}
