package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
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
	path string
}

type persistedFenced struct {
	Operations []fencedOperation
	Next       int
}

func newFencedStore() *fencedStore {
	return newFencedStoreAt("")
}

func newFencedStoreAt(path string) *fencedStore {
	store := &fencedStore{ops: map[string]*fencedOperation{}, path: path}
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

func (f *fencedStore) create(owner string) (string, int) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.next++
	op := &fencedOperation{ID: fmt.Sprintf("fence-%d", f.next), Owner: owner, Epoch: 1}
	f.ops[op.ID] = op
	f.save()
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
	f.save()
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

func TestLongRunningDurableFencingAfterRestart(t *testing.T) {
	path := filepath.Join(t.TempDir(), "fencing.json")
	store := newFencedStoreAt(path)
	id, firstEpoch := store.create("worker-a")
	secondEpoch, ok := store.acquire(id, "worker-b")
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
