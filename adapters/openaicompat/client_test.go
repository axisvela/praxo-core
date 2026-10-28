package openaicompat

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/axisvela/praxo-core/v2/pkg/model"
)

var (
	_ model.Model          = Adapter{}
	_ model.StreamingModel = Adapter{}
)

func TestAdapterRequiresBaseURL(t *testing.T) {
	if _, err := (Adapter{}).Generate(context.Background(), model.Request{}); !errors.Is(err, ErrBaseURLRequired) {
		t.Fatalf("got %v, want %v", err, ErrBaseURLRequired)
	}
}

func TestAdapterGenerate(t *testing.T) {
	var gotAuth, gotPath string
	var gotRequest apiRequest
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotAuth = r.Header.Get("Authorization")
		gotPath = r.URL.Path
		if err := json.NewDecoder(r.Body).Decode(&gotRequest); err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{
			"choices": [{
				"message": {
					"role": "assistant",
					"tool_calls": [{
						"id": "call-1",
						"type": "function",
						"function": {"name": "get_time", "arguments": "{}"}
					}]
				},
				"finish_reason": "tool_calls"
			}],
			"usage": {"prompt_tokens": 7, "completion_tokens": 3, "prompt_tokens_details": {"cached_tokens": 2}}
		}`))
	}))
	defer server.Close()

	adapter := Adapter{
		BaseURL: server.URL,
		APIKey:  "secret",
		Model:   "test-model",
		HTTP:    server.Client(),
	}
	response, err := adapter.Generate(context.Background(), model.Request{
		Messages:   []model.Message{{Role: model.RoleUser, Content: "time?"}},
		Tools:      []model.ToolSpec{{Name: "get_time", Description: "Get time"}},
		ToolChoice: model.ToolChoiceAuto,
	})
	if err != nil {
		t.Fatal(err)
	}
	if gotPath != "/chat/completions" {
		t.Fatalf("path = %q", gotPath)
	}
	if gotAuth != "Bearer secret" {
		t.Fatalf("authorization = %q", gotAuth)
	}
	if gotRequest.Model != "test-model" || len(gotRequest.Messages) != 1 {
		t.Fatalf("request = %#v", gotRequest)
	}
	if len(gotRequest.Tools) != 1 || gotRequest.Tools[0].Function.Name != "get_time" {
		t.Fatalf("tools = %#v", gotRequest.Tools)
	}
	if len(response.Message.ToolCalls) != 1 {
		t.Fatalf("tool calls = %#v", response.Message.ToolCalls)
	}
	call := response.Message.ToolCalls[0]
	if call.ID != "call-1" || call.Name != "get_time" || len(call.Arguments) != 0 {
		t.Fatalf("call = %#v", call)
	}
	if response.Usage.InputTokens != 7 || response.Usage.OutputTokens != 3 || response.Usage.CachedTokens != 2 {
		t.Fatalf("usage = %#v", response.Usage)
	}
	if response.FinishReason != "tool_calls" {
		t.Fatalf("finish reason = %q", response.FinishReason)
	}
}

func TestAdapterHTTPError(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		http.Error(w, "bad model", http.StatusBadRequest)
	}))
	defer server.Close()

	adapter := Adapter{BaseURL: server.URL, Model: "bad", HTTP: server.Client()}
	_, err := adapter.Generate(context.Background(), model.Request{})
	if err == nil {
		t.Fatal("expected an error")
	}
	if !strings.Contains(err.Error(), "bad model") {
		t.Fatalf("error = %v", err)
	}
}

func TestAdapterGenerateStream(t *testing.T) {
	var gotRequest apiRequest
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if err := json.NewDecoder(r.Body).Decode(&gotRequest); err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
		w.Header().Set("Content-Type", "text/event-stream")
		flusher, _ := w.(http.Flusher)
		write := func(value string) {
			_, _ = fmt.Fprint(w, value)
			if flusher != nil {
				flusher.Flush()
			}
		}
		write("data: {\"choices\":[{\"delta\":{\"content\":\"he\"}}]}\n\n")
		write("data: {\"choices\":[{\"delta\":{\"content\":\"llo\"}}]}\n\n")
		write("data: {\"choices\":[{\"delta\":{\"tool_calls\":[{\"index\":0,\"id\":\"call-1\",\"function\":{\"name\":\"echo\",\"arguments\":\"{\\\"value\\\":\"}}]}}]}\n\n")
		write("data: {\"choices\":[{\"delta\":{\"tool_calls\":[{\"index\":0,\"function\":{\"arguments\":\"\\\"ok\\\"}\"}}]},\"finish_reason\":\"tool_calls\"}]}\n\n")
		write("data: {\"choices\":[],\"usage\":{\"prompt_tokens\":5,\"completion_tokens\":2,\"prompt_tokens_details\":{\"cached_tokens\":4}}}\n\n")
		write("data: [DONE]\n\n")
	}))
	defer server.Close()

	adapter := Adapter{BaseURL: server.URL, Model: "test-model", HTTP: server.Client(), IncludeUsage: true}
	var deltas []string
	response, err := adapter.GenerateStream(context.Background(), model.Request{
		Messages: []model.Message{{Role: model.RoleUser, Content: "hi"}},
	}, func(delta string) {
		deltas = append(deltas, delta)
	})
	if err != nil {
		t.Fatal(err)
	}
	if !gotRequest.Stream {
		t.Fatal("expected stream=true")
	}
	if gotRequest.StreamOptions == nil || !gotRequest.StreamOptions.IncludeUsage {
		t.Fatalf("stream options = %#v", gotRequest.StreamOptions)
	}
	if response.Usage.InputTokens != 5 || response.Usage.OutputTokens != 2 || response.Usage.CachedTokens != 4 {
		t.Fatalf("usage = %#v", response.Usage)
	}
	if strings.Join(deltas, "") != "hello" {
		t.Fatalf("deltas = %#v", deltas)
	}
	if response.Message.Content != "hello" {
		t.Fatalf("content = %q", response.Message.Content)
	}
	if len(response.Message.ToolCalls) != 1 {
		t.Fatalf("tool calls = %#v", response.Message.ToolCalls)
	}
	call := response.Message.ToolCalls[0]
	if call.ID != "call-1" || call.Name != "echo" || call.Arguments["value"] != "ok" {
		t.Fatalf("call = %#v", call)
	}
	if response.FinishReason != "tool_calls" {
		t.Fatalf("finish reason = %q", response.FinishReason)
	}
}

func TestAdapterGenerateStreamRejectsTruncatedStream(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/event-stream")
		_, _ = fmt.Fprint(w, "data: {\"choices\":[{\"delta\":{\"content\":\"partial\"}}]}\n\n")
	}))
	defer server.Close()

	adapter := Adapter{BaseURL: server.URL, Model: "test-model", HTTP: server.Client()}
	response, err := adapter.GenerateStream(context.Background(), model.Request{
		Messages: []model.Message{{Role: model.RoleUser, Content: "hi"}},
	}, nil)
	if err == nil || !strings.Contains(err.Error(), "stream ended before completion") {
		t.Fatalf("response=%#v error=%v", response, err)
	}
}

func TestAdapterGenerateStreamAllowsFinishReasonWithoutDone(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/event-stream")
		_, _ = fmt.Fprint(w, "data: {\"choices\":[{\"delta\":{\"content\":\"ok\"},\"finish_reason\":\"stop\"}]}\n\n")
	}))
	defer server.Close()

	adapter := Adapter{BaseURL: server.URL, Model: "test-model", HTTP: server.Client()}
	response, err := adapter.GenerateStream(context.Background(), model.Request{
		Messages: []model.Message{{Role: model.RoleUser, Content: "hi"}},
	}, nil)
	if err != nil {
		t.Fatal(err)
	}
	if response.Message.Content != "ok" || response.FinishReason != "stop" {
		t.Fatalf("response = %#v", response)
	}
}

func TestAdapterGenerateStreamAllowsDoneWithoutFinishReason(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/event-stream")
		_, _ = fmt.Fprint(w, "data: {\"choices\":[{\"delta\":{\"content\":\"ok\"}}]}\n\n")
		_, _ = fmt.Fprint(w, "data: [DONE]\n\n")
	}))
	defer server.Close()

	adapter := Adapter{BaseURL: server.URL, Model: "test-model", HTTP: server.Client()}
	response, err := adapter.GenerateStream(context.Background(), model.Request{
		Messages: []model.Message{{Role: model.RoleUser, Content: "hi"}},
	}, nil)
	if err != nil {
		t.Fatal(err)
	}
	if response.Message.Content != "ok" || response.FinishReason != "" {
		t.Fatalf("response = %#v", response)
	}
}

func TestAdapterRequestBodyMapsMultimodalBlocks(t *testing.T) {
	body, err := (Adapter{Model: "test-model"}).requestBody(model.Request{
		Messages: []model.Message{{
			Role:    model.RoleUser,
			Content: "caption",
			ContentBlocks: []model.ContentBlock{
				{Type: "text", Text: "detail"},
				{Type: "image_url", ImageURL: "https://example.com/image.png"},
			},
		}},
	}, false)
	if err != nil {
		t.Fatal(err)
	}
	parts, ok := body.Messages[0].Content.([]apiContentPart)
	if !ok || len(parts) != 3 {
		t.Fatalf("content = %#v", body.Messages[0].Content)
	}
	if parts[0].Type != "text" || parts[0].Text != "caption" ||
		parts[1].Type != "text" || parts[1].Text != "detail" ||
		parts[2].Type != "image_url" || parts[2].ImageURL == nil ||
		parts[2].ImageURL.URL != "https://example.com/image.png" {
		t.Fatalf("parts = %#v", parts)
	}
}

func TestAdapterRequestJSONShape(t *testing.T) {
	body, err := (Adapter{Model: "test-model"}).requestBody(model.Request{
		Messages: []model.Message{{
			Role:    model.RoleUser,
			Content: "hi",
			ContentBlocks: []model.ContentBlock{
				{Type: "image_url", ImageURL: "https://example.com/image.png"},
			},
		}},
		ResponseFormat: &model.ResponseFormat{
			Name:   "answer",
			Schema: map[string]any{"type": "object"},
		},
	}, true)
	if err != nil {
		t.Fatal(err)
	}
	raw, err := json.Marshal(body)
	if err != nil {
		t.Fatal(err)
	}
	var decoded struct {
		Stream   bool `json:"stream"`
		Messages []struct {
			Content []struct {
				Type     string `json:"type"`
				Text     string `json:"text"`
				ImageURL *struct {
					URL string `json:"url"`
				} `json:"image_url"`
			} `json:"content"`
		} `json:"messages"`
		ResponseFormat *struct {
			Type       string `json:"type"`
			JSONSchema *struct {
				Name string `json:"name"`
			} `json:"json_schema"`
		} `json:"response_format"`
	}
	if err := json.Unmarshal(raw, &decoded); err != nil {
		t.Fatal(err)
	}
	if !decoded.Stream || len(decoded.Messages) != 1 || len(decoded.Messages[0].Content) != 2 {
		t.Fatalf("decoded = %#v", decoded)
	}
	if decoded.Messages[0].Content[1].ImageURL == nil ||
		decoded.Messages[0].Content[1].ImageURL.URL != "https://example.com/image.png" {
		t.Fatalf("image = %#v", decoded.Messages[0].Content[1])
	}
	if decoded.ResponseFormat == nil || decoded.ResponseFormat.Type != "json_schema" ||
		decoded.ResponseFormat.JSONSchema == nil || decoded.ResponseFormat.JSONSchema.Name != "answer" {
		t.Fatalf("response format = %#v", decoded.ResponseFormat)
	}
}

func TestAdapterRequestBodyRejectsUnsupportedBlock(t *testing.T) {
	_, err := (Adapter{Model: "test-model"}).requestBody(model.Request{
		Messages: []model.Message{{
			Role:          model.RoleUser,
			ContentBlocks: []model.ContentBlock{{Type: "data", Data: "AAAA"}},
		}},
	}, false)
	if err == nil || !strings.Contains(err.Error(), "unsupported content block type") {
		t.Fatalf("error = %v", err)
	}
}

func TestAdapterRequestBodyMapsResponseFormat(t *testing.T) {
	body, err := (Adapter{Model: "test-model"}).requestBody(model.Request{
		Messages: []model.Message{{Role: model.RoleUser, Content: "hi"}},
		ResponseFormat: &model.ResponseFormat{
			Name:   "answer",
			Schema: map[string]any{"type": "object"},
		},
	}, false)
	if err != nil {
		t.Fatal(err)
	}
	if body.ResponseFormat == nil || body.ResponseFormat.Type != "json_schema" ||
		body.ResponseFormat.JSONSchema == nil || body.ResponseFormat.JSONSchema.Name != "answer" {
		t.Fatalf("response format = %#v", body.ResponseFormat)
	}
}

func TestAdapterRequestBodyRejectsResponseFormatWithoutSchema(t *testing.T) {
	_, err := (Adapter{Model: "test-model"}).requestBody(model.Request{
		Messages:       []model.Message{{Role: model.RoleUser, Content: "hi"}},
		ResponseFormat: &model.ResponseFormat{Name: "answer"},
	}, false)
	if err == nil || !strings.Contains(err.Error(), "requires a schema") {
		t.Fatalf("error = %v", err)
	}
}
