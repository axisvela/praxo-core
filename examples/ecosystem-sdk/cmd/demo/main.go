package main

import (
	"context"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/http/httptest"
	"strings"

	sdk "github.com/axisvela/noetivela-open/sdk/go/v3/client"
	noetivelaadapter "github.com/axisvela/praxo-core/examples/ecosystem-sdk/noetivela"
	"github.com/axisvela/praxo-core/v2/pkg/agent"
	"github.com/axisvela/praxo-core/v2/pkg/event"
	"github.com/axisvela/praxo-core/v2/pkg/memory"
	"github.com/axisvela/praxo-core/v2/pkg/model"
	"github.com/axisvela/praxo-core/v2/pkg/policy"
)

func main() {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/v1/chat/completions" {
			http.NotFound(w, r)
			return
		}
		if r.Header.Get("X-Noetivela-Contract") == "" {
			http.Error(w, "missing contract", http.StatusBadRequest)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		_, _ = io.WriteString(w, `{
			"choices": [{"message": {"content": "status is green"}, "finish_reason": "stop"}],
			"usage": {"input_tokens": 5, "output_tokens": 3},
			"noetivela": {"decision_id": "demo", "model_ref": "demo"}
		}`)
	}))
	defer server.Close()

	modelAdapter := noetivelaadapter.Adapter{
		Client: sdk.New(server.URL),
		Policy: "demo-policy",
		ContractFunc: func(model.Request) *sdk.Contract {
			return &sdk.Contract{
				Task:     "status_lookup",
				Modality: []string{"text"},
				Policy: &sdk.Policy{
					DataClassification: "internal",
					AllowedRegions:     []string{"sg"},
				},
			}
		},
	}

	ag, err := agent.New(agent.Options{
		Model:        modelAdapter,
		SystemPrompt: "Report the current status.",
		Memory:       memory.NewMemoryStore(),
		Recall:       true,
		MaxSteps:     2,
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
		ID:          "demo",
		TenantID:    "demo",
		WorkspaceID: "demo",
	}, "report status")
	if err != nil {
		log.Fatal(err)
	}
	if !strings.Contains(result.Output, "green") {
		log.Fatalf("unexpected output: %q", result.Output)
	}
	fmt.Println("output:", result.Output)
}
