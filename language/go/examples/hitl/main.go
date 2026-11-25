package main

import (
	"context"
	"fmt"
	"io"
	"os"
	"strings"

	"github.com/axisvela/praxo-core/v2/pkg/agent"
	"github.com/axisvela/praxo-core/v2/pkg/model"
	"github.com/axisvela/praxo-core/v2/pkg/policy"
	"github.com/axisvela/praxo-core/v2/pkg/tool"
)

type writeNoteTool struct {
	notes []string
}

func (*writeNoteTool) Name() string { return "write_note" }

func (*writeNoteTool) Description() string {
	return "Write a short note with the requested visibility."
}

func (*writeNoteTool) Spec() model.ToolSpec {
	return model.ToolSpec{
		Name:        "write_note",
		Description: "Write a short note with the requested visibility.",
		Parameters: map[string]any{
			"type":     "object",
			"required": []string{"text", "visibility"},
			"properties": map[string]any{
				"text":       map[string]any{"type": "string"},
				"visibility": map[string]any{"type": "string", "enum": []string{"public", "private"}},
			},
		},
	}
}

func (t *writeNoteTool) Invoke(_ context.Context, args map[string]any) (any, error) {
	t.notes = append(t.notes, fmt.Sprint(args["text"]))
	return "written", nil
}

type fixtureModel struct{}

func (fixtureModel) Generate(_ context.Context, req model.Request) (model.Response, error) {
	last := req.Messages[len(req.Messages)-1]
	if last.Role == model.RoleTool {
		return model.Response{Message: model.Message{Role: model.RoleAssistant, Content: "done"}}, nil
	}
	return model.Response{Message: model.Message{
		Role: model.RoleAssistant,
		ToolCalls: []model.ToolCall{{
			ID:   "write-note-1",
			Name: "write_note",
			Arguments: map[string]any{
				"text":       "hello",
				"visibility": "public",
			},
		}},
	}}, nil
}

func allowPublicNotes(_ context.Context, action policy.Action) (policy.Decision, error) {
	switch action.Kind {
	case "model.generate":
		return policy.Decision{Allowed: true}, nil
	case "tool.invoke":
		return policy.Decision{
			Allowed: action.ToolName == "write_note" && action.Arguments["visibility"] == "public",
			Reason:  "only public notes are permitted",
		}, nil
	default:
		return policy.Decision{Reason: "unsupported action"}, nil
	}
}

func runScenario(ctx context.Context, decision agent.InterruptDecision) (string, int, error) {
	impl := &writeNoteTool{}
	tools := tool.NewRegistry()
	tools.Register(impl)
	ag, err := agent.New(agent.Options{
		Model:        fixtureModel{},
		Tools:        tools,
		MaxSteps:     3,
		AllowedTools: []string{"write_note"},
		Policy:       policy.FuncHook(allowPublicNotes),
		InterruptOn:  map[string]bool{"write_note": true},
		OnInterruptDecision: func(context.Context, agent.Interrupt) (agent.InterruptDecision, error) {
			return decision, nil
		},
	})
	if err != nil {
		return "", len(impl.notes), err
	}
	result, err := ag.Run(ctx, agent.Session{ID: "hitl"}, "Write a note.")
	if err != nil {
		return "", len(impl.notes), err
	}
	return result.Output, len(impl.notes), nil
}

func run(ctx context.Context, out io.Writer) error {
	output, effects, err := runScenario(ctx, agent.InterruptDecision{Action: agent.InterruptApprove})
	if err != nil || output != "done" || effects != 1 {
		return fmt.Errorf("approve scenario failed: output=%q effects=%d error=%v", output, effects, err)
	}
	fmt.Fprintln(out, "approve: written; effects=1")

	_, effects, err = runScenario(ctx, agent.InterruptDecision{
		Action: agent.InterruptEdit,
		Arguments: map[string]any{
			"text":       "hello",
			"visibility": "private",
		},
	})
	if err == nil || !strings.Contains(err.Error(), "tool.invoke denied") || effects != 0 {
		return fmt.Errorf("edit scenario failed: effects=%d error=%v", effects, err)
	}
	fmt.Fprintln(out, "edit: policy rejected; effects=0")
	return nil
}

func main() {
	if err := run(context.Background(), os.Stdout); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
