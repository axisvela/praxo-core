package profile

import (
	"context"
	"testing"

	"github.com/axisvela/praxo-core/adapters/workspace/contract"
	"github.com/axisvela/praxo-core/adapters/workspace/fake"
	"github.com/axisvela/praxo-core/v2/pkg/vfs"
)

func TestSandboxProfileWithWorkspaceSession(t *testing.T) {
	ctx := context.Background()
	provider := fake.NewProvider()
	session, err := provider.Create(ctx, contract.Spec{WorkDir: "/workspace"})
	if err != nil {
		t.Fatalf("create session: %v", err)
	}
	defer session.Close(ctx)

	profile := Profile{
		Kind:      KindSandbox,
		Files:     session,
		Session:   session,
		Trust:     TrustIsolated,
		Isolation: IsolationProvider,
		Capabilities: Capabilities{
			Execute:  true,
			Upload:   true,
			Download: true,
			Pause:    true,
		},
	}
	if err := profile.Validate(); err != nil {
		t.Fatalf("validate: %v", err)
	}
	tools := profile.Tools()
	if len(tools) == 0 {
		t.Fatal("no tools")
	}

	writeTool, ok := findTool(tools, "fs.write")
	if !ok {
		t.Fatal("missing fs.write")
	}
	if _, err := writeTool.Invoke(ctx, map[string]any{
		"path":    "notes.txt",
		"content": "hello",
	}); err != nil {
		t.Fatalf("write: %v", err)
	}

	readTool, ok := findTool(tools, "fs.read")
	if !ok {
		t.Fatal("missing fs.read")
	}
	value, err := readTool.Invoke(ctx, map[string]any{"path": "notes.txt"})
	if err != nil {
		t.Fatalf("read: %v", err)
	}
	if value != "hello" {
		t.Fatalf("read = %#v", value)
	}

	executeTool, ok := findTool(tools, "fs.execute")
	if !ok {
		t.Fatal("missing fs.execute")
	}
	result, err := executeTool.Invoke(ctx, map[string]any{
		"command": []any{"echo", "ok"},
	})
	if err != nil {
		t.Fatalf("execute: %v", err)
	}
	if result.(vfs.Result).Stdout != "echo ok" {
		t.Fatalf("execute result = %#v", result)
	}

	pauser, ok := session.(contract.Pauser)
	if !ok {
		t.Fatal("session does not implement Pauser")
	}
	if err := pauser.Pause(ctx); err != nil {
		t.Fatalf("pause: %v", err)
	}
}
