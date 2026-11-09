package longrunning

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"os"
	"sync"
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
