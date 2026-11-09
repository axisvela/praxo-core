package longrunning

import (
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"testing"
)

func TestLongRunningFaultBeforeRenameKeepsCommittedState(t *testing.T) {
	path := filepath.Join(t.TempDir(), "operations.json")
	service := newRemoteOperationsAt(path)
	if _, created := service.submit("key-1"); !created {
		t.Fatal("first submit was not created")
	}

	service.commitHook = func(stage string) error {
		if stage == "before-rename" {
			return errors.New("simulated power loss before commit")
		}
		return nil
	}
	func() {
		defer func() {
			if recover() == nil {
				t.Fatal("save did not fail before the rename boundary")
			}
		}()
		service.submit("key-2")
	}()

	restarted := newRemoteOperationsAt(path)
	if effects := restarted.effectCount(); effects != 1 {
		t.Fatalf("effects=%d, want the last committed value 1", effects)
	}
	if _, ok := restarted.status("op-key-2"); ok {
		t.Fatal("uncommitted operation survived the simulated crash")
	}
	status, ok := restarted.status("op-key-1")
	if !ok || status.State != remoteAccepted {
		t.Fatalf("committed operation was lost: %#v ok=%v", status, ok)
	}
}

func TestLongRunningFaultAfterRenameKeepsNewState(t *testing.T) {
	path := filepath.Join(t.TempDir(), "operations.json")
	service := newRemoteOperationsAt(path)
	if _, created := service.submit("key-1"); !created {
		t.Fatal("first submit was not created")
	}

	service.commitHook = func(stage string) error {
		if stage == "after-rename" {
			return errors.New("simulated crash after commit")
		}
		return nil
	}
	func() {
		defer func() {
			if recover() == nil {
				t.Fatal("save did not fail after the rename boundary")
			}
		}()
		service.submit("key-2")
	}()

	restarted := newRemoteOperationsAt(path)
	if effects := restarted.effectCount(); effects != 2 {
		t.Fatalf("effects=%d, want the committed value 2", effects)
	}
	status, ok := restarted.status("op-key-2")
	if !ok || status.State != remoteAccepted {
		t.Fatalf("committed operation was lost after the rename: %#v ok=%v", status, ok)
	}
}

func TestLongRunningValidTempDoesNotOverrideCommittedState(t *testing.T) {
	path := filepath.Join(t.TempDir(), "operations.json")
	service := newRemoteOperationsAt(path)
	if _, created := service.submit("key-1"); !created {
		t.Fatal("first submit was not created")
	}

	newer := persistedOperations{
		Effects: 2,
		Next:    2,
		Operations: []remoteOperation{
			{ID: "op-key-1", Key: "key-1", State: remoteAccepted},
			{ID: "op-key-2", Key: "key-2", State: remoteAccepted},
		},
	}
	data, err := json.Marshal(newer)
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path+".tmp", data, 0o600); err != nil {
		t.Fatal(err)
	}

	restarted := newRemoteOperationsAt(path)
	if effects := restarted.effectCount(); effects != 1 {
		t.Fatalf("effects=%d, want the committed value 1", effects)
	}
	if _, ok := restarted.status("op-key-2"); ok {
		t.Fatal("a valid but uncommitted temp file overrode committed state")
	}
}

func TestLongRunningCorruptCommittedStateFailsClosed(t *testing.T) {
	path := filepath.Join(t.TempDir(), "operations.json")
	if err := os.WriteFile(path, []byte("{not-json"), 0o600); err != nil {
		t.Fatal(err)
	}
	defer func() {
		if recover() == nil {
			t.Fatal("corrupt committed state did not fail closed")
		}
	}()
	newRemoteOperationsAt(path)
}
