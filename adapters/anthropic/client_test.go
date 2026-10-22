package anthropic

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

func TestAdapterRequiresCredentials(t *testing.T) {
	ctx := context.Background()
	if _, err := (Adapter{}).Generate(ctx, model.Request{}); !errors.Is(err, ErrAPIKeyRequired) {
		t.Fatalf("got %v, want %v", err, ErrAPIKeyRequired)
	}
	if _, err := (Adapter{APIKey: "key"}).Generate(ctx, model.Request{}); !errors.Is(err, ErrModelRequired) {
		t.Fatalf("got %v, want %v", err, ErrModelRequired)
	}
}

func TestAdapterGenerate(t *testing.T) {
	var gotRequest apiRequest
	var gotKey, gotVersion, gotPath string
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotKey = r.Header.Get("x-api-key")
		gotVersion = r.Header.Get("anthropic-version")
		gotPath = r.URL.Path
		if err := json.NewDecoder(r.Body).Decode(&gotRequest); err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{
			"type": "message",
			"content": [
				{"type": "text", "text": "hello"},
				{"type": "tool_use", "id": "toolu_1", "name": "get_time", "input": {"tz": "utc"}}
			],
			"stop_reason": "tool_use",
			"usage": {"input_tokens": 10, "output_tokens": 5, "cache_read_input_tokens": 2}
		}`))
	}))
	defer server.Close()

	adapter := Adapter{
		BaseURL:   server.URL,
		APIKey:    "secret",
		Model:     "claude-test",
		MaxTokens: 512,
		HTTP:      server.Client(),
	}
	response, err := adapter.Generate(context.Background(), model.Request{
		Messages: []model.Message{
			{Role: model.RoleSystem, Content: "be concise"},
			{Role: model.RoleUser, Content: "time?"},
		},
		Tools: []model.ToolSpec{{
			Name:        "get_time",
			Description: "Get time",
			Parameters:  map[string]any{"type": "object"},
		}},
		ToolChoice: model.ToolChoiceAuto,
	})
	if err != nil {
		t.Fatal(err)
	}
	if gotPath != "/v1/messages" || gotKey != "secret" || gotVersion != DefaultVersion {
		t.Fatalf("path=%q key=%q version=%q", gotPath, gotKey, gotVersion)
	}
	if gotRequest.Model != "claude-test" || gotRequest.MaxTokens != 512 {
		t.Fatalf("request = %#v", gotRequest)
	}
	if gotRequest.System != "be concise" || len(gotRequest.Messages) != 1 {
		t.Fatalf("request = %#v", gotRequest)
	}
	if len(gotRequest.Tools) != 1 || gotRequest.Tools[0].Name != "get_time" {
		t.Fatalf("tools = %#v", gotRequest.Tools)
	}
	choice, ok := gotRequest.ToolChoice.(map[string]any)
	if !ok || choice["type"] != "auto" {
		t.Fatalf("tool choice = %#v", gotRequest.ToolChoice)
	}
	if response.Message.Content != "hello" {
		t.Fatalf("content = %q", response.Message.Content)
	}
	if len(response.Message.ToolCalls) != 1 {
		t.Fatalf("tool calls = %#v", response.Message.ToolCalls)
	}
	call := response.Message.ToolCalls[0]
	if call.ID != "toolu_1" || call.Name != "get_time" || call.Arguments["tz"] != "utc" {
		t.Fatalf("call = %#v", call)
	}
	if response.Usage.InputTokens != 10 || response.Usage.OutputTokens != 5 || response.Usage.CachedTokens != 2 {
		t.Fatalf("usage = %#v", response.Usage)
	}
	if response.FinishReason != "tool_use" {
		t.Fatalf("finish reason = %q", response.FinishReason)
	}
}

func TestBuildMessagesGroupsToolResults(t *testing.T) {
	system, messages := buildMessages([]model.Message{
		{Role: model.RoleSystem, Content: "system"},
		{Role: model.RoleUser, Content: "go"},
		{Role: model.RoleAssistant, ToolCalls: []model.ToolCall{{
			ID: "call-1", Name: "lookup", Arguments: map[string]any{"key": "status"},
		}}},
		{Role: model.RoleTool, ToolID: "call-1", Content: "green"},
		{Role: model.RoleTool, ToolID: "call-2", Content: "blue"},
	})
	if system != "system" || len(messages) != 3 {
		t.Fatalf("system=%q messages=%#v", system, messages)
	}
	if messages[1].Role != model.RoleAssistant || len(messages[1].Content) != 1 || messages[1].Content[0].Type != "tool_use" {
		t.Fatalf("assistant = %#v", messages[1])
	}
	if messages[2].Role != "user" || len(messages[2].Content) != 2 {
		t.Fatalf("tool results = %#v", messages[2])
	}
	if messages[2].Content[0].Type != "tool_result" || messages[2].Content[0].ToolUseID != "call-1" {
		t.Fatalf("tool results = %#v", messages[2].Content)
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
		write("data: {\"type\":\"message_start\",\"message\":{\"usage\":{\"input_tokens\":5,\"cache_read_input_tokens\":2}}}\n\n")
		write("data: {\"type\":\"content_block_start\",\"index\":0,\"content_block\":{\"type\":\"text\",\"text\":\"\"}}\n\n")
		write("data: {\"type\":\"content_block_delta\",\"index\":0,\"delta\":{\"type\":\"text_delta\",\"text\":\"hello\"}}\n\n")
		write("data: {\"type\":\"content_block_start\",\"index\":1,\"content_block\":{\"type\":\"tool_use\",\"id\":\"toolu_1\",\"name\":\"get_time\",\"input\":{}}}\n\n")
		write("data: {\"type\":\"content_block_delta\",\"index\":1,\"delta\":{\"type\":\"input_json_delta\",\"partial_json\":\"{\\\"tz\\\":\"}}\n\n")
		write("data: {\"type\":\"content_block_delta\",\"index\":1,\"delta\":{\"type\":\"input_json_delta\",\"partial_json\":\"\\\"utc\\\"}\"}}\n\n")
		write("data: {\"type\":\"message_delta\",\"delta\":{\"stop_reason\":\"tool_use\"},\"usage\":{\"output_tokens\":7}}\n\n")
		write("data: {\"type\":\"message_stop\"}\n\n")
	}))
	defer server.Close()

	adapter := Adapter{
		BaseURL: server.URL,
		APIKey:  "secret",
		Model:   "claude-test",
		HTTP:    server.Client(),
	}
	var deltas []string
	response, err := adapter.GenerateStream(context.Background(), model.Request{
		Messages: []model.Message{{Role: model.RoleUser, Content: "time?"}},
	}, func(delta string) {
		deltas = append(deltas, delta)
	})
	if err != nil {
		t.Fatal(err)
	}
	if !gotRequest.Stream {
		t.Fatal("expected stream=true")
	}
	if strings.Join(deltas, "") != "hello" || response.Message.Content != "hello" {
		t.Fatalf("deltas=%#v content=%q", deltas, response.Message.Content)
	}
	if len(response.Message.ToolCalls) != 1 {
		t.Fatalf("tool calls = %#v", response.Message.ToolCalls)
	}
	call := response.Message.ToolCalls[0]
	if call.ID != "toolu_1" || call.Name != "get_time" || call.Arguments["tz"] != "utc" {
		t.Fatalf("call = %#v", call)
	}
	if response.Usage.InputTokens != 5 || response.Usage.OutputTokens != 7 || response.Usage.CachedTokens != 2 {
		t.Fatalf("usage = %#v", response.Usage)
	}
	if response.FinishReason != "tool_use" {
		t.Fatalf("finish reason = %q", response.FinishReason)
	}
}
