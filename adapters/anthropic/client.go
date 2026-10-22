// Package anthropic adapts the Anthropic Messages API to the PRAXO-CORE model seam.
package anthropic

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"sort"
	"strings"
	"time"

	"github.com/axisvela/praxo-core/v2/pkg/model"
)

const (
	// DefaultBaseURL is the Anthropic API endpoint.
	DefaultBaseURL = "https://api.anthropic.com"
	// DefaultVersion is the Anthropic API version header.
	DefaultVersion = "2023-06-01"
	// DefaultMaxTokens is used when Adapter.MaxTokens is zero.
	DefaultMaxTokens = 1024
)

var (
	// ErrAPIKeyRequired is returned when the adapter has no API key.
	ErrAPIKeyRequired = errors.New("anthropic: API key is required")
	// ErrModelRequired is returned when the adapter has no model.
	ErrModelRequired = errors.New("anthropic: model is required")
)

// Adapter implements model.Model and model.StreamingModel for Anthropic.
type Adapter struct {
	BaseURL   string
	APIKey    string
	Model     string
	Version   string
	MaxTokens int
	HTTP      *http.Client
}

// Generate sends one Messages API request.
func (a Adapter) Generate(ctx context.Context, req model.Request) (model.Response, error) {
	if a.APIKey == "" {
		return model.Response{}, ErrAPIKeyRequired
	}
	if a.Model == "" {
		return model.Response{}, ErrModelRequired
	}
	body := a.request(req)
	httpReq, err := a.newRequest(ctx, body, false)
	if err != nil {
		return model.Response{}, err
	}
	resp, err := a.client().Do(httpReq)
	if err != nil {
		return model.Response{}, err
	}
	defer resp.Body.Close()
	payload, err := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if err != nil {
		return model.Response{}, err
	}
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return model.Response{}, fmt.Errorf("anthropic: %s: %s", resp.Status, strings.TrimSpace(string(payload)))
	}
	var decoded apiResponse
	if err := json.Unmarshal(payload, &decoded); err != nil {
		return model.Response{}, err
	}
	if decoded.Error != nil {
		return model.Response{}, fmt.Errorf("anthropic: %s", decoded.Error.Message)
	}
	content, calls := parseContent(decoded.Content)
	return model.Response{
		Message: model.Message{
			Role:      model.RoleAssistant,
			Content:   content,
			ToolCalls: calls,
		},
		Usage: model.Usage{
			InputTokens:  decoded.Usage.InputTokens,
			OutputTokens: decoded.Usage.OutputTokens,
			CachedTokens: decoded.Usage.CacheReadInputTokens,
		},
		FinishReason: decoded.StopReason,
	}, nil
}

