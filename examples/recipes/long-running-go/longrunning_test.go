package longrunning

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"os"
	"path/filepath"
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
	remoteCompleted       remoteState = "completed"
	remoteEffectVerified  remoteState = "effect_verified"
)

type remoteOperation struct {
	ID       string
	Key      string
	State    remoteState
	Evidence string
}

type effectAuthority interface {
	valid(operationID, evidence, receipt string) bool
}

type effectVerifier struct {
	secret []byte
}

func newEffectVerifier(secret string) *effectVerifier {
	return &effectVerifier{secret: []byte(secret)}
}

func (v *effectVerifier) sign(operationID, evidence string) string {
	mac := hmac.New(sha256.New, v.secret)
	mac.Write([]byte(operationID + "\n" + evidence))
	return hex.EncodeToString(mac.Sum(nil))
}

func (v *effectVerifier) valid(operationID, evidence, receipt string) bool {
	expected := v.sign(operationID, evidence)
	return hmac.Equal([]byte(expected), []byte(receipt))
}

type remoteOperations struct {
	mu         sync.Mutex
	byKey      map[string]*remoteOperation
	byID       map[string]*remoteOperation
	effects    int
	next       int
	path       string
	verifier   effectAuthority
	commitHook func(stage string) error
}

type persistedOperations struct {
	Operations []remoteOperation
	Effects    int
	Next       int
}

func newRemoteOperations() *remoteOperations {
	return newRemoteOperationsAt("")
}

func newRemoteOperationsAt(path string) *remoteOperations {
	return newRemoteOperationsWithVerifier(path, newEffectVerifier("fixture-effect-secret"))
}

func newRemoteOperationsWithVerifier(path string, verifier effectAuthority) *remoteOperations {
	r := &remoteOperations{
		byKey:    map[string]*remoteOperation{},
		byID:     map[string]*remoteOperation{},
		path:     path,
		verifier: verifier,
	}
	if path == "" {
		return r
	}
	data, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return r
		}
		panic(err)
	}
	var persisted persistedOperations
	if err := json.Unmarshal(data, &persisted); err != nil {
		panic(err)
	}
	r.effects = persisted.Effects
	r.next = persisted.Next
	for _, item := range persisted.Operations {
		op := item
		r.byKey[op.Key] = &op
		r.byID[op.ID] = &op
	}
	return r
}

