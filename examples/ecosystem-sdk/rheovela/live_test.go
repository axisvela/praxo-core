package rheovela

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"testing"
	"time"

	rheovela "github.com/axisvela/rheovela-open/sdk/go/v3/rheovela"
	"github.com/axisvela/rheovela-open/sdk/go/v3/worker"
)

func TestLiveDurableWorker(t *testing.T) {
	baseURL := os.Getenv("RHEO_URL")
	if baseURL == "" {
		t.Skip("RHEO_URL is not set")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()
	client := rheovela.NewClient(baseURL)
	if err := client.Health(ctx); err != nil {
		t.Fatal(err)
	}
	workflowID := fmt.Sprintf("praxo-live-%d", time.Now().UnixNano())
	if err := publishWorkflow(ctx, baseURL, workflowID); err != nil {
		t.Fatal(err)
	}

	run, err := client.OpenRun(ctx, rheovela.OpenRunRequest{
		Workflow:       workflowID,
		Actor:          "praxo-live",
		IdempotencyKey: workflowID,
	})
	if err != nil {
		t.Fatal(err)
	}
	item := awaitWorkItem(t, ctx, client, run.InstanceID, "ready")
	success := stepRunner(func(context.Context, worker.WorkItem) (StepResult, error) {
		return StepResult{
			Result:        map[string]any{"ok": true},
			CheckpointRef: "live-ckpt",
			EffectCursor:  "live-eff",
		}, nil
	})
	instance, err := NewDurableWorker(client, success)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := instance.RunOnce(ctx); err != nil {
		t.Fatal(err)
	}
	done := awaitWorkItem(t, ctx, client, run.InstanceID, "done")
	if !bytes.Contains(done.Result, []byte(`"ok":true`)) {
		t.Fatalf("result = %s", done.Result)
	}
	if done.CheckpointRef != "live-ckpt" || done.EffectCursor != "live-eff" {
		t.Fatalf("refs = %#v", done)
	}
	if item.ID != done.ID {
		t.Fatalf("item = %s, done = %s", item.ID, done.ID)
	}

	approvalRun, err := client.OpenRun(ctx, rheovela.OpenRunRequest{
		Workflow:       workflowID,
		Actor:          "praxo-live",
		IdempotencyKey: workflowID + "-approval",
	})
	if err != nil {
		t.Fatal(err)
	}
	awaitWorkItem(t, ctx, client, approvalRun.InstanceID, "ready")
	approval := stepRunner(func(context.Context, worker.WorkItem) (StepResult, error) {
		return StepResult{
			CheckpointRef: "live-approval-ckpt",
			Approval: &worker.ApprovalRequest{
				Reason:    "live approval",
				FinalArgs: json.RawMessage(`{"approved":true}`),
			},
		}, nil
	})
	instance, err = NewDurableWorker(client, approval)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := instance.RunOnce(ctx); err != nil {
		t.Fatal(err)
	}
	pending := awaitWorkItem(t, ctx, client, approvalRun.InstanceID, "awaiting_approval")
	if pending.Approval == nil || pending.Approval.Reason != "live approval" {
		t.Fatalf("approval = %#v", pending.Approval)
	}
	if err := client.ApproveWorkItem(ctx, pending.ID, "reviewer", "ok", nil); err != nil {
		t.Fatal(err)
	}
	awaitWorkItem(t, ctx, client, approvalRun.InstanceID, "ready")
	instance, err = NewDurableWorker(client, success)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := instance.RunOnce(ctx); err != nil {
		t.Fatal(err)
	}
	awaitWorkItem(t, ctx, client, approvalRun.InstanceID, "done")
}

func publishWorkflow(ctx context.Context, baseURL, workflowID string) error {
	body, err := json.Marshal(map[string]any{
		"schema_version": "1",
		"workflow_id":    workflowID,
		"title":          "PRAXO live worker",
		"kind":           "business",
		"source":         "praxo-live",
		"stages":         []map[string]any{{"id": "work", "title": "Work"}},
		"transitions":    []any{},
	})
	if err != nil {
		return err
	}
	request, err := http.NewRequestWithContext(ctx, http.MethodPost, baseURL+"/api/v1/workflows", bytes.NewReader(body))
	if err != nil {
		return err
	}
	request.Header.Set("Content-Type", "application/json")
	response, err := http.DefaultClient.Do(request)
	if err != nil {
		return err
	}
	defer response.Body.Close()
	payload, _ := io.ReadAll(io.LimitReader(response.Body, 1<<20))
	if response.StatusCode < 200 || response.StatusCode >= 300 {
		return fmt.Errorf("publish workflow: %s: %s", response.Status, string(payload))
	}
	return nil
}

func awaitWorkItem(t *testing.T, ctx context.Context, client *rheovela.Client, instanceID, state string) rheovela.WorkItem {
	t.Helper()
	deadline := time.Now().Add(10 * time.Second)
	for time.Now().Before(deadline) {
		items, err := client.ListWorkItems(ctx, instanceID)
		if err != nil {
			t.Fatal(err)
		}
		for _, item := range items {
			if item.State == state {
				return item
			}
		}
		time.Sleep(100 * time.Millisecond)
	}
	t.Fatalf("work item for %s did not reach %s", instanceID, state)
	return rheovela.WorkItem{}
}
