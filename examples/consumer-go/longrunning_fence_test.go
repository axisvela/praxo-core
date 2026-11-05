package main

import (
	"fmt"
	"sync"
	"testing"
)

type fencedOperation struct {
	ID        string
	Owner     string
	Epoch     int
	Completed bool
}

type fencedStore struct {
	mu   sync.Mutex
	ops  map[string]*fencedOperation
	next int
}

func newFencedStore() *fencedStore {
	return &fencedStore{ops: map[string]*fencedOperation{}}
}

func (f *fencedStore) create(owner string) (string, int) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.next++
	op := &fencedOperation{ID: fmt.Sprintf("fence-%d", f.next), Owner: owner, Epoch: 1}
	f.ops[op.ID] = op
	return op.ID, op.Epoch
}

func (f *fencedStore) acquire(id, owner string) (int, bool) {
	f.mu.Lock()
	defer f.mu.Unlock()
	op, ok := f.ops[id]
	if !ok || op.Completed {
		return 0, false
	}
	op.Epoch++
	op.Owner = owner
	return op.Epoch, true
}

func (f *fencedStore) complete(id, owner string, epoch int) bool {
	f.mu.Lock()
	defer f.mu.Unlock()
	op, ok := f.ops[id]
	if !ok || op.Completed || op.Owner != owner || op.Epoch != epoch {
		return false
	}
	op.Completed = true
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
	id, firstEpoch := store.create("worker-a")
	secondEpoch, ok := store.acquire(id, "worker-b")
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
