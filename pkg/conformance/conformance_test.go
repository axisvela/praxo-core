package conformance

import (
	"context"
	"testing"

	"github.com/axisvela/praxo-core/v2/pkg/memory"
	"github.com/axisvela/praxo-core/v2/pkg/vfs/localfs"
)

func TestCheckVFSBackend(t *testing.T) {
	backend, err := localfs.New(t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	if err := CheckVFSBackend(context.Background(), backend); err != nil {
		t.Fatal(err)
	}
}

func TestCheckMemoryStore(t *testing.T) {
	if err := CheckMemoryStore(context.Background(), memory.NewMemoryStore()); err != nil {
		t.Fatal(err)
	}
}
