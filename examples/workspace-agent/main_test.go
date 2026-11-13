package main

import (
	"context"
	"testing"

	"github.com/axisvela/praxo-core/v2/pkg/policy"
)

func TestReadOnlyPolicyAllowsReadTools(t *testing.T) {
	for _, name := range []string{"fs.list", "fs.read", "fs.glob", "fs.grep"} {
		decision, err := readOnlyPolicy(context.Background(), policy.Action{
			Kind:     "tool.invoke",
			ToolName: name,
			Arguments: map[string]any{
				"path": "report.txt",
			},
		})
		if err != nil || !decision.Allowed {
			t.Fatalf("%s should be allowed: decision=%+v err=%v", name, decision, err)
		}
	}
}

func TestReadOnlyPolicyDeniesWrites(t *testing.T) {
	decision, err := readOnlyPolicy(context.Background(), policy.Action{
		Kind:     "tool.invoke",
		ToolName: "fs.write",
		Arguments: map[string]any{
			"path": "notes.md",
		},
	})
	if err != nil || decision.Allowed {
		t.Fatalf("fs.write must be denied: decision=%+v err=%v", decision, err)
	}
}

func TestReadOnlyPolicyRejectsEscapingPaths(t *testing.T) {
	for _, path := range []string{"../secret.txt", "/etc/passwd", `..\secret.txt`} {
		decision, err := readOnlyPolicy(context.Background(), policy.Action{
			Kind:     "tool.invoke",
			ToolName: "fs.read",
			Arguments: map[string]any{
				"path": path,
			},
		})
		if err != nil || decision.Allowed {
			t.Fatalf("%s must be denied: decision=%+v err=%v", path, decision, err)
		}
	}
}