func (r *remoteOperations) save() {
	if r.path == "" {
		return
	}
	state := persistedOperations{Effects: r.effects, Next: r.next}
	for _, op := range r.byID {
		state.Operations = append(state.Operations, *op)
	}
	data, err := json.Marshal(state)
	if err != nil {
		panic(err)
	}
	temporary := r.path + ".tmp"
	file, err := os.OpenFile(temporary, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0o600)
	if err != nil {
		panic(err)
	}
	if _, err := file.Write(data); err != nil {
		_ = file.Close()
		panic(err)
	}
	if err := file.Sync(); err != nil {
		_ = file.Close()
		panic(err)
	}
	if err := file.Close(); err != nil {
		panic(err)
	}
	if r.commitHook != nil {
		if err := r.commitHook("before-rename"); err != nil {
			panic(err)
		}
	}
	if err := os.Rename(temporary, r.path); err != nil {
		panic(err)
	}
	if r.commitHook != nil {
		if err := r.commitHook("after-rename"); err != nil {
			panic(err)
		}
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
	r.save()
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
	r.save()
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
	r.save()
	return *op, true
}

func (r *remoteOperations) complete(id string) (remoteOperation, bool) {
	r.mu.Lock()
	defer r.mu.Unlock()
	op, ok := r.byID[id]
	if !ok || op.State != remoteAccepted {
		return remoteOperation{}, false
	}
	op.State = remoteCompleted
	r.save()
	return *op, true
}

func (r *remoteOperations) verifyEffect(id, evidence, receipt string) (remoteOperation, bool) {
	r.mu.Lock()
	defer r.mu.Unlock()
	op, ok := r.byID[id]
	if !ok || op.State != remoteCompleted || evidence == "" || !r.verifier.valid(id, evidence, receipt) {
		return remoteOperation{}, false
	}
	op.State = remoteEffectVerified
	op.Evidence = evidence
	r.save()
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

func TestLongRunningSurvivesRestart(t *testing.T) {
	path := filepath.Join(t.TempDir(), "operations.json")
	service := newRemoteOperationsAt(path)
	op, created := service.submit("key-1")
	if !created {
		t.Fatal("first submit was not created")
	}
	restarted := newRemoteOperationsAt(path)
	status, ok := restarted.status(op.ID)
	if !ok || status.State != remoteAccepted {
		t.Fatalf("status after restart=%#v ok=%v", status, ok)
	}
	recovered, created := restarted.submit("key-1")
	if created || recovered.ID != op.ID || restarted.effectCount() != 1 {
		t.Fatalf("recovered=%#v created=%v effects=%d", recovered, created, restarted.effectCount())
	}
	requested, ok := restarted.requestCancel(op.ID)
	if !ok || requested.State != remoteCancelRequested {
		t.Fatalf("requested=%#v ok=%v", requested, ok)
	}
	restartedAgain := newRemoteOperationsAt(path)
	status, ok = restartedAgain.status(op.ID)
	if !ok || status.State != remoteCancelRequested {
		t.Fatalf("cancel request was not durable: %#v ok=%v", status, ok)
	}
	confirmed, ok := restartedAgain.confirmCancel(op.ID)
	if !ok || confirmed.State != remoteCanceled {
		t.Fatalf("confirmed=%#v ok=%v", confirmed, ok)
	}
	final := newRemoteOperationsAt(path)
	status, ok = final.status(op.ID)
	if !ok || status.State != remoteCanceled {
		t.Fatalf("cancel confirmation was not durable: %#v ok=%v", status, ok)
	}
}

func TestLongRunningPartialWriteDoesNotCorruptState(t *testing.T) {
	path := filepath.Join(t.TempDir(), "operations.json")
	service := newRemoteOperationsAt(path)
	op, _ := service.submit("key-1")
	if _, err := os.Stat(path + ".tmp"); !os.IsNotExist(err) {
		t.Fatalf("temporary file was left behind: %v", err)
	}
	if err := os.WriteFile(path+".tmp", []byte("{partial"), 0o600); err != nil {
		t.Fatal(err)
	}
	restarted := newRemoteOperationsAt(path)
	status, ok := restarted.status(op.ID)
	if !ok || status.State != remoteAccepted {
		t.Fatalf("committed state was corrupted: %#v ok=%v", status, ok)
	}
	recovered, created := restarted.submit("key-1")
	if created || recovered.ID != op.ID || restarted.effectCount() != 1 {
		t.Fatalf("recovered=%#v created=%v effects=%d", recovered, created, restarted.effectCount())
	}
}

func TestLongRunningCompletionIsNotEffectVerification(t *testing.T) {
	path := filepath.Join(t.TempDir(), "operations.json")
	verifier := newEffectVerifier("test-secret")
	service := newRemoteOperationsWithVerifier(path, verifier)
	op, _ := service.submit("key-1")
	completed, ok := service.complete(op.ID)
	if !ok || completed.State != remoteCompleted || completed.Evidence != "" {
		t.Fatalf("completed=%#v ok=%v", completed, ok)
	}
	if _, ok := service.verifyEffect(op.ID, "", ""); ok {
		t.Fatal("effect verification without evidence was accepted")
	}
	restarted := newRemoteOperationsWithVerifier(path, verifier)
	status, ok := restarted.status(op.ID)
	if !ok || status.State != remoteCompleted {
		t.Fatalf("completion was not durable: %#v ok=%v", status, ok)
	}
	evidence := "room=kitchen;sensor=door"
	if _, ok := restarted.verifyEffect(op.ID, evidence, "forged"); ok {
		t.Fatal("forged effect receipt was accepted")
	}
	verified, ok := restarted.verifyEffect(op.ID, evidence, verifier.sign(op.ID, evidence))
	if !ok || verified.State != remoteEffectVerified || verified.Evidence == "" {
		t.Fatalf("verified=%#v ok=%v", verified, ok)
	}
	final := newRemoteOperationsAt(path)
	status, ok = final.status(op.ID)
	if !ok || status.State != remoteEffectVerified || status.Evidence == "" {
		t.Fatalf("effect evidence was not durable: %#v ok=%v", status, ok)
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
