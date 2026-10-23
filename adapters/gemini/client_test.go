package gemini

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
	var gotKey, gotPath string
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotKey = r.Header.Get("x-goog-api-key")
		gotPath = r.URL.Path
		if err := json.NewDecoder(r.Body).Decode(&gotRequest); err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{
			"candidates": [{
				"content": {
					"role": "model",
					"parts": [
						{"text": "hello"},
						{"functionCall": {"name": "get_time", "args": {"tz": "utc"}}}
					]
				},
				"finishReason": "STOP"
			}],
			"usageMetadata": {
				"promptTokenCount": 10,
				"candidatesTokenCount": 5,
				"cachedContentTokenCount": 2
			}
		}`))
	}))
	defer server.Close()

	adapter := Adapter{
		BaseURL:   server.URL,
		APIKey:    "secret",
		Model:     "gemini-test",
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
	if gotKey != "secret" || gotPath != "/v1beta/models/gemini-test:generateContent" {
		t.Fatalf("key=%q path=%q", gotKey, gotPath)
	}
	if gotRequest.SystemInstruction == nil || len(gotRequest.SystemInstruction.Parts) != 1 {
		t.Fatalf("system = %#v", gotRequest.SystemInstruction)
	}
	if gotRequest.SystemInstruction.Parts[0].Text != "be concise" || len(gotRequest.Contents) != 1 {
		t.Fatalf("request = %#v", gotRequest)
	}
	if len(gotRequest.Tools) != 1 || gotRequest.Tools[0].FunctionDeclarations[0].Name != "get_time" {
		t.Fatalf("tools = %#v", gotRequest.Tools)
	}
	if gotRequest.ToolConfig == nil || gotRequest.ToolConfig.FunctionCallingConfig.Mode != "AUTO" {
		t.Fatalf("tool config = %#v", gotRequest.ToolConfig)
	}
	if gotRequest.GenerationConfig == nil || gotRequest.GenerationConfig.MaxOutputTokens != 512 {
		t.Fatalf("generation config = %#v", gotRequest.GenerationConfig)
	}
	if response.Message.Content != "hello" {
		t.Fatalf("content = %q", response.Message.Content)
	}
	if len(response.Message.ToolCalls) != 1 {
		t.Fatalf("tool calls = %#v", response.Message.ToolCalls)
	}
	call := response.Message.ToolCalls[0]
	if call.Name != "get_time" || call.Arguments["tz"] != "utc" {
		t.Fatalf("call = %#v", call)
	}
	if response.Usage.InputTokens != 10 || response.Usage.OutputTokens != 5 || response.Usage.CachedTokens != 2 {
		t.Fatalf("usage = %#v", response.Usage)
	}
	if response.FinishReason != "STOP" {
		t.Fatalf("finish reason = %q", response.FinishReason)
	}
}

func TestBuildContentsMapsToolResults(t *testing.T) {
	system, contents := buildContents([]model.Message{
		{Role: model.RoleSystem, Content: "system"},
		{Role: model.RoleUser, Content: "go"},
		{Role: model.RoleAssistant, ToolCalls: []model.ToolCall{{
			ID: "call-1", Name: "lookup", Arguments: map[string]any{"key": "status"},
		}}},
		{Role: model.RoleTool, ToolID: "call-1", Content: "green"},
	})
	if system == nil || len(system.Parts) != 1 || system.Parts[0].Text != "system" {
		t.Fatalf("system = %#v", system)
	}
	if len(contents) != 3 {
		t.Fatalf("contents = %#v", contents)
	}
	if contents[1].Role != "model" || contents[1].Parts[0].FunctionCall == nil {
		t.Fatalf("assistant = %#v", contents[1])
	}
	last := contents[2]
	if last.Role != "user" || last.Parts[0].FunctionResponse == nil {
		t.Fatalf("tool result = %#v", last)
	}
	if last.Parts[0].FunctionResponse.Name != "lookup" || last.Parts[0].FunctionResponse.Response["result"] != "green" {
		t.Fatalf("function response = %#v", last.Parts[0].FunctionResponse)
	}
}

func TestAdapterGenerateStream(t *testing.T) {
	var gotPath string
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotPath = r.URL.Path
		w.Header().Set("Content-Type", "text/event-stream")
		flusher, _ := w.(http.Flusher)
		write := func(value string) {
			_, _ = fmt.Fprint(w, value)
			if flusher != nil {
				flusher.Flush()
			}
		}
		write("data: {\"candidates\":[{\"content\":{\"role\":\"model\",\"parts\":[{\"text\":\"hel\"}]}}]}\n\n")
		write("data: {\"candidates\":[{\"content\":{\"role\":\"model\",\"parts\":[{\"text\":\"lo\"}]}}]}\n\n")
		write("data: {\"candidates\":[{\"content\":{\"role\":\"model\",\"parts\":[{\"functionCall\":{\"name\":\"get_time\",\"args\":{\"tz\":\"utc\"}}}]},\"finishReason\":\"STOP\"}],\"usageMetadata\":{\"promptTokenCount\":5,\"candidatesTokenCount\":3,\"cachedContentTokenCount\":1}}\n\n")
	}))
	defer server.Close()

	adapter := Adapter{
		BaseURL: server.URL,
		APIKey:  "secret",
		Model:   "gemini-test",
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
	if gotPath != "/v1beta/models/gemini-test:streamGenerateContent" {
		t.Fatalf("path = %q", gotPath)
	}
	if strings.Join(deltas, "") != "hello" || response.Message.Content != "hello" {
		t.Fatalf("deltas=%#v content=%q", deltas, response.Message.Content)
	}
	if len(response.Message.ToolCalls) != 1 {
		t.Fatalf("tool calls = %#v", response.Message.ToolCalls)
	}
	call := response.Message.ToolCalls[0]
	if call.Name != "get_time" || call.Arguments["tz"] != "utc" {
		t.Fatalf("call = %#v", call)
	}
	if response.Usage.InputTokens != 5 || response.Usage.OutputTokens != 3 || response.Usage.CachedTokens != 1 {
		t.Fatalf("usage = %#v", response.Usage)
	}
	if response.FinishReason != "STOP" {
		t.Fatalf("finish reason = %q", response.FinishReason)
	}
}
