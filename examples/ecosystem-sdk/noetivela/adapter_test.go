package noetivela

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	sdk "github.com/axisvela/noetivela-open/sdk/go/v3/client"
	"github.com/axisvela/praxo-core/v2/pkg/model"
)

var _ model.Model = Adapter{}

func TestAdapterRequiresClient(t *testing.T) {
	if _, err := (Adapter{}).Generate(context.Background(), model.Request{}); !errors.Is(err, ErrClientRequired) {
		t.Fatalf("got %v, want %v", err, ErrClientRequired)
	}
}

func TestAdapterUsesSDK(t *testing.T) {
	var gotContract, gotPolicy, gotModel string
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/v1/chat/completions" {
			http.NotFound(w, r)
			return
		}
		gotContract = r.Header.Get("X-Noetivela-Contract")
		gotPolicy = r.Header.Get("X-Noetivela-Policy")
		var body struct {
			Model    string        `json:"model"`
			Messages []sdk.Message `json:"messages"`
		}
		if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
		gotModel = body.Model
		w.Header().Set("Content-Type", "application/json")
		_, _ = io.WriteString(w, `{
			"choices": [{"message": {"content": "status is green"}, "finish_reason": "stop"}],
			"usage": {"input_tokens": 4, "output_tokens": 3, "cached_tokens": 1},
			"noetivela": {"decision_id": "decision-1", "model_ref": "model-1"}
		}`)
	}))
	defer server.Close()

	adapter := Adapter{
		Client: sdk.New(server.URL),
		Policy: "test-policy",
		ContractFunc: func(model.Request) *sdk.Contract {
			return &sdk.Contract{
				Task:     "status_lookup",
				Modality: []string{"text"},
				Policy:   &sdk.Policy{DataClassification: "internal", AllowedRegions: []string{"sg"}},
			}
		},
	}
	response, err := adapter.Generate(context.Background(), model.Request{
		Messages: []model.Message{{Role: model.RoleUser, Content: "check status"}},
	})
	if err != nil {
		t.Fatal(err)
	}
	if response.Message.Content != "status is green" {
		t.Fatalf("content = %q", response.Message.Content)
	}
	if response.Usage.InputTokens != 4 || response.Usage.OutputTokens != 3 || response.Usage.CachedTokens != 1 {
		t.Fatalf("usage = %#v", response.Usage)
	}
	if response.FinishReason != "stop" {
		t.Fatalf("finish reason = %q", response.FinishReason)
	}
	if gotModel != "auto" {
		t.Fatalf("model = %q", gotModel)
	}
	if gotPolicy != "test-policy" {
		t.Fatalf("policy = %q", gotPolicy)
	}
	if !strings.Contains(gotContract, "status_lookup") {
		t.Fatalf("contract header = %q", gotContract)
	}
}
