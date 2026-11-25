package longrunning

import (
	"os"
	"path/filepath"
	"testing"
)

func TestFileSecretReload(t *testing.T) {
	path := filepath.Join(t.TempDir(), "token")
	if err := os.WriteFile(path, []byte("one\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	secret, err := NewFileSecret(path)
	if err != nil {
		t.Fatal(err)
	}
	value, err := secret.Value()
	if err != nil || value != "one" {
		t.Fatalf("value=%q err=%v", value, err)
	}
	if err := os.WriteFile(path, []byte("two\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	value, err = secret.Value()
	if err != nil || value != "two" {
		t.Fatalf("value=%q err=%v", value, err)
	}
}
