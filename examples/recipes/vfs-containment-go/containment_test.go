package vfs_containment_recipe

import (
	"context"
	"os"
	"path/filepath"
	"testing"

	"github.com/axisvela/praxo-core/v2/pkg/policy"
	"github.com/axisvela/praxo-core/v2/pkg/vfs/localfs"
)

func TestLocalBackendRoundTripAndTraversal(t *testing.T) {
	backend, err := localfs.New(t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	ctx := context.Background()
	if err := backend.Write(ctx, "notes/a.txt", []byte("hello")); err != nil {
		t.Fatal(err)
	}
	data, err := backend.Read(ctx, "notes/a.txt")
	if err != nil {
		t.Fatal(err)
	}
	if string(data) != "hello" {
		t.Fatalf("read = %q", data)
	}
	if err := backend.Write(ctx, "../escape", []byte("x")); err == nil {
		t.Fatal("traversal path was accepted")
	}
	if err := backend.Write(ctx, "bad\x00name", []byte("x")); err == nil {
		t.Fatal("NUL byte path was accepted")
	}
	if err := backend.Delete(ctx, "", true); err == nil {
		t.Fatal("root delete was accepted")
	}
}

func TestSymlinkEscapeIsRejected(t *testing.T) {
	root := t.TempDir()
	outside := t.TempDir()
	if err := os.WriteFile(filepath.Join(outside, "secret"), []byte("x"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(outside, filepath.Join(root, "link")); err != nil {
		t.Skipf("symlinks unavailable: %v", err)
	}
	backend, err := localfs.New(root)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := backend.Read(context.Background(), "link/secret"); err == nil {
		t.Fatal("symlink escape was accepted")
	}
}

func TestPathCheckerGrantsAndDenials(t *testing.T) {
	root := t.TempDir()
	checker, err := policy.NewPathChecker([]policy.PathGrant{{Root: root, Access: policy.AccessRead}})
	if err != nil {
		t.Fatal(err)
	}
	inside := filepath.Join(root, "a.txt")
	allowed, err := checker.Check(inside, policy.AccessRead)
	if err != nil || !allowed.Allowed {
		t.Fatalf("read decision = %+v err=%v", allowed, err)
	}
	denied, err := checker.Check(inside, policy.AccessWrite)
	if err != nil || denied.Allowed {
		t.Fatalf("write decision = %+v err=%v", denied, err)
	}
	traversal, err := checker.Check(filepath.Join(root, "..", "outside", "x.txt"), policy.AccessRead)
	if err != nil || traversal.Allowed {
		t.Fatalf("traversal decision = %+v err=%v", traversal, err)
	}
	sibling, err := checker.Check(filepath.Join(root, "..", filepath.Base(root)+"-evil", "x.txt"), policy.AccessRead)
	if err != nil || sibling.Allowed {
		t.Fatalf("sibling decision = %+v err=%v", sibling, err)
	}

	empty, err := policy.NewPathChecker(nil)
	if err != nil {
		t.Fatal(err)
	}
	none, err := empty.Check(inside, policy.AccessRead)
	if err != nil || none.Allowed {
		t.Fatalf("empty checker decision = %+v err=%v", none, err)
	}
}
