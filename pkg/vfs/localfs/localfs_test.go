package localfs

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"reflect"
	"runtime"
	"testing"

	"github.com/axisvela/praxo-core/v2/pkg/vfs"
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

func TestLocalBackendGrepRejectsSymlinkEscape(t *testing.T) {
	b, err := New(t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	ctx := context.Background()
	if err := b.Write(ctx, "nested/a.txt", []byte("needle inside")); err != nil {
		t.Fatal(err)
	}
	outside := filepath.Join(t.TempDir(), "secret.txt")
	if err := os.WriteFile(outside, []byte("needle external secret"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(outside, filepath.Join(b.Root(), "nested", "z-link.txt")); err != nil {
		t.Skipf("symlinks unavailable: %v", err)
	}
	for _, path := range []string{"nested/z-link.txt", "nested", ""} {
		t.Run("path="+path, func(t *testing.T) {
			matches, err := b.Grep(ctx, "needle", path)
			if !errors.Is(err, os.ErrPermission) || matches != nil {
				t.Fatalf("grep = %+v, %v; want nil matches and permission error", matches, err)
			}
		})
	}
}

func TestLocalBackendGrepInRootSymlink(t *testing.T) {
	b, err := New(t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	ctx := context.Background()
	if err := b.Write(ctx, "target.txt", []byte("other\nneedle inside\n")); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(filepath.Join(b.Root(), "target.txt"), filepath.Join(b.Root(), "link.txt")); err != nil {
		t.Skipf("symlinks unavailable: %v", err)
	}
	for _, path := range []string{"link.txt", ""} {
		want := []vfs.Match{{Path: "link.txt", Line: 2, Text: "needle inside"}}
		if path == "" {
			want = append(want, vfs.Match{Path: "target.txt", Line: 2, Text: "needle inside"})
		}
		matches, err := b.Grep(ctx, "needle", path)
		if err != nil || !reflect.DeepEqual(matches, want) {
			t.Fatalf("grep %q = %+v, %v; want %+v", path, matches, err, want)
		}
	}
}

func TestLocalBackendGrepBrokenSymlink(t *testing.T) {
	b, err := New(t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	ctx := context.Background()
	if err := b.Write(ctx, "a.txt", []byte("needle inside")); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(filepath.Join(b.Root(), "missing.txt"), filepath.Join(b.Root(), "broken.txt")); err != nil {
		t.Skipf("symlinks unavailable: %v", err)
	}
	if matches, err := b.Grep(ctx, "needle", "broken.txt"); !errors.Is(err, vfs.ErrNotFound) || matches != nil {
		t.Fatalf("direct grep = %+v, %v; want nil matches and not found", matches, err)
	}
	want := []vfs.Match{{Path: "a.txt", Line: 1, Text: "needle inside"}}
	if matches, err := b.Grep(ctx, "needle", ""); err != nil || !reflect.DeepEqual(matches, want) {
		t.Fatalf("directory grep = %+v, %v; want %+v", matches, err, want)
	}
}

func TestLocalBackendGrepTraversal(t *testing.T) {
	b, err := New(t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	ctx := context.Background()
	for path, text := range map[string]string{
		"a.txt":             "needle root",
		"nested/b.txt":      "other\nneedle nested\n",
		"nested/deep/c.txt": "needle deep",
		"nested/other.txt":  "no match",
	} {
		if err := b.Write(ctx, path, []byte(text)); err != nil {
			t.Fatal(err)
		}
	}
	want := []vfs.Match{
		{Path: "nested/b.txt", Line: 2, Text: "needle nested"},
		{Path: "nested/deep/c.txt", Line: 1, Text: "needle deep"},
	}
	if matches, err := b.Grep(ctx, "needle", "nested"); err != nil || !reflect.DeepEqual(matches, want) {
		t.Fatalf("grep = %+v, %v; want %+v", matches, err, want)
	}
	if matches, err := b.Grep(ctx, "needle", "../"); !errors.Is(err, os.ErrPermission) || matches != nil {
		t.Fatalf("escape grep = %+v, %v; want nil matches and permission error", matches, err)
	}
}
