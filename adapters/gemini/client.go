// Package gemini adapts the Gemini generateContent API to the PRAXO-CORE model seam.
package gemini

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/axisvela/praxo-core/v2/pkg/model"
)

const (
	// DefaultBaseURL is the Gemini API endpoint.
	DefaultBaseURL = "https://generativelanguage.googleapis.com"
)

var (
	// ErrAPIKeyRequired is returned when the adapter has no API key.
	ErrAPIKeyRequired = errors.New("gemini: API key is required")
	// ErrModelRequired is returned when the adapter has no model.
	ErrModelRequired = errors.New("gemini: model is required")
)

// Adapter implements model.Model and model.StreamingModel for Gemini.
type Adapter struct {
	BaseURL string
	APIKey  string
	Model   string
	HTTP    *http.Client
	// MaxTokens maps to generationConfig.maxOutputTokens when positive.
	MaxTokens int
}

// Generate sends one generateContent request.
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
		return model.Response{}, fmt.Errorf("gemini: %s: %s", resp.Status, strings.TrimSpace(string(payload)))
	}
	var decoded apiResponse
	if err := json.Unmarshal(payload, &decoded); err != nil {
		return model.Response{}, err
	}
	if decoded.Error != nil {
		return model.Response{}, fmt.Errorf("gemini: %s", decoded.Error.Message)
	}
	if len(decoded.Candidates) == 0 {
		return model.Response{}, fmt.Errorf("gemini: empty response")
	}
	candidate := decoded.Candidates[0]
	content, calls := parseParts(candidate.Content.Parts)
	return model.Response{
		Message: model.Message{
			Role:      model.RoleAssistant,
			Content:   content,
			ToolCalls: calls,
		},
		Usage: model.Usage{
			InputTokens:  decoded.UsageMetadata.PromptTokenCount,
			OutputTokens: decoded.UsageMetadata.CandidatesTokenCount,
			CachedTokens: decoded.UsageMetadata.CachedContentTokenCount,
		},
		FinishReason: candidate.FinishReason,
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
		return model.Response{}, fmt.Errorf("gemini: %s: %s", resp.Status, strings.TrimSpace(string(payload)))
	}

	var content strings.Builder
	var calls []model.ToolCall
	finishReason := ""
	var usage apiUsage

	scanner := bufio.NewScanner(resp.Body)
	scanner.Buffer(make([]byte, 64*1024), 1<<20)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, ":") || !strings.HasPrefix(line, "data:") {
			continue
		}
		data := strings.TrimSpace(strings.TrimPrefix(line, "data:"))
		if data == "" || data == "[DONE]" {
			continue
		}
		var chunk apiResponse
		if err := json.Unmarshal([]byte(data), &chunk); err != nil {
			return model.Response{}, err
		}
		if chunk.Error != nil {
			return model.Response{}, fmt.Errorf("gemini: %s", chunk.Error.Message)
		}
		if chunk.UsageMetadata.PromptTokenCount != 0 ||
			chunk.UsageMetadata.CandidatesTokenCount != 0 ||
			chunk.UsageMetadata.CachedContentTokenCount != 0 {
			usage = chunk.UsageMetadata
		}
		if len(chunk.Candidates) == 0 {
			continue
		}
		candidate := chunk.Candidates[0]
		if candidate.FinishReason != "" {
			finishReason = candidate.FinishReason
		}
		for _, part := range candidate.Content.Parts {
			if part.Text != "" {
				content.WriteString(part.Text)
				if onDelta != nil {
					onDelta(part.Text)
				}
			}
			if part.FunctionCall != nil {
				calls = append(calls, model.ToolCall{
					ID:        fmt.Sprintf("call-%d", len(calls)+1),
					Name:      part.FunctionCall.Name,
					Arguments: part.FunctionCall.Args,
				})
			}
		}
	}
	if err := scanner.Err(); err != nil {
		return model.Response{}, err
	}
	return model.Response{
		Message: model.Message{
			Role:      model.RoleAssistant,
			Content:   content.String(),
			ToolCalls: calls,
		},
		Usage: model.Usage{
			InputTokens:  usage.PromptTokenCount,
			OutputTokens: usage.CandidatesTokenCount,
			CachedTokens: usage.CachedContentTokenCount,
		},
		FinishReason: finishReason,
	}, nil
}