// GenerateStream streams text deltas and returns the complete response.
func (a Adapter) GenerateStream(ctx context.Context, req model.Request, onDelta func(string)) (model.Response, error) {
	if a.APIKey == "" {
		return model.Response{}, ErrAPIKeyRequired
	}
	if a.Model == "" {
		return model.Response{}, ErrModelRequired
	}
	body := a.request(req)
	httpReq, err := a.newRequest(ctx, body, true)
	if err != nil {
		return model.Response{}, err
	}
	resp, err := a.client().Do(httpReq)
	if err != nil {
		return model.Response{}, err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		payload, _ := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
		return model.Response{}, fmt.Errorf("anthropic: %s: %s", resp.Status, strings.TrimSpace(string(payload)))
	}

	type blockState struct {
		kind  string
		id    string
		name  string
		input map[string]any
		args  strings.Builder
	}
	blocks := map[int]*blockState{}
	var content strings.Builder
	var inputTokens, outputTokens, cachedTokens int64
	stopReason := ""

	scanner := bufio.NewScanner(resp.Body)
	scanner.Buffer(make([]byte, 64*1024), 1<<20)
streamLoop:
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, ":") || !strings.HasPrefix(line, "data:") {
			continue
		}
		data := strings.TrimSpace(strings.TrimPrefix(line, "data:"))
		if data == "" || data == "[DONE]" {
			continue
		}
		var event apiStreamEvent
		if err := json.Unmarshal([]byte(data), &event); err != nil {
			return model.Response{}, err
		}
		if event.Error != nil {
			return model.Response{}, fmt.Errorf("anthropic: %s", event.Error.Message)
		}
		switch event.Type {
		case "message_start":
			if event.Message != nil {
				inputTokens = event.Message.Usage.InputTokens
				cachedTokens = event.Message.Usage.CacheReadInputTokens
			}
		case "content_block_start":
			if event.ContentBlock != nil {
				block := &blockState{
					kind:  event.ContentBlock.Type,
					id:    event.ContentBlock.ID,
					name:  event.ContentBlock.Name,
					input: event.ContentBlock.Input,
				}
				if event.ContentBlock.Text != "" {
					content.WriteString(event.ContentBlock.Text)
					if onDelta != nil {
						onDelta(event.ContentBlock.Text)
					}
				}
				blocks[event.Index] = block
			}
		case "content_block_delta":
			block := blocks[event.Index]
			if block == nil {
				block = &blockState{}
				blocks[event.Index] = block
			}
			if event.Delta != nil {
				switch event.Delta.Type {
				case "text_delta":
					content.WriteString(event.Delta.Text)
					if onDelta != nil {
						onDelta(event.Delta.Text)
					}
				case "input_json_delta":
					block.args.WriteString(event.Delta.PartialJSON)
				}
			}
		case "message_delta":
			if event.Delta != nil && event.Delta.StopReason != "" {
				stopReason = event.Delta.StopReason
			}
			if event.Usage != nil {
				outputTokens = event.Usage.OutputTokens
				if event.Usage.InputTokens != 0 {
					inputTokens = event.Usage.InputTokens
				}
			}
		case "message_stop":
			break streamLoop
		}
	}
	if err := scanner.Err(); err != nil {
		return model.Response{}, err
	}

	indexes := make([]int, 0, len(blocks))
	for index := range blocks {
		indexes = append(indexes, index)
	}
	sort.Ints(indexes)
	calls := make([]model.ToolCall, 0, len(indexes))
	for _, index := range indexes {
		block := blocks[index]
		if block.kind != "tool_use" {
			continue
		}
		arguments := block.input
		if block.args.Len() > 0 {
			arguments = map[string]any{}
			if err := json.Unmarshal([]byte(block.args.String()), &arguments); err != nil {
				return model.Response{}, fmt.Errorf("anthropic: tool %s arguments: %w", block.name, err)
			}
		}
		if arguments == nil {
			arguments = map[string]any{}
		}
		calls = append(calls, model.ToolCall{
			ID:        block.id,
			Name:      block.name,
			Arguments: arguments,
		})
	}
	return model.Response{
		Message: model.Message{
			Role:      model.RoleAssistant,
			Content:   content.String(),
			ToolCalls: calls,
		},
		Usage: model.Usage{
			InputTokens:  inputTokens,
			OutputTokens: outputTokens,
			CachedTokens: cachedTokens,
		},
		FinishReason: stopReason,
	}, nil
}

func (a Adapter) request(req model.Request) apiRequest {
	system, messages := buildMessages(req.Messages)
	tools := buildTools(req.Tools)
	body := apiRequest{
		Model:       a.Model,
		MaxTokens:   a.maxTokens(),
		System:      system,
		Messages:    messages,
		Tools:       tools,
		Temperature: req.Temperature,
	}
	if len(tools) > 0 {
		body.ToolChoice = buildToolChoice(req.ToolChoice)
	}
	return body
}

func (a Adapter) newRequest(ctx context.Context, body apiRequest, stream bool) (*http.Request, error) {
	body.Stream = stream
	raw, err := json.Marshal(body)
	if err != nil {
		return nil, err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, a.endpoint(), bytes.NewReader(raw))
	if err != nil {
		return nil, err
	}
	req.Header.Set("content-type", "application/json")
	req.Header.Set("x-api-key", a.APIKey)
	req.Header.Set("anthropic-version", a.version())
	if stream {
		req.Header.Set("accept", "text/event-stream")
	}
	return req, nil
}

func (a Adapter) endpoint() string {
	base := a.BaseURL
	if base == "" {
		base = DefaultBaseURL
	}
	return strings.TrimRight(base, "/") + "/v1/messages"
}

func (a Adapter) version() string {
	if a.Version == "" {
		return DefaultVersion
	}
	return a.Version
}

func (a Adapter) maxTokens() int {
	if a.MaxTokens <= 0 {
		return DefaultMaxTokens
	}
	return a.MaxTokens
}

func (a Adapter) client() *http.Client {
	if a.HTTP == nil {
		return &http.Client{Timeout: 120 * time.Second}
	}
	return a.HTTP
}

