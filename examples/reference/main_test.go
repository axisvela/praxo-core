package main

import (
	"context"
	"testing"

	"github.com/axisvela/praxo-core/v2/pkg/policy"
)

func TestWorkspacePolicy(t *testing.T) {
	tests := []struct {
		name    string
		action  policy.Action
		allowed bool
	}{
		{name: "model", action: policy.Action{Kind: "model.generate"}, allowed: true},
		{name: "workspace tool", action: policy.Action{Kind: "tool.invoke", ToolName: "fs.read"}, allowed: true},
		{name: "other tool", action: policy.Action{Kind: "tool.invoke", ToolName: "exec"}},
		{name: "other action", action: policy.Action{Kind: "memory.read"}},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			decision, err := workspacePolicy(context.Background(), test.action)
			if err != nil {
				t.Fatal(err)
			}
			if decision.Allowed != test.allowed {
				t.Fatalf("decision = %#v", decision)
			}
		})
	}
}
