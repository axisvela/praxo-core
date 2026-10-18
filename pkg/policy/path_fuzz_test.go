package policy

import (
	"os"
	"testing"
)

func FuzzPathChecker(f *testing.F) {
	root, err := os.MkdirTemp("", "praxo-path-fuzz-")
	if err != nil {
		f.Fatal(err)
	}
	defer os.RemoveAll(root)
	f.Add("file.txt")
	f.Add("../escape")
	f.Add("")
	f.Add("a/../../b")
	f.Fuzz(func(t *testing.T, target string) {
		c, err := NewPathChecker([]PathGrant{{Root: root, Access: AccessReadWrite}})
		if err != nil {
			t.Fatal(err)
		}
		_, _ = c.Check(target, AccessRead)
	})
}
