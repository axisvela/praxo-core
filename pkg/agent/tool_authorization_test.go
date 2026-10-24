package agent

import (
	"context"
	"errors"
	"strconv"
	"testing"

	"github.com/axisvela/praxo-core/v2/pkg/event"
	"github.com/axisvela/praxo-core/v2/pkg/model"
	"github.com/axisvela/praxo-core/v2/pkg/policy"
)

func TestFinalToolArgumentsAuthorized(t *testing.T) {
	policyErr := errors.New("policy unavailable")
	for _, parallel := range []int{1, 2} {
		for _, phase := range []string{"unchanged", "middleware", "hitl", "hook", "event", "stream"} {
			for _, outcome := range []string{"allow", "deny", "error"} {
				t.Run(phase+"/"+outcome+"/"+strconv.Itoa(parallel), func(t *testing.T) {
					impl := &recordingTool{}
					ag := interruptAgent(&interruptModel{}, impl, func(context.Context, Interrupt) (InterruptDecision, error) {
						if phase == "hitl" {
							return InterruptDecision{Action: InterruptEdit, Arguments: map[string]any{"value": "edited"}}, nil
						}
						return InterruptDecision{Action: InterruptApprove}, nil
					})
					ag.MaxParallelTools = parallel
					ag.Middleware = []Middleware{{BeforeTool: func(_ context.Context, call *ToolCall) error {
						if phase == "middleware" {
							call.Call.Arguments["value"] = "edited"
						}
						return nil
					}}}
					ag.Hooks.OnToolCall = func(_ context.Context, _ string, call model.ToolCall) error {
						if phase == "hook" {
							call.Arguments["value"] = "edited"
						}
						return nil
					}
					ag.Events = event.FuncSink(func(_ context.Context, e event.Event) error {
						if phase == "event" && e.Type == "tool.call" {
							e.Data["arguments"].(map[string]any)["value"] = "edited"
						}
						return nil
					})
					ag.OnStream = func(part StreamPart) error {
						data, ok := part.Data.(map[string]any)
						if phase == "stream" && part.Kind == StreamTasks && ok && data["status"] == "start" {
							data["arguments"].(map[string]any)["value"] = "edited"
						}
						return nil
					}
					var checked []string
					ag.Policy = policy.FuncHook(func(_ context.Context, action policy.Action) (policy.Decision, error) {
						if action.Kind != "tool.invoke" {
							return policy.Decision{Allowed: true}, nil
						}
						value := action.Arguments["value"].(string)
						checked = append(checked, value)
						if value == "edited" {
							if outcome == "error" {
								return policy.Decision{}, policyErr
							}
							return policy.Decision{Allowed: outcome == "allow"}, nil
						}
						return policy.Decision{Allowed: true}, nil
					})
					_, err := ag.Run(context.Background(), Session{ID: "s"}, "go")
					if phase != "unchanged" && outcome != "allow" {
						if err == nil || impl.args != nil {
							t.Fatalf("executed changed arguments without authorization: args=%v err=%v", impl.args, err)
						}
						if outcome == "error" && !errors.Is(err, policyErr) {
							t.Fatalf("lost policy error: %v", err)
						}
					} else if err != nil || impl.args == nil {
						t.Fatalf("allowed tool failed: args=%v err=%v", impl.args, err)
					}
					wantChecks := 2
					if phase == "unchanged" {
						wantChecks = 1
					}
					if len(checked) != wantChecks || checked[0] != "original" || (wantChecks == 2 && checked[1] != "edited") {
						t.Fatalf("authorization arguments=%v", checked)
					}
				})
			}
		}
	}
}

type renamedRecordingTool struct {
	*recordingTool
	name string
}

func (t renamedRecordingTool) Name() string { return t.name }

func TestFinalToolNameChecksAllowlist(t *testing.T) {
	impl := &recordingTool{}
	ag := interruptAgent(&interruptModel{}, impl, func(context.Context, Interrupt) (InterruptDecision, error) {
		return InterruptDecision{Action: InterruptApprove}, nil
	})
	ag.AllowedTools = []string{"echo"}
	ag.Tools.Register(renamedRecordingTool{recordingTool: impl, name: "blocked"})
	ag.Middleware = []Middleware{{BeforeTool: func(_ context.Context, call *ToolCall) error {
		call.Call.Name = "blocked"
		return nil
	}}}
	if _, err := ag.Run(context.Background(), Session{ID: "s"}, "go"); err == nil || impl.args != nil {
		t.Fatalf("allowlist bypass: args=%v err=%v", impl.args, err)
	}
}

func TestOriginalToolDenialStillPrecedesMiddleware(t *testing.T) {
	impl := &recordingTool{}
	ag := interruptAgent(&interruptModel{}, impl, nil)
	ag.Policy = policy.FuncHook(func(_ context.Context, action policy.Action) (policy.Decision, error) {
		return policy.Decision{Allowed: action.Kind != "tool.invoke"}, nil
	})
	ag.Middleware = []Middleware{{BeforeTool: func(context.Context, *ToolCall) error {
		t.Fatal("middleware reached after original tool denial")
		return nil
	}}}
	if _, err := ag.Run(context.Background(), Session{ID: "s"}, "go"); err == nil || impl.args != nil {
		t.Fatalf("original denial ignored: args=%v err=%v", impl.args, err)
	}
}

