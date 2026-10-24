package localfs

import (
	"context"
	"os"
	"path/filepath"
	"runtime"
	"testing"
)

func TestLocalBackendRoundTrip(t *testing.T) {
	root := t.TempDir()
	b, err := New(root)
	if err != nil {
		t.Fatal(err)
	}
	ctx := context.Background()
	if err := b.Write(ctx, "a/b.txt", []byte("hello world")); err != nil {
		t.Fatal(err)
	}
	data, err := b.Read(ctx, "a/b.txt")
	if err != nil || string(data) != "hello world" {
		t.Fatalf("read = %q, %v", data, err)
	}
	entries, err := b.List(ctx, "a")
	if err != nil || len(entries) != 1 {
		t.Fatalf("list = %+v, %v", entries, err)
	}
	paths, err := b.Glob(ctx, "**/*.txt")
	if err != nil || len(paths) != 1 || paths[0] != "a/b.txt" {
		t.Fatalf("glob = %v, %v", paths, err)
	}
	matches, err := b.Grep(ctx, "hello", "")
	if err != nil || len(matches) != 1 || matches[0].Line != 1 {
		t.Fatalf("grep = %+v, %v", matches, err)
	}
	if err := b.Delete(ctx, "a", true); err != nil {
		t.Fatal(err)
	}
	if _, err := b.Read(ctx, "a/b.txt"); err == nil {
		t.Fatal("deleted file still readable")
	}
}

func TestLocalBackendRejectsEscape(t *testing.T) {
	b, err := New(t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	if err := b.Write(context.Background(), "../escape", []byte("x")); err == nil {
		t.Fatal("traversal path accepted")
	}
}

func TestLocalBackendRejectsSymlinkEscape(t *testing.T) {
	root := t.TempDir()
	outside := t.TempDir()
	if err := os.WriteFile(filepath.Join(outside, "secret"), []byte("x"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(outside, filepath.Join(root, "link")); err != nil {
		t.Skipf("symlinks unavailable: %v", err)
	}
	b, err := New(root)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := b.Read(context.Background(), "link/secret"); err == nil {
		t.Fatal("symlink escape accepted")
	}
}

func TestLocalBackendRejectsNULByte(t *testing.T) {
	b, err := New(t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	if err := b.Write(context.Background(), "bad\x00name", []byte("x")); err == nil {
		t.Fatal("NUL byte path accepted")
	}
}

func TestLocalBackendRejectsWindowsSpecialPaths(t *testing.T) {
	if runtime.GOOS != "windows" {
		t.Skip("windows-only path checks")
	}
	b, err := New(t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	ctx := context.Background()
	for _, target := range []string{
		"C:evil.txt",
		"NUL",
		"nul.txt",
		"CON",
		"PRN",
		"AUX",
		"COM1",
		"LPT1",
		"file:stream",
		"trailing.",
		"trailing ",
		"nested/NUL.txt",
	} {
		if err := b.Write(ctx, target, []byte("x")); err == nil {
			t.Errorf("special path %q accepted", target)
		}
	}
	for _, target := range []string{"normal.txt", "COM10", "console"} {
		if err := b.Write(ctx, target, []byte("x")); err != nil {
			t.Errorf("normal path %q rejected: %v", target, err)
		}
	}
}

func TestLocalBackendRefusesRootDelete(t *testing.T) {
	b, err := New(t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	if err := b.Delete(context.Background(), "", true); err == nil {
		t.Fatal("root delete accepted")
	}
}
