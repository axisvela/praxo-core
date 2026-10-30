package cubesandbox

import (
	"context"
	"strings"
	"testing"

	"github.com/axisvela/praxo-core/adapters/workspace/contract"
	"github.com/axisvela/praxo-core/adapters/workspace/profile"
	"github.com/axisvela/praxo-core/v2/pkg/tool"
	"github.com/axisvela/praxo-core/v2/pkg/vfs"
)

func TestProfileWithProvider(t *testing.T) {
	ctx := context.Background()
	provider := newProvider(newFakeClient(), Config{})
	session, err := provider.Create(ctx, contract.Spec{})
	if err != nil {
		t.Fatal(err)
	}
	defer session.Close(ctx)

	workspace := profile.Profile{
		Kind:      profile.KindSandbox,
		Files:     session,
		Session:   session,
		Trust:     profile.TrustIsolated,
		Isolation: profile.IsolationProvider,
		Capabilities: profile.Capabilities{
			Execute:  true,
			Upload:   true,
			Download: true,
			Pause:    true,
		},
	}
	if err := workspace.Validate(); err != nil {
		t.Fatal(err)
	}
	tools := workspace.Tools()
	write := findProfileTool(t, tools, "fs.write")
	if _, err := write.Invoke(ctx, map[string]any{"path": "notes.txt", "content": "hello"}); err != nil {
		t.Fatal(err)
	}
	read := findProfileTool(t, tools, "fs.read")
	value, err := read.Invoke(ctx, map[string]any{"path": "notes.txt"})
	if err != nil {
		t.Fatal(err)
	}
	if value != "hello" {
		t.Fatalf("read = %#v", value)
	}
	execute := findProfileTool(t, tools, "fs.execute")
	result, err := execute.Invoke(ctx, map[string]any{"command": []any{"echo", "ok"}})
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(result.(vfs.Result).Stdout, "echo ok") {
		t.Fatalf("execute = %#v", result)
	}
	pauser, ok := session.(contract.Pauser)
	if !ok {
		t.Fatal("session does not implement Pauser")
	}
	if err := pauser.Pause(ctx); err != nil {
		t.Fatal(err)
	}
}

func findProfileTool(t *testing.T, tools []tool.Tool, name string) tool.Tool {
	t.Helper()
	for _, item := range tools {
		if item.Name() == name {
			return item
		}
	}
	t.Fatalf("missing %s", name)
	return nil
}