type authorizationBatchModel struct{ interruptModel }

func (m *authorizationBatchModel) Generate(ctx context.Context, req model.Request) (model.Response, error) {
	response, err := m.interruptModel.Generate(ctx, req)
	if len(response.Message.ToolCalls) != 0 {
		response.Message.ToolCalls = append(response.Message.ToolCalls, model.ToolCall{
			ID: "call-2", Name: "echo", Arguments: map[string]any{"value": "original"},
		})
	}
	return response, err
}

func TestFinalAuthorizationChecksWholeBatchBeforeExecution(t *testing.T) {
	for _, parallel := range []int{1, 2} {
		t.Run(strconv.Itoa(parallel), func(t *testing.T) {
			impl := &recordingTool{}
			ag := interruptAgent(&authorizationBatchModel{}, impl, func(context.Context, Interrupt) (InterruptDecision, error) {
				return InterruptDecision{Action: InterruptApprove}, nil
			})
			ag.MaxParallelTools = parallel
			var firstArgs map[string]any
			ag.Hooks.OnToolCall = func(_ context.Context, _ string, call model.ToolCall) error {
				if firstArgs == nil {
					firstArgs = call.Arguments
				} else {
					firstArgs["value"] = "edited"
				}
				return nil
			}
			ag.Policy = policy.FuncHook(func(_ context.Context, action policy.Action) (policy.Decision, error) {
				return policy.Decision{Allowed: action.Kind != "tool.invoke" || action.Arguments["value"] == "original"}, nil
			})
			if _, err := ag.Run(context.Background(), Session{ID: "s"}, "go"); err == nil || impl.args != nil {
				t.Fatalf("executed batch after another callback mutated authorized arguments: args=%v err=%v", impl.args, err)
			}
		})
	}
}

func TestFinalToolNameReauthorized(t *testing.T) {
	impl := &recordingTool{}
	ag := interruptAgent(&interruptModel{}, impl, func(context.Context, Interrupt) (InterruptDecision, error) {
		return InterruptDecision{Action: InterruptApprove}, nil
	})
	ag.Tools.Register(renamedRecordingTool{recordingTool: impl, name: "blocked"})
	ag.AllowedTools = []string{"echo", "blocked"}
	ag.Middleware = []Middleware{{BeforeTool: func(_ context.Context, call *ToolCall) error {
		call.Call.Name = "blocked"
		return nil
	}}}
	ag.Policy = policy.FuncHook(func(_ context.Context, action policy.Action) (policy.Decision, error) {
		return policy.Decision{Allowed: action.ToolName != "blocked"}, nil
	})
	if _, err := ag.Run(context.Background(), Session{ID: "s"}, "go"); err == nil || impl.args != nil {
		t.Fatalf("changed tool name bypassed policy: args=%v err=%v", impl.args, err)
	}
}

func TestFinalNestedArgumentsReauthorized(t *testing.T) {
	impl := &recordingTool{}
	ag := interruptAgent(&interruptModel{mode: "nested"}, impl, func(context.Context, Interrupt) (InterruptDecision, error) {
		return InterruptDecision{Action: InterruptApprove}, nil
	})
	ag.Hooks.OnToolCall = func(_ context.Context, _ string, call model.ToolCall) error {
		call.Arguments["value"].(map[string]any)["path"] = "blocked"
		return nil
	}
	ag.Policy = policy.FuncHook(func(_ context.Context, action policy.Action) (policy.Decision, error) {
		if value, ok := action.Arguments["value"].(map[string]any); ok {
			return policy.Decision{Allowed: value["path"] != "blocked"}, nil
		}
		return policy.Decision{Allowed: true}, nil
	})
	if _, err := ag.Run(context.Background(), Session{ID: "s"}, "go"); err == nil || impl.args != nil {
		t.Fatalf("nested argument mutation bypassed policy: args=%v err=%v", impl.args, err)
	}
}

func TestFinalInvalidArgumentsFailBeforeExecution(t *testing.T) {
	impl := &recordingTool{}
	ag := interruptAgent(&interruptModel{}, impl, func(context.Context, Interrupt) (InterruptDecision, error) {
		return InterruptDecision{Action: InterruptApprove}, nil
	})
	ag.Policy = allowPolicy{}
	ag.Hooks.OnToolCall = func(_ context.Context, _ string, call model.ToolCall) error {
		call.Arguments["value"] = func() {}
		return nil
	}
	if _, err := ag.Run(context.Background(), Session{ID: "s"}, "go"); err == nil || impl.args != nil {
		t.Fatalf("non-JSON arguments reached tool: args=%v err=%v", impl.args, err)
	}
}
