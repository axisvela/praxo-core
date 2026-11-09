package longrunning

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sync"
	"testing"
	"time"
)

type fencedOperation struct {
	ID         string
	Owner      string
	Epoch      int
	Completed  bool
	LeaseUntil time.Time
	Revoked    bool
}

type fencedStore struct {
	mu   sync.Mutex
	ops  map[string]*fencedOperation
	next int
	path string
	now  func() time.Time
}

type persistedFenced struct {
	Operations []fencedOperation
	Next       int
}

func newFencedStore() *fencedStore {
	return newFencedStoreAt("")
}

func newFencedStoreAt(path string) *fencedStore {
	store := &fencedStore{ops: map[string]*fencedOperation{}, path: path, now: time.Now}
	if path == "" {
		return store
	}
	data, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return store
		}
		panic(err)
	}
	var persisted persistedFenced
	if err := json.Unmarshal(data, &persisted); err != nil {
		panic(err)
	}
	store.next = persisted.Next
	for _, item := range persisted.Operations {
		op := item
		store.ops[op.ID] = &op
	}
	return store
}

func (f *fencedStore) save() {
	if f.path == "" {
		return
	}
	state := persistedFenced{Next: f.next}
	for _, op := range f.ops {
		state.Operations = append(state.Operations, *op)
	}
	data, err := json.Marshal(state)
	if err != nil {
		panic(err)
	}
	temporary := f.path + ".tmp"
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
	if err := os.Rename(temporary, f.path); err != nil {
		panic(err)
	}
}

func (f *fencedStore) create(owner string, ttl time.Duration) (string, int) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.next++
	op := &fencedOperation{
		ID:         fmt.Sprintf("fence-%d", f.next),
		Owner:      owner,
		Epoch:      1,
		LeaseUntil: f.now().Add(ttl),
	}
	f.ops[op.ID] = op
	f.save()
	return op.ID, op.Epoch
}

func (f *fencedStore) acquire(id, owner string, ttl time.Duration) (int, bool) {
	f.mu.Lock()
	defer f.mu.Unlock()
	op, ok := f.ops[id]
	if !ok || op.Completed {
		return 0, false
	}
	op.Epoch++
	op.Owner = owner
	op.Revoked = false
	op.LeaseUntil = f.now().Add(ttl)
	f.save()
	return op.Epoch, true
}

func (f *fencedStore) acquireExpired(id, owner string, ttl time.Duration) (int, bool) {
	f.mu.Lock()
	defer f.mu.Unlock()
	op, ok := f.ops[id]
	if !ok || op.Completed {
		return 0, false
	}
	if !op.Revoked && op.LeaseUntil.After(f.now()) {
		return 0, false
	}
	op.Epoch++
	op.Owner = owner
	op.Revoked = false
	op.LeaseUntil = f.now().Add(ttl)
	f.save()
	return op.Epoch, true
}

func (f *fencedStore) renew(id, owner string, epoch int, ttl time.Duration) bool {
	f.mu.Lock()
	defer f.mu.Unlock()
	op, ok := f.ops[id]
	if !ok || op.Completed || op.Revoked || op.Owner != owner || op.Epoch != epoch {
		return false
	}
	if !op.LeaseUntil.After(f.now()) {
		return false
	}
	op.LeaseUntil = f.now().Add(ttl)
	f.save()
	return true
}

func (f *fencedStore) revoke(id string) bool {
	f.mu.Lock()
	defer f.mu.Unlock()
	op, ok := f.ops[id]
	if !ok || op.Completed {
		return false
	}
	op.Revoked = true
	f.save()
	return true
}

func (f *fencedStore) complete(id, owner string, epoch int) bool {
	f.mu.Lock()
	defer f.mu.Unlock()
	op, ok := f.ops[id]
	if !ok || op.Completed || op.Revoked || op.Owner != owner || op.Epoch != epoch {
		return false
	}
	if !op.LeaseUntil.IsZero() && !op.LeaseUntil.After(f.now()) {
		return false
	}
	op.Completed = true
	f.save()
	return true
}

func (f *fencedStore) status(id string) (fencedOperation, bool) {
	f.mu.Lock()
	defer f.mu.Unlock()
	op, ok := f.ops[id]
	if !ok {
		return fencedOperation{}, false
	}
	return *op, true
}

func TestLongRunningFencingRejectsStaleWorker(t *testing.T) {
	store := newFencedStore()
	id, firstEpoch := store.create("worker-a", time.Hour)
	secondEpoch, ok := store.acquire(id, "worker-b", time.Hour)
	if !ok || secondEpoch != firstEpoch+1 {
		t.Fatalf("secondEpoch=%d ok=%v", secondEpoch, ok)
	}
	if store.complete(id, "worker-a", firstEpoch) {
		t.Fatal("stale worker completed the operation")
	}
	if !store.complete(id, "worker-b", secondEpoch) {
		t.Fatal("current worker could not complete the operation")
	}
	if store.complete(id, "worker-b", secondEpoch) {
		t.Fatal("operation was completed twice")
	}
	status, ok := store.status(id)
	if !ok || !status.Completed || status.Owner != "worker-b" || status.Epoch != secondEpoch {
		t.Fatalf("status=%#v ok=%v", status, ok)
	}
}

