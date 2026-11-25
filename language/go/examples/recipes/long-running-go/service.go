package longrunning

import (
	"context"
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
	lease      Lease
	owner      string
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
	return newRemoteOperationsWithLease(path, verifier, nil, "")
}

func newRemoteOperationsWithLease(path string, verifier effectAuthority, lease Lease, owner string) *remoteOperations {
	r := &remoteOperations{
		path:     path,
		verifier: verifier,
		lease:    lease,
		owner:    owner,
	}
	r.reload()
	return r
}

func (r *remoteOperations) reload() {
	r.byKey = map[string]*remoteOperation{}
	r.byID = map[string]*remoteOperation{}
	r.effects = 0
	r.next = 0
	if r.path == "" {
		return
	}
	data, err := os.ReadFile(r.path)
	if err != nil {
		if os.IsNotExist(err) {
			return
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
}

func (r *remoteOperations) mutate(fn func()) {
	r.mu.Lock()
	defer r.mu.Unlock()
	if r.lease != nil {
		release, err := r.lease.Acquire(context.Background(), r.owner)
		if err != nil {
			panic(err)
		}
		defer release()
		r.reload()
	}
	fn()
	r.save()
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
	var op remoteOperation
	created := false
	r.mutate(func() {
		if existing, ok := r.byKey[key]; ok {
			op = *existing
			return
		}
		r.next++
		entry := &remoteOperation{ID: "op-" + key, Key: key, State: remoteAccepted}
		r.byKey[key] = entry
		r.byID[entry.ID] = entry
		r.effects++
		op = *entry
		created = true
	})
	return op, created
}

func (r *remoteOperations) status(id string) (remoteOperation, bool) {
	r.mu.Lock()
	defer r.mu.Unlock()
	if r.path != "" {
		r.reload()
	}
	op, ok := r.byID[id]
	if !ok {
		return remoteOperation{}, false
	}
	return *op, true
}

func (r *remoteOperations) requestCancel(id string) (remoteOperation, bool) {
	var op remoteOperation
	ok := false
	r.mutate(func() {
		entry, found := r.byID[id]
		if !found || entry.State != remoteAccepted {
			return
		}
		entry.State = remoteCancelRequested
		op = *entry
		ok = true
	})
	return op, ok
}

func (r *remoteOperations) confirmCancel(id string) (remoteOperation, bool) {
	var op remoteOperation
	ok := false
	r.mutate(func() {
		entry, found := r.byID[id]
		if !found || entry.State != remoteCancelRequested {
			return
		}
		entry.State = remoteCanceled
		op = *entry
		ok = true
	})
	return op, ok
}

func (r *remoteOperations) complete(id string) (remoteOperation, bool) {
	var op remoteOperation
	ok := false
	r.mutate(func() {
		entry, found := r.byID[id]
		if !found || entry.State != remoteAccepted {
			return
		}
		entry.State = remoteCompleted
		op = *entry
		ok = true
	})
	return op, ok
}

func (r *remoteOperations) verifyEffect(id, evidence, receipt string) (remoteOperation, bool) {
	var op remoteOperation
	ok := false
	r.mutate(func() {
		entry, found := r.byID[id]
		if !found || entry.State != remoteCompleted || evidence == "" || !r.verifier.valid(id, evidence, receipt) {
			return
		}
		entry.State = remoteEffectVerified
		entry.Evidence = evidence
		op = *entry
		ok = true
	})
	return op, ok
}

func (r *remoteOperations) effectCount() int {
	r.mu.Lock()
	defer r.mu.Unlock()
	if r.path != "" {
		r.reload()
	}
	return r.effects
}
