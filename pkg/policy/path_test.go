package policy

import (
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"testing"
)

func TestPathCheckerReadInsideRoot(t *testing.T) {
	root := t.TempDir()
	c, err := NewPathChecker([]PathGrant{{Root: root, Access: AccessReadWrite}})
	if err != nil {
		t.Fatal(err)
	}
	d, err := c.Check(filepath.Join(root, "a.txt"), AccessRead)
	if err != nil {
		t.Fatal(err)
	}
	if !d.Allowed {
		t.Fatalf("denied in-root read: %+v", d)
	}
}

func TestPathCheckerDeniesWriteWithReadGrant(t *testing.T) {
	root := t.TempDir()
	c, err := NewPathChecker([]PathGrant{{Root: root, Access: AccessRead}})
	if err != nil {
		t.Fatal(err)
	}
	d, err := c.Check(filepath.Join(root, "a.txt"), AccessWrite)
	if err != nil {
		t.Fatal(err)
	}
	if d.Allowed {
		t.Fatal("read grant allowed a write")
	}
}

func TestPathCheckerWriteGrant(t *testing.T) {
	root := t.TempDir()
	c, err := NewPathChecker([]PathGrant{{Root: root, Access: AccessWrite}})
	if err != nil {
		t.Fatal(err)
	}
	d, err := c.Check(filepath.Join(root, "a.txt"), AccessWrite)
	if err != nil {
		t.Fatal(err)
	}
	if !d.Allowed {
		t.Fatal("write grant denied a write")
	}
}

func TestPathCheckerDeniesSiblingPrefix(t *testing.T) {
	base := t.TempDir()
	root := filepath.Join(base, "root")
	if err := os.MkdirAll(root, 0o755); err != nil {
		t.Fatal(err)
	}
	outside := filepath.Join(base, "root-evil")
	if err := os.MkdirAll(outside, 0o755); err != nil {
		t.Fatal(err)
	}
	c, err := NewPathChecker([]PathGrant{{Root: root, Access: AccessReadWrite}})
	if err != nil {
		t.Fatal(err)
	}
	d, err := c.Check(filepath.Join(outside, "x.txt"), AccessRead)
	if err != nil {
		t.Fatal(err)
	}
	if d.Allowed {
		t.Fatal("sibling prefix was treated as inside the root")
	}
}

func TestPathCheckerDeniesTraversal(t *testing.T) {
	base := t.TempDir()
	root := filepath.Join(base, "root")
	if err := os.MkdirAll(root, 0o755); err != nil {
		t.Fatal(err)
	}
	c, err := NewPathChecker([]PathGrant{{Root: root, Access: AccessReadWrite}})
	if err != nil {
		t.Fatal(err)
	}
	d, err := c.Check(filepath.Join(root, "..", "outside", "x.txt"), AccessRead)
	if err != nil {
		t.Fatal(err)
	}
	if d.Allowed {
		t.Fatal("traversal outside the root was allowed")
	}
}

func TestPathCheckerNonExistentInsideRoot(t *testing.T) {
	root := t.TempDir()
	c, err := NewPathChecker([]PathGrant{{Root: root, Access: AccessReadWrite}})
	if err != nil {
		t.Fatal(err)
	}
	d, err := c.Check(filepath.Join(root, "new", "dir", "file.txt"), AccessWrite)
	if err != nil {
		t.Fatal(err)
	}
	if !d.Allowed {
		t.Fatalf("non-existent in-root path denied: %+v", d)
	}
}

func TestPathCheckerSymlinkEscape(t *testing.T) {
	root := t.TempDir()
	outside := t.TempDir()
	if err := os.WriteFile(filepath.Join(outside, "secret.txt"), []byte("secret"), 0o600); err != nil {
		t.Fatal(err)
	}
	link := filepath.Join(root, "link")
	if err := os.Symlink(outside, link); err != nil {
		t.Skipf("symlinks unavailable: %v", err)
	}
	c, err := NewPathChecker([]PathGrant{{Root: root, Access: AccessReadWrite}})
	if err != nil {
		t.Fatal(err)
	}
	d, err := c.Check(filepath.Join(link, "secret.txt"), AccessRead)
	if err != nil {
		t.Fatal(err)
	}
	if d.Allowed {
		t.Fatal("symlink escape was allowed")
	}
}

func TestPathCheckerRootSymlink(t *testing.T) {
	real := t.TempDir()
	alias := filepath.Join(t.TempDir(), "alias")
	if err := os.Symlink(real, alias); err != nil {
		t.Skipf("symlinks unavailable: %v", err)
	}
	c, err := NewPathChecker([]PathGrant{{Root: alias, Access: AccessReadWrite}})
	if err != nil {
		t.Fatal(err)
	}
	d, err := c.Check(filepath.Join(real, "file.txt"), AccessRead)
	if err != nil {
		t.Fatal(err)
	}
	if !d.Allowed {
		t.Fatal("resolved root symlink did not match the real root")
	}
}

func TestPathCheckerEmptyGrantsDeny(t *testing.T) {
	c, err := NewPathChecker(nil)
	if err != nil {
		t.Fatal(err)
	}
	d, err := c.Check(filepath.Join(t.TempDir(), "x"), AccessRead)
	if err != nil {
		t.Fatal(err)
	}
	if d.Allowed {
		t.Fatal("empty grant set allowed a path")
	}
}

func TestPathCheckerInvalidAccess(t *testing.T) {
	if _, err := NewPathChecker([]PathGrant{{Root: t.TempDir(), Access: PathAccess("execute")}}); err == nil {
		t.Fatal("invalid grant access accepted")
	}
	c, err := NewPathChecker([]PathGrant{{Root: t.TempDir(), Access: AccessRead}})
	if err != nil {
		t.Fatal(err)
	}
	if _, err := c.Check(filepath.Join(t.TempDir(), "x"), PathAccess("execute")); err == nil {
		t.Fatal("invalid requested access accepted")
	}
}

func TestPathCheckerWindowsCaseInsensitive(t *testing.T) {
	if runtime.GOOS != "windows" {
		t.Skip("windows-only case check")
	}
	root := t.TempDir()
	c, err := NewPathChecker([]PathGrant{{Root: root, Access: AccessReadWrite}})
	if err != nil {
		t.Fatal(err)
	}
	target := filepath.Join(strings.ToUpper(root), "File.txt")
	d, err := c.Check(target, AccessRead)
	if err != nil {
		t.Fatal(err)
	}
	if !d.Allowed {
		t.Fatal("case-different path inside the root was denied")
	}
}
