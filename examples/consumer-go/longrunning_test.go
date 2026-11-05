package main

import (
	"context"
	"sync"
	"testing"
	"time"

	"github.com/axisvela/praxo-core/v2/pkg/agent"
	"github.com/axisvela/praxo-core/v2/pkg/model"
	"github.com/axisvela/praxo-core/v2/pkg/tool"
)

type remoteState string

const (
	remoteAccepted        remoteState = "accepted"
	remoteCancelRequested remoteState = "cancel_requested"
	remoteCanceled        remoteState = "canceled"
)

type remoteOperation struct {
	ID    string
	Key   string
	State remoteState
}

type remoteOperations struct {
	mu      sync.Mutex
	byKey   map[string]*remoteOperation
	byID    map[string]*remoteOperation
	effects int
	next    int
}

func newRemoteOperations() *remoteOperations {
	return &remoteOperations{
		byKey: map[string]*remoteOperation{},
		byID:  map[string]*remoteOperation{},
	}
}

func (r *remoteOperations) submit(key string) (remoteOperation, bool) {
	r.mu.Lock()
	defer r.mu.Unlock()
	if existing, ok := r.byKey[key]; ok {
		return *existing, false
	}
	r.next++
	op := &remoteOperation{ID: "op-" + key, Key: key, State: remoteAccepted}
	r.byKey[key] = op
	r.byID[op.ID] = op
	r.effects++
	return *op, true
}

func (r *remoteOperations) status(id string) (remoteOperation, bool) {
	r.mu.Lock()
	defer r.mu.Unlock()
	op, ok := r.byID[id]
	if !ok {
		return remoteOperation{}, false
	}
	return *op, true
}

func (r *remoteOperations) requestCancel(id string) (remoteOperation, bool) {
	r.mu.Lock()
	defer r.mu.Unlock()
	op, ok := r.byID[id]
	if !ok || op.State != remoteAccepted {
		return remoteOperation{}, false
	}
	op.State = remoteCancelRequested
	return *op, true
}

func (r *remoteOperations) confirmCancel(id string) (remoteOperation, bool) {
	r.mu.Lock()
	defer r.mu.Unlock()
	op, ok := r.byID[id]
	if !ok || op.State != remoteCancelRequested {
		return remoteOperation{}, false
	}
	op.State = remoteCanceled
	return *op, true
}

func (r *remoteOperations) effectCount() int {
	r.mu.Lock()
	defer r.mu.Unlock()
	return r.effects
}

type blockingSubmitTool struct {
	service  *remoteOperations
	key      string
	accepted chan string
}

func (*blockingSubmitTool) Name() string        { return "submit_op" }
func (*blockingSubmitTool) Description() string { return "Submit a long-running operation." }

func (t *blockingSubmitTool) Invoke(ctx context.Context, _ map[string]any) (any, error) {
	op, _ := t.service.submit(t.key)
	t.accepted <- op.ID
	<-ctx.Done()
	return nil, ctx.Err()
}

type submitModel struct{ key string }

func (m submitModel) Generate(_ context.Context, req model.Request) (model.Response, error) {
	last := req.Messages[len(req.Messages)-1]
	if last.Role == model.RoleTool {
		return model.Response{Message: model.Message{Role: model.RoleAssistant, Content: "submitted"}}, nil
	}
	return model.Response{Message: model.Message{
		Role: model.RoleAssistant,
		ToolCalls: []model.ToolCall{{
			ID: "submit-1", Name: "submit_op", Arguments: map[string]any{"key": m.key},
		}},
	}}, nil
}

func TestLongRunningSubmitIsIdempotent(t *testing.T) {
	service := newRemoteOperations()
	first, created := service.submit("key-1")
	if !created {
		t.Fatal("first submit was not created")
	}
	second, created := service.submit("key-1")
	if created || first.ID != second.ID {
		t.Fatalf("first=%s second=%s created=%v", first.ID, second.ID, created)
	}
	if service.effectCount() != 1 {
		t.Fatalf("effects=%d", service.effectCount())
	}
}

func TestLongRunningRecoveryUsesAuthority(t *testing.T) {
	service := newRemoteOperations()
	lost, _ := service.submit("key-1")
	recovered, created := service.submit("key-1")
	if created || recovered.ID != lost.ID {
		t.Fatalf("lost=%s recovered=%s created=%v", lost.ID, recovered.ID, created)
	}
	status, ok := service.status(lost.ID)
	if !ok || status.ID != lost.ID || status.State != remoteAccepted {
		t.Fatalf("status=%#v ok=%v", status, ok)
	}
	if service.effectCount() != 1 {
		t.Fatalf("effects=%d", service.effectCount())
	}
}

func TestLongRunningCancelRequestIsNotConfirmation(t *testing.T) {
	service := newRemoteOperations()
	op, _ := service.submit("key-1")
	requested, ok := service.requestCancel(op.ID)
	if !ok || requested.State != remoteCancelRequested {
		t.Fatalf("requested=%#v ok=%v", requested, ok)
	}
	if requested.State == remoteCanceled {
		t.Fatal("cancel request was reported as confirmed")
	}
	confirmed, ok := service.confirmCancel(op.ID)
	if !ok || confirmed.State != remoteCanceled {
		t.Fatalf("confirmed=%#v ok=%v", confirmed, ok)
	}
	if _, ok := service.confirmCancel(op.ID); ok {
		t.Fatal("already canceled operation was confirmed twice")
	}
}

func TestLongRunningRunCancellationLeavesRemoteState(t *testing.T) {
	service := newRemoteOperations()
	toolImpl := &blockingSubmitTool{
		service: service, key: "key-1", accepted: make(chan string, 1),
	}
	tools := tool.NewRegistry()
	tools.Register(toolImpl)
	ag, err := agent.New(agent.Options{
		Model: submitModel{key: "key-1"}, Tools: tools, MaxSteps: 2,
		AllowedTools: []string{"submit_op"},
	})
	if err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan error, 1)
	go func() {
		_, err := ag.Run(ctx, agent.Session{ID: "long-running"}, "submit")
		done <- err
	}()
	var operationID string
	select {
	case operationID = <-toolImpl.accepted:
	case <-time.After(5 * time.Second):
		t.Fatal("tool did not submit the operation")
	}
	cancel()
	if err := <-done; err == nil {
		t.Fatal("run cancellation was not reported")
	}
	status, ok := service.status(operationID)
	if !ok || status.State != remoteAccepted {
		t.Fatalf("remote state=%#v ok=%v", status, ok)
	}
	if status.State == remoteCanceled {
		t.Fatal("run cancellation was reported as remote cancellation")
	}
	if service.effectCount() != 1 {
		t.Fatalf("effects=%d", service.effectCount())
	}
}