func (a Adapter) request(req model.Request) apiRequest {
	system, contents := buildContents(req.Messages)
	tools := buildTools(req.Tools)
	body := apiRequest{
		SystemInstruction: system,
		Contents:          contents,
		Tools:             tools,
	}
	if len(tools) > 0 {
		body.ToolConfig = &apiToolConfig{FunctionCallingConfig: apiFunctionCallingConfig{
			Mode: toolMode(req.ToolChoice),
		}}
	}
	if req.Temperature != 0 || a.MaxTokens > 0 {
		body.GenerationConfig = &apiGenerationConfig{
			Temperature:     req.Temperature,
			MaxOutputTokens: a.MaxTokens,
		}
	}
	return body
}

func (a Adapter) newRequest(ctx context.Context, body apiRequest, stream bool) (*http.Request, error) {
	raw, err := json.Marshal(body)
	if err != nil {
		return nil, err
	}
	base := a.BaseURL
	if base == "" {
		base = DefaultBaseURL
	}
	path := strings.TrimRight(base, "/") + "/v1beta/models/" + url.PathEscape(a.Model) + ":generateContent"
	if stream {
		path = strings.TrimRight(base, "/") + "/v1beta/models/" + url.PathEscape(a.Model) + ":streamGenerateContent?alt=sse"
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, path, bytes.NewReader(raw))
	if err != nil {
		return nil, err
	}
	req.Header.Set("content-type", "application/json")
	req.Header.Set("x-goog-api-key", a.APIKey)
	if stream {
		req.Header.Set("accept", "text/event-stream")
	}
	return req, nil
}

func (a Adapter) client() *http.Client {
	if a.HTTP == nil {
		return &http.Client{Timeout: 120 * time.Second}
	}
	return a.HTTP
}

func buildContents(messages []model.Message) (*apiContent, []apiContent) {
	var systemParts []apiPart
	var contents []apiContent
	var toolParts []apiPart
	names := map[string]string{}
	flushTools := func() {
		if len(toolParts) == 0 {
			return
		}
		contents = append(contents, apiContent{Role: "user", Parts: toolParts})
		toolParts = nil
	}
	for _, message := range messages {
		switch message.Role {
		case model.RoleSystem:
			if message.Content != "" {
				systemParts = append(systemParts, apiPart{Text: message.Content})
			}
		case model.RoleTool:
			name := names[message.ToolID]
			if name == "" {
				name = message.ToolID
			}
			if name == "" {
				name = "tool"
			}
			toolParts = append(toolParts, apiPart{FunctionResponse: &apiFunctionResponse{
				Name:     name,
				Response: map[string]any{"result": message.Content},
			}})
		default:
			flushTools()
			parts := messageParts(message)
			if len(parts) == 0 {
				continue
			}
			role := "user"
			if message.Role == model.RoleAssistant {
				role = "model"
			}
			contents = append(contents, apiContent{Role: role, Parts: parts})
			for _, call := range message.ToolCalls {
				if call.ID != "" && call.Name != "" {
					names[call.ID] = call.Name
				}
			}
		}
	}
	flushTools()
	if len(systemParts) == 0 {
		return nil, contents
	}
	return &apiContent{Parts: systemParts}, contents
}

func messageParts(message model.Message) []apiPart {
	var parts []apiPart
	if message.Content != "" {
		parts = append(parts, apiPart{Text: message.Content})
	}
	for _, block := range message.ContentBlocks {
		if block.Type == "text" && block.Text != "" {
			parts = append(parts, apiPart{Text: block.Text})
		}
	}
	for _, call := range message.ToolCalls {
		parts = append(parts, apiPart{FunctionCall: &apiFunctionCall{
			Name: call.Name,
			Args: call.Arguments,
		}})
	}
	return parts
}

