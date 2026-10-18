package agent

import (
	"context"
	"errors"
	"testing"

	"github.com/axisvela/praxo-core/v2/pkg/model"
	"github.com/axisvela/praxo-core/v2/pkg/tool"
)

type interruptModel struct {
	calls int
	mode  string
}

func (m *interruptModel) Generate(_ context.Context, req model.Request) (model.Response, error) {
	m.calls++
	if m.calls == 1 {
		return model.Response{Message: model.Message{ToolCalls: []model.ToolCall{{
			ID:        "call-1",
			Name:      "echo",
			Arguments: map[string]any{"value": "original"},
		}}}}, nil
	}
	if m.mode == "respond" {
		for i := len(req.Messages) - 1; i >= 0; i-- {
			if req.Messages[i].Role == model.RoleTool {
				return model.Response{Message: model.Message{Content: req.Messages[i].Content}}, nil
			}
		}
	}
	return model.Response{Message: model.Message{Content: "final"}}, nil
}

type recordingTool struct {
	args map[string]any
}

func (t *recordingTool) Name() string        { return "echo" }
func (t *recordingTool) Description() string { return "echo" }
func (t *recordingTool) Invoke(_ context.Context, args map[string]any) (any, error) {
	t.args = args
	return args["value"], nil
}

func interruptAgent(model model.Model, toolImpl tool.Tool, decision func(context.Context, Interrupt) (InterruptDecision, error)) *Agent {
	registry := tool.NewRegistry()
	registry.Register(toolImpl)
	return &Agent{
		Model:               model,
		Tools:               registry,
		MaxSteps:            4,
		InterruptOn:         map[string]bool{"echo": true},
		OnInterruptDecision: decision,
	}
}

func TestInterruptEditReplacesArguments(t *testing.T) {
	impl := &recordingTool{}
	ag := interruptAgent(&interruptModel{}, impl, func(context.Context, Interrupt) (InterruptDecision, error) {
		return InterruptDecision{Action: InterruptEdit, Arguments: map[string]any{"value": "edited"}}, nil
	})
	result, err := ag.Run(context.Background(), Session{ID: "s"}, "go")
	if err != nil {
		t.Fatal(err)
	}
	if impl.args["value"] != "edited" || result.Output != "final" {
		t.Fatalf("args=%+v output=%q", impl.args, result.Output)
	}
}

func TestInterruptRejectFailsRun(t *testing.T) {
	ag := interruptAgent(&interruptModel{}, &recordingTool{}, func(context.Context, Interrupt) (InterruptDecision, error) {
		return InterruptDecision{Action: InterruptReject, Reason: "not allowed"}, nil
	})
	_, err := ag.Run(context.Background(), Session{ID: "s"}, "go")
	if !errors.Is(err, ErrApprovalDenied) {
		t.Fatalf("err = %v, want ErrApprovalDenied", err)
	}
}

func TestInterruptRespondSkipsTool(t *testing.T) {
	impl := &recordingTool{}
	ag := interruptAgent(&interruptModel{mode: "respond"}, impl, func(context.Context, Interrupt) (InterruptDecision, error) {
		return InterruptDecision{Action: InterruptRespond, Response: "human answer"}, nil
	})
	result, err := ag.Run(context.Background(), Session{ID: "s"}, "go")
	if err != nil {
		t.Fatal(err)
	}
	if impl.args != nil {
		t.Fatalf("tool was invoked with %+v", impl.args)
	}
	if result.Output == "" || result.Output == "final" {
		t.Fatalf("output = %q, want human answer", result.Output)
	}
}

func TestInterruptApproveRunsTool(t *testing.T) {
	impl := &recordingTool{}
	ag := interruptAgent(&interruptModel{}, impl, func(context.Context, Interrupt) (InterruptDecision, error) {
		return InterruptDecision{Action: InterruptApprove}, nil
	})
	if _, err := ag.Run(context.Background(), Session{ID: "s"}, "go"); err != nil {
		t.Fatal(err)
	}
	if impl.args["value"] != "original" {
		t.Fatalf("args = %+v", impl.args)
	}
}

func TestInterruptInvalidDecision(t *testing.T) {
	ag := interruptAgent(&interruptModel{}, &recordingTool{}, func(context.Context, Interrupt) (InterruptDecision, error) {
		return InterruptDecision{Action: "invalid"}, nil
	})
	if _, err := ag.Run(context.Background(), Session{ID: "s"}, "go"); !errors.Is(err, ErrInterruptDecisionInvalid) {
		t.Fatalf("err = %v, want ErrInterruptDecisionInvalid", err)
	}
}