func buildMessages(messages []model.Message) (string, []apiMessage) {
	var system []string
	out := make([]apiMessage, 0, len(messages))
	var toolResults []apiContent
	flush := func() {
		if len(toolResults) == 0 {
			return
		}
		out = append(out, apiMessage{Role: "user", Content: toolResults})
		toolResults = nil
	}
	for _, message := range messages {
		switch message.Role {
		case model.RoleSystem:
			if message.Content != "" {
				system = append(system, message.Content)
			}
		case model.RoleTool:
			toolResults = append(toolResults, apiContent{
				Type:      "tool_result",
				ToolUseID: message.ToolID,
				Content:   message.Content,
			})
		default:
			flush()
			content := messageContent(message)
			if len(content) > 0 {
				out = append(out, apiMessage{Role: message.Role, Content: content})
			}
		}
	}
	flush()
	return strings.Join(system, "\n\n"), out
}

func messageContent(message model.Message) []apiContent {
	var content []apiContent
	if message.Content != "" {
		content = append(content, apiContent{Type: "text", Text: message.Content})
	}
	for _, block := range message.ContentBlocks {
		if block.Type == "text" && block.Text != "" {
			content = append(content, apiContent{Type: "text", Text: block.Text})
		}
	}
	for _, call := range message.ToolCalls {
		content = append(content, apiContent{
			Type:  "tool_use",
			ID:    call.ID,
			Name:  call.Name,
			Input: call.Arguments,
		})
	}
	return content
}

func buildTools(specs []model.ToolSpec) []apiTool {
	tools := make([]apiTool, 0, len(specs))
	for _, spec := range specs {
		schema := spec.Parameters
		if schema == nil {
			schema = map[string]any{"type": "object", "properties": map[string]any{}}
		}
		tools = append(tools, apiTool{
			Name:        spec.Name,
			Description: spec.Description,
			InputSchema: schema,
		})
	}
	return tools
}

func buildToolChoice(choice string) any {
	switch choice {
	case model.ToolChoiceAuto:
		return map[string]any{"type": "auto"}
	case model.ToolChoiceRequired:
		return map[string]any{"type": "any"}
	case model.ToolChoiceNone:
		return map[string]any{"type": "none"}
	default:
		return nil
	}
}

func parseContent(blocks []apiContent) (string, []model.ToolCall) {
	var text []string
	var calls []model.ToolCall
	for _, block := range blocks {
		switch block.Type {
		case "text":
			text = append(text, block.Text)
		case "tool_use":
			arguments := block.Input
			if arguments == nil {
				arguments = map[string]any{}
			}
			calls = append(calls, model.ToolCall{
				ID:        block.ID,
				Name:      block.Name,
				Arguments: arguments,
			})
		}
	}
	return strings.Join(text, ""), calls
}

type apiRequest struct {
	Model       string       `json:"model"`
	MaxTokens   int          `json:"max_tokens"`
	System      string       `json:"system,omitempty"`
	Messages    []apiMessage `json:"messages"`
	Tools       []apiTool    `json:"tools,omitempty"`
	ToolChoice  any          `json:"tool_choice,omitempty"`
	Temperature float64      `json:"temperature,omitempty"`
	Stream      bool         `json:"stream,omitempty"`
}

type apiMessage struct {
	Role    string       `json:"role"`
	Content []apiContent `json:"content"`
}

type apiContent struct {
	Type      string         `json:"type"`
	Text      string         `json:"text,omitempty"`
	ID        string         `json:"id,omitempty"`
	Name      string         `json:"name,omitempty"`
	Input     map[string]any `json:"input,omitempty"`
	ToolUseID string         `json:"tool_use_id,omitempty"`
	Content   any            `json:"content,omitempty"`
}

type apiTool struct {
	Name        string         `json:"name"`
	Description string         `json:"description"`
	InputSchema map[string]any `json:"input_schema"`
}

type apiUsage struct {
	InputTokens              int64 `json:"input_tokens"`
	OutputTokens             int64 `json:"output_tokens"`
	CacheCreationInputTokens int64 `json:"cache_creation_input_tokens"`
	CacheReadInputTokens     int64 `json:"cache_read_input_tokens"`
}

type apiError struct {
	Type    string `json:"type"`
	Message string `json:"message"`
}

type apiResponse struct {
	Type       string       `json:"type"`
	Content    []apiContent `json:"content"`
	StopReason string       `json:"stop_reason"`
	Usage      apiUsage     `json:"usage"`
	Error      *apiError    `json:"error"`
}

type apiStreamEvent struct {
	Type    string `json:"type"`
	Index   int    `json:"index"`
	Message *struct {
		Usage apiUsage `json:"usage"`
	} `json:"message"`
	ContentBlock *apiContent `json:"content_block"`
	Delta        *struct {
		Type        string `json:"type"`
		Text        string `json:"text"`
		PartialJSON string `json:"partial_json"`
		StopReason  string `json:"stop_reason"`
	} `json:"delta"`
	Usage *apiUsage `json:"usage"`
	Error *apiError `json:"error"`
}
