package rheovela

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/axisvela/praxo-core/v2/pkg/agent"
	rheovela "github.com/axisvela/rheovela-open/sdk/go/v3/rheovela"
)

func TestRunnerRequiresClient(t *testing.T) {
	ctx := context.Background()
	if _, err := (Runner{}).Start(ctx, agent.Session{}); !errors.Is(err, ErrClientRequired) {
		t.Fatalf("got %v, want %v", err, ErrClientRequired)
	}
	if err := (Runner{}).Step(ctx, "i", "advance", "stage"); !errors.Is(err, ErrClientRequired) {
		t.Fatalf("got %v, want %v", err, ErrClientRequired)
	}
}

func TestRunnerUsesRheovela(t *testing.T) {
	var openRequest rheovela.OpenRunRequest
	var stepRequest rheovela.StepRequest
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/api/v1/instances":
			if err := json.NewDecoder(r.Body).Decode(&openRequest); err != nil {
				http.Error(w, err.Error(), http.StatusBadRequest)
				return
			}
			w.Header().Set("Content-Type", "application/json")
			_, _ = w.Write([]byte(`{
				"instance_id": "instance-1",
				"project_id": "proj",
				"definition_id": "agent",
				"definition_version": 1,
				"status": "active",
				"opened_by": "agent-1"
			}`))
		case "/api/v1/instances/instance-1/steps":
			if err := json.NewDecoder(r.Body).Decode(&stepRequest); err != nil {
				http.Error(w, err.Error(), http.StatusBadRequest)
				return
			}
			w.WriteHeader(http.StatusOK)
		case "/api/v1/audit/instance-1":
			w.Header().Set("Content-Type", "application/json")
			_, _ = w.Write([]byte(`{"ok":true}`))
		default:
			http.NotFound(w, r)
		}
	}))
	defer server.Close()

	runner := Runner{
		Client:    rheovela.NewClient(server.URL, rheovela.WithHTTPClient(server.Client())),
		Workflow:  "agent",
		ProjectID: "proj",
		Actor:     "agent-1",
	}
	instance, err := runner.Start(context.Background(), agent.Session{
		ID:          "session-1",
		TenantID:    "acme",
		WorkspaceID: "default",
	})
	if err != nil {
		t.Fatal(err)
	}
	if instance.InstanceID != "instance-1" {
		t.Fatalf("instance = %#v", instance)
	}
	if openRequest.Workflow != "agent" || openRequest.ProjectID != "proj" || openRequest.Actor != "agent-1" {
		t.Fatalf("open request = %#v", openRequest)
	}
	if openRequest.Variables["session_id"] != "session-1" || openRequest.Variables["tenant_id"] != "acme" {
		t.Fatalf("variables = %#v", openRequest.Variables)
	}
	if openRequest.IdempotencyKey != "session-1" {
		t.Fatalf("idempotency key = %q", openRequest.IdempotencyKey)
	}

	if err := runner.Step(context.Background(), "instance-1", "advance", "review"); err != nil {
		t.Fatal(err)
	}
	if stepRequest.Action != "advance" || stepRequest.Stage != "review" || stepRequest.Actor != "agent-1" {
		t.Fatalf("step request = %#v", stepRequest)
	}

	audit, err := runner.Audit(context.Background(), "instance-1")
	if err != nil {
		t.Fatal(err)
	}
	if string(audit) != `{"ok":true}` {
		t.Fatalf("audit = %s", audit)
	}
}