func TestLongRunningDurableFencingAfterRestart(t *testing.T) {
	path := filepath.Join(t.TempDir(), "fencing.json")
	store := newFencedStoreAt(path)
	id, firstEpoch := store.create("worker-a", time.Hour)
	secondEpoch, ok := store.acquire(id, "worker-b", time.Hour)
	if !ok || secondEpoch != firstEpoch+1 {
		t.Fatalf("secondEpoch=%d ok=%v", secondEpoch, ok)
	}
	restarted := newFencedStoreAt(path)
	status, ok := restarted.status(id)
	if !ok || status.Owner != "worker-b" || status.Epoch != secondEpoch || status.Completed {
		t.Fatalf("status after restart=%#v ok=%v", status, ok)
	}
	if restarted.complete(id, "worker-a", firstEpoch) {
		t.Fatal("stale worker completed after restart")
	}
	if !restarted.complete(id, "worker-b", secondEpoch) {
		t.Fatal("current worker could not complete after restart")
	}
	final := newFencedStoreAt(path)
	status, ok = final.status(id)
	if !ok || !status.Completed || status.Epoch != secondEpoch {
		t.Fatalf("completion was not durable: %#v ok=%v", status, ok)
	}
}

func TestLongRunningExpiredLeaseRejectsCompletion(t *testing.T) {
	now := time.Date(2026, 11, 9, 0, 0, 0, 0, time.UTC)
	store := newFencedStore()
	store.now = func() time.Time { return now }
	id, firstEpoch := store.create("worker-a", 10*time.Second)

	now = now.Add(11 * time.Second)
	if store.complete(id, "worker-a", firstEpoch) {
		t.Fatal("expired lease completed the operation")
	}
	secondEpoch, ok := store.acquireExpired(id, "worker-b", 10*time.Second)
	if !ok || secondEpoch != firstEpoch+1 {
		t.Fatalf("secondEpoch=%d ok=%v", secondEpoch, ok)
	}
	if store.complete(id, "worker-a", firstEpoch) {
		t.Fatal("stale worker completed after lease expiry")
	}
	if !store.complete(id, "worker-b", secondEpoch) {
		t.Fatal("new owner could not complete after lease expiry")
	}
}

func TestLongRunningRenewExtendsLease(t *testing.T) {
	now := time.Date(2026, 11, 9, 0, 0, 0, 0, time.UTC)
	store := newFencedStore()
	store.now = func() time.Time { return now }
	id, epoch := store.create("worker-a", 10*time.Second)

	now = now.Add(5 * time.Second)
	if !store.renew(id, "worker-a", epoch, 10*time.Second) {
		t.Fatal("renewal before expiry failed")
	}
	now = now.Add(6 * time.Second)
	if !store.complete(id, "worker-a", epoch) {
		t.Fatal("renewed lease could not complete")
	}
}

func TestLongRunningRevocationAllowsReacquisition(t *testing.T) {
	store := newFencedStore()
	id, firstEpoch := store.create("worker-a", time.Hour)
	if !store.revoke(id) {
		t.Fatal("revocation failed")
	}
	if store.complete(id, "worker-a", firstEpoch) {
		t.Fatal("revoked lease completed the operation")
	}
	secondEpoch, ok := store.acquireExpired(id, "worker-b", time.Hour)
	if !ok || secondEpoch != firstEpoch+1 {
		t.Fatalf("secondEpoch=%d ok=%v", secondEpoch, ok)
	}
	if !store.complete(id, "worker-b", secondEpoch) {
		t.Fatal("new owner could not complete after revocation")
	}
}

func TestLongRunningLeaseExpirySurvivesRestart(t *testing.T) {
	path := filepath.Join(t.TempDir(), "fencing.json")
	now := time.Date(2026, 11, 9, 0, 0, 0, 0, time.UTC)
	store := newFencedStoreAt(path)
	store.now = func() time.Time { return now }
	id, firstEpoch := store.create("worker-a", 10*time.Second)

	now = now.Add(11 * time.Second)
	restarted := newFencedStoreAt(path)
	restarted.now = func() time.Time { return now }
	if restarted.complete(id, "worker-a", firstEpoch) {
		t.Fatal("expired lease completed after restart")
	}
	secondEpoch, ok := restarted.acquireExpired(id, "worker-b", 10*time.Second)
	if !ok || secondEpoch != firstEpoch+1 {
		t.Fatalf("secondEpoch=%d ok=%v", secondEpoch, ok)
	}
	if !restarted.complete(id, "worker-b", secondEpoch) {
		t.Fatal("new owner could not complete after restart")
	}
}
