package aegivela

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/axisvela/aegivela-open/sdk/go/v3/pepsdk"
	"github.com/axisvela/praxo-core/v2/pkg/policy"
)

var _ policy.Hook = Hook{}

func TestHookRequiresClient(t *testing.T) {
	if _, err := (Hook{}).Authorize(context.Background(), policy.Action{}); !errors.Is(err, ErrClientRequired) {
		t.Fatalf("got %v, want %v", err, ErrClientRequired)
	}
}

func TestHookEvaluatesPolicy(t *testing.T) {
	var request map[string]any
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/v1/policy/decisions/evaluate" {
			http.NotFound(w, r)
			return
		}
		if err := json.NewDecoder(r.Body).Decode(&request); err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{
			"api_version": "aegivela.io/v1alpha1",
			"decision_id": "decision-1",
			"outcome": "allow",
			"policy_version": "v1",
			"evidence_refs": ["evidence-1"]
		}`))
	}))
	defer server.Close()

	hook := Hook{
		Client: pepsdk.NewClient(server.URL, server.Client()),
		Route: pepsdk.Route{
			Audience:  "agent",
			Action:    "tool:invoke",
			Scope:     []string{"tool:invoke"},
			Kind:      "tool",
			Reference: "lookup",
		},
		Input: pepsdk.AuthorizationInput{
			Mode:              pepsdk.ModeSystemAPI,
			WorkloadAssertion: "assertion",
		},
	}
	decision, err := hook.Authorize(context.Background(), policy.Action{
		Kind:     "tool",
		ToolName: "lookup",
	})
	if err != nil {
		t.Fatal(err)
	}
	if !decision.Allowed || decision.Reason != "allow" {
		t.Fatalf("decision = %#v", decision)
	}
	if request["action"] != "tool:invoke" {
		t.Fatalf("request = %#v", request)
	}
	resource, ok := request["resource"].(map[string]any)
	if !ok || resource["reference"] != "lookup" {
		t.Fatalf("request = %#v", request)
	}
}

func TestHookDenies(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{
			"api_version": "aegivela.io/v1alpha1",
			"decision_id": "decision-1",
			"outcome": "deny",
			"policy_version": "v1",
			"evidence_refs": ["evidence-1"]
		}`))
	}))
	defer server.Close()

	hook := Hook{
		Client: pepsdk.NewClient(server.URL, server.Client()),
		Route: pepsdk.Route{
			Audience:  "agent",
			Action:    "tool:invoke",
			Scope:     []string{"tool:invoke"},
			Kind:      "tool",
			Reference: "lookup",
		},
		Input: pepsdk.AuthorizationInput{
			Mode:              pepsdk.ModeSystemAPI,
			WorkloadAssertion: "assertion",
		},
	}
	decision, err := hook.Authorize(context.Background(), policy.Action{ToolName: "lookup"})
	if err != nil {
		t.Fatal(err)
	}
	if decision.Allowed || decision.Reason != "deny" {
		t.Fatalf("decision = %#v", decision)
	}
}
