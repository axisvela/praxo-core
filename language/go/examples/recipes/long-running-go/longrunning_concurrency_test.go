package longrunning

import (
	"path/filepath"
	"testing"
)

func TestLongRunningConcurrentWritersLoseUpdates(t *testing.T) {
	path := filepath.Join(t.TempDir(), "operations.json")
	seed := newRemoteOperationsAt(path)
	if _, created := seed.submit("key-1"); !created {
		t.Fatal("seed submit was not created")
	}

	writerA := newRemoteOperationsAt(path)
	writerB := newRemoteOperationsAt(path)
	if _, created := writerA.submit("key-2"); !created {
		t.Fatal("writer A submit was not created")
	}
	if _, created := writerB.submit("key-3"); !created {
		t.Fatal("writer B submit was not created")
	}

	restarted := newRemoteOperationsAt(path)
	if _, ok := restarted.status("op-key-2"); ok {
		t.Fatal("known concurrent-writer lost update did not occur; update the documented limitation if locking was added")
	}
	if _, ok := restarted.status("op-key-3"); !ok {
		t.Fatal("last writer's operation is missing")
	}
	if effects := restarted.effectCount(); effects != 2 {
		t.Fatalf("effects=%d, want the last writer's value 2", effects)
	}
}
