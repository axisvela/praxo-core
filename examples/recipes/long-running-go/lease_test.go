package longrunning

import (
	"context"
	"path/filepath"
	"sync"
	"testing"
	"time"
)

func TestFileLeaseSerializes(t *testing.T) {
	lease := NewFileLease(filepath.Join(t.TempDir(), "operations.lock"), time.Second)
	release, err := lease.Acquire(context.Background(), "a")
	if err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 100*time.Millisecond)
	defer cancel()
	if _, err := lease.Acquire(ctx, "b"); err == nil {
		t.Fatal("second file lease acquisition succeeded")
	}
	release()
	release, err = lease.Acquire(context.Background(), "b")
	if err != nil {
		t.Fatal(err)
	}
	release()
}

func TestConcurrentWritersWithFileLease(t *testing.T) {
	path := filepath.Join(t.TempDir(), "operations.json")
	verifier := newEffectVerifier("test-secret")
	lockPath := path + ".lock"
	writerA := newRemoteOperationsWithLease(path, verifier, NewFileLease(lockPath, time.Second), "a")
	writerB := newRemoteOperationsWithLease(path, verifier, NewFileLease(lockPath, time.Second), "b")
	runConcurrentSubmits(t, writerA, writerB)
}

func runConcurrentSubmits(t *testing.T, writerA, writerB *remoteOperations) {
	t.Helper()
	var wait sync.WaitGroup
	wait.Add(2)
	go func() {
		defer wait.Done()
		writerA.submit("key-1")
	}()
	go func() {
		defer wait.Done()
		writerB.submit("key-2")
	}()
	wait.Wait()

	restarted := newRemoteOperationsWithVerifier(writerA.path, newEffectVerifier("test-secret"))
	for _, id := range []string{"op-key-1", "op-key-2"} {
		if _, ok := restarted.status(id); !ok {
			t.Fatalf("operation %s was lost", id)
		}
	}
	if effects := restarted.effectCount(); effects != 2 {
		t.Fatalf("effects=%d, want 2", effects)
	}
}