func buildTools(specs []model.ToolSpec) []apiToolGroup {
	if len(specs) == 0 {
		return nil
	}
	declarations := make([]apiFunctionDeclaration, 0, len(specs))
	for _, spec := range specs {
		parameters := spec.Parameters
		if parameters == nil {
			parameters = map[string]any{"type": "object", "properties": map[string]any{}}
		}
		declarations = append(declarations, apiFunctionDeclaration{
			Name:        spec.Name,
			Description: spec.Description,
			Parameters:  parameters,
		})
	}
	return []apiToolGroup{{FunctionDeclarations: declarations}}
}

func toolMode(choice string) string {
	switch choice {
	case model.ToolChoiceRequired:
		return "ANY"
	case model.ToolChoiceNone:
		return "NONE"
	default:
		return "AUTO"
	}
}

func parseParts(parts []apiPart) (string, []model.ToolCall) {
	var text strings.Builder
	var calls []model.ToolCall
	for _, part := range parts {
		if part.Text != "" {
			text.WriteString(part.Text)
		}
		if part.FunctionCall != nil {
			calls = append(calls, model.ToolCall{
				ID:        fmt.Sprintf("call-%d", len(calls)+1),
				Name:      part.FunctionCall.Name,
				Arguments: part.FunctionCall.Args,
			})
		}
	}
	return text.String(), calls
}

type apiRequest struct {
	SystemInstruction *apiContent          `json:"system_instruction,omitempty"`
	Contents          []apiContent         `json:"contents"`
	Tools             []apiToolGroup       `json:"tools,omitempty"`
	ToolConfig        *apiToolConfig       `json:"toolConfig,omitempty"`
	GenerationConfig  *apiGenerationConfig `json:"generationConfig,omitempty"`
}

type apiContent struct {
	Role  string    `json:"role,omitempty"`
	Parts []apiPart `json:"parts"`
}

type apiPart struct {
	Text             string               `json:"text,omitempty"`
	FunctionCall     *apiFunctionCall     `json:"functionCall,omitempty"`
	FunctionResponse *apiFunctionResponse `json:"functionResponse,omitempty"`
}

type apiFunctionCall struct {
	Name string         `json:"name"`
	Args map[string]any `json:"args,omitempty"`
}

type apiFunctionResponse struct {
	Name     string         `json:"name"`
	Response map[string]any `json:"response"`
}

type apiToolGroup struct {
	FunctionDeclarations []apiFunctionDeclaration `json:"functionDeclarations"`
}

type apiFunctionDeclaration struct {
	Name        string         `json:"name"`
	Description string         `json:"description"`
	Parameters  map[string]any `json:"parameters,omitempty"`
}

type apiToolConfig struct {
	FunctionCallingConfig apiFunctionCallingConfig `json:"functionCallingConfig"`
}

type apiFunctionCallingConfig struct {
	Mode string `json:"mode"`
}

type apiGenerationConfig struct {
	Temperature     float64 `json:"temperature,omitempty"`
	MaxOutputTokens int     `json:"maxOutputTokens,omitempty"`
}

type apiUsage struct {
	PromptTokenCount        int64 `json:"promptTokenCount"`
	CandidatesTokenCount    int64 `json:"candidatesTokenCount"`
	CachedContentTokenCount int64 `json:"cachedContentTokenCount"`
}

type apiResponse struct {
	Candidates []struct {
		Content struct {
			Role  string    `json:"role"`
			Parts []apiPart `json:"parts"`
		} `json:"content"`
		FinishReason string `json:"finishReason"`
	} `json:"candidates"`
	UsageMetadata apiUsage `json:"usageMetadata"`
	Error         *struct {
		Code    int    `json:"code"`
		Message string `json:"message"`
		Status  string `json:"status"`
	} `json:"error"`
}
