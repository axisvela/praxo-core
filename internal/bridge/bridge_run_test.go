package bridge

import (
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/axisvela/praxo-core/v2/pkg/agent"
	"github.com/axisvela/praxo-core/v2/pkg/event"
)

func openAIServer(t *testing.T) *httptest.Server {
	t.Helper()
	return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_ = json.NewEncoder(w).Encode(map[string]any{
			"choices": []any{
				map[string]any{
					"message": map[string]any{
						"role":    "assistant",
						"content": "hello",
					},
					"finish_reason": "stop",
				},
			},
			"usage": map[string]any{
				"prompt_tokens":     1,
				"completion_tokens": 2,
			},
		})
	}))
}

func TestToolList(t *testing.T) {
	result, err := Run([]string{"tool", "list"}, []byte(`{}`))
	if err != nil {
		t.Fatal(err)
	}
	tools := result.(map[string]any)["tools"].([]any)
	if len(tools) != 0 {
		t.Fatalf("tools: %#v", tools)
	}
}

func TestRun(t *testing.T) {
	server := openAIServer(t)
	defer server.Close()
	t.Setenv("PRAXO_BASE_URL", server.URL)
	t.Setenv("PRAXO_MODEL", "test")
	result, err := Run(
		[]string{"run"},
		[]byte(`{"prompt":"hi","sessionId":"s1"}`),
	)
	if err != nil {
		t.Fatal(err)
	}
	run := result.(*agent.Result)
	if run.Output != "hello" || run.Steps != 1 {
		t.Fatalf("result: %#v", run)
	}
}

func TestRunRequiresBaseURL(t *testing.T) {
	t.Setenv("PRAXO_BASE_URL", "")
	_, err := Run([]string{"run"}, []byte(`{"prompt":"hi"}`))
	var contract *ContractError
	if !errors.As(err, &contract) || contract.Code != "BRIDGE_CONFIG" {
		t.Fatalf("got %v", err)
	}
}

func TestEventStream(t *testing.T) {
	server := openAIServer(t)
	defer server.Close()
	t.Setenv("PRAXO_BASE_URL", server.URL)
	t.Setenv("PRAXO_MODEL", "test")
	var emitted []any
	result, err := RunWithEmitter(
		[]string{"event", "stream"},
		[]byte(`{"prompt":"hi","sessionId":"s1"}`),
		func(value any) { emitted = append(emitted, value) },
	)
	if err != nil {
		t.Fatal(err)
	}
	if result != nil {
		t.Fatalf("result: %#v", result)
	}
	types := make([]string, 0)
	for _, value := range emitted {
		if item, ok := value.(event.Event); ok {
			types = append(types, item.Type)
		}
	}
	if len(types) < 2 || types[0] != "run.started" || types[len(types)-1] != "run.completed" {
		t.Fatalf("events: %#v", types)
	}
	last := emitted[len(emitted)-1].(map[string]any)
	if last["type"] != "result" {
		t.Fatalf("last: %#v", last)
	}
}
