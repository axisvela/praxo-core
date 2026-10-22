package main

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/axisvela/praxo-core/v2/pkg/model"
)

func TestChatModelGenerate(t *testing.T) {
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
			"usage": {"prompt_tokens": 7, "completion_tokens": 3}
		}`))
	}))
	defer server.Close()

	adapter := chatModel{
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
	if response.Usage.InputTokens != 7 || response.Usage.OutputTokens != 3 {
		t.Fatalf("usage = %#v", response.Usage)
	}
	if response.FinishReason != "tool_calls" {
		t.Fatalf("finish reason = %q", response.FinishReason)
	}
}

func TestChatModelHTTPError(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		http.Error(w, "bad model", http.StatusBadRequest)
	}))
	defer server.Close()

	adapter := chatModel{BaseURL: server.URL, Model: "bad", HTTP: server.Client()}
	_, err := adapter.Generate(context.Background(), model.Request{})
	if err == nil {
		t.Fatal("expected an error")
	}
	if !strings.Contains(err.Error(), "bad model") {
		t.Fatalf("error = %v", err)
	}
}
