package vfstools

import (
	"context"
	"testing"

	"github.com/axisvela/praxo-core/pkg/tool"
	"github.com/axisvela/praxo-core/pkg/vfs"
	"github.com/axisvela/praxo-core/pkg/vfs/localfs"
)

func toolMap(t *testing.T, backend *localfs.Backend) map[string]tool.Tool {
	t.Helper()
	out := map[string]tool.Tool{}
	for _, tl := range Tools(backend) {
		out[tl.Name()] = tl
	}
	return out
}

func TestFilesystemToolsRoundTrip(t *testing.T) {
	backend, err := localfs.New(t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	tools := toolMap(t, backend)
	ctx := context.Background()

	if _, err := tools["fs.write"].Invoke(ctx, map[string]any{"path": "dir/a.txt", "content": "hello"}); err != nil {
		t.Fatal(err)
	}
	got, err := tools["fs.read"].Invoke(ctx, map[string]any{"path": "dir/a.txt"})
	if err != nil || got != "hello" {
		t.Fatalf("read = %v, %v", got, err)
	}
	if _, err := tools["fs.edit"].Invoke(ctx, map[string]any{"path": "dir/a.txt", "old": "hello", "new": "world"}); err != nil {
		t.Fatal(err)
	}
	got, _ = tools["fs.read"].Invoke(ctx, map[string]any{"path": "dir/a.txt"})
	if got != "world" {
		t.Fatalf("edited = %v", got)
	}
	globbed, err := tools["fs.glob"].Invoke(ctx, map[string]any{"pattern": "**/*.txt"})
	if err != nil {
		t.Fatal(err)
	}
	if paths, _ := globbed.([]string); len(paths) != 1 || paths[0] != "dir/a.txt" {
		t.Fatalf("glob = %+v", globbed)
	}
	matches, err := tools["fs.grep"].Invoke(ctx, map[string]any{"pattern": "world", "path": "dir"})
	if err != nil {
		t.Fatal(err)
	}
	if m, ok := matches.([]vfs.Match); !ok || len(m) != 1 {
		t.Fatalf("grep = %+v", matches)
	}
	if _, err := tools["fs.delete"].Invoke(ctx, map[string]any{"path": "dir", "recursive": true}); err != nil {
		t.Fatal(err)
	}
	if _, ok := tools["fs.execute"]; ok {
		t.Fatal("localfs unexpectedly exposed fs.execute")
	}
}
