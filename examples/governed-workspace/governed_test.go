package main

import (
	"context"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"sync/atomic"
	"testing"

	"github.com/axisvela/praxo-core/v2/pkg/agent"
	"github.com/axisvela/praxo-core/v2/pkg/event"
	"github.com/axisvela/praxo-core/v2/pkg/model"
	"github.com/axisvela/praxo-core/v2/pkg/policy"
	"github.com/axisvela/praxo-core/v2/pkg/tool"
	"github.com/axisvela/praxo-core/v2/pkg/vfs/localfs"
	"github.com/axisvela/praxo-core/v2/pkg/vfs/vfstools"
)

func governedFixture(t *testing.T) (agent.Options, agent.Session, *scriptedModel) {
	t.Helper()
	dir := t.TempDir()
	backend, err := localfs.New(dir)
	if err != nil {
		t.Fatal(err)
	}
	registry := tool.NewRegistry()
	for _, item := range vfstools.Tools(backend) {
		registry.Register(item)
	}
	m := &scriptedModel{mode: "write"}
	opts := agent.Options{
		Model: m, Tools: registry, Policy: policy.FuncHook(workspacePolicy),
		AllowedTools: []string{"fs.write"}, InterruptOn: map[string]bool{"fs.write": true},
		OnInterruptDecision: func(context.Context, agent.Interrupt) (agent.InterruptDecision, error) {
			return agent.InterruptDecision{Action: agent.InterruptApprove}, nil
		},
		Events: event.FuncSink(func(context.Context, event.Event) error { return nil }),
	}
	return opts, agent.Session{ID: "governed-test", TenantID: "synthetic", WorkspaceID: dir}, m
}

func assertNoWorkspaceWrite(t *testing.T, session agent.Session) {
	t.Helper()
	entries, err := os.ReadDir(session.WorkspaceID)
	if err != nil || len(entries) != 0 {
		t.Fatalf("unexpected workspace effects: entries=%v err=%v", entries, err)
	}
}

func TestGovernedWorkspaceRejectsMissingConfiguration(t *testing.T) {
	for _, name := range []string{"policy", "scope", "events", "registry", "unregistered", "unknown", "approval-gate", "approval-handler", "tool-retry", "typed-nil-policy", "typed-nil-events", "typed-nil-model"} {
		t.Run(name, func(t *testing.T) {
			opts, session, m := governedFixture(t)
			switch name {
			case "policy":
				opts.Policy = nil
			case "scope":
				opts.AllowedTools = nil
			case "events":
				opts.Events = nil
			case "registry":
				opts.Tools = nil
			case "unregistered":
				opts.Tools = tool.NewRegistry()
			case "unknown":
				opts.AllowedTools = []string{"shell.exec"}
			case "approval-gate":
				opts.InterruptOn = nil
			case "approval-handler":
				opts.OnInterruptDecision = nil
			case "tool-retry":
				opts.ToolRetry = &tool.RetryPolicy{}
			case "typed-nil-policy":
				opts.Policy = policy.FuncHook(nil)
			case "typed-nil-events":
				opts.Events = event.FuncSink(nil)
			case "typed-nil-model":
				opts.Model = (*scriptedModel)(nil)
			}
			_, err := runGovernedWorkspace(context.Background(), opts, session, "write")
			if err == nil || m.calls != 0 {
				t.Fatalf("configuration admitted: model calls=%d err=%v", m.calls, err)
			}
			assertNoWorkspaceWrite(t, session)
		})
	}
}

func TestGovernedWorkspaceDependencyFailures(t *testing.T) {
	for _, name := range []string{"model-policy", "tool-policy", "execution-policy", "approval", "event"} {
		t.Run(name, func(t *testing.T) {
			opts, session, _ := governedFixture(t)
			failure := errors.New("synthetic dependency failure")
			toolChecks := 0
			opts.Policy = policy.FuncHook(func(_ context.Context, action policy.Action) (policy.Decision, error) {
				if action.Kind == "tool.invoke" {
					toolChecks++
				}
				if (name == "model-policy" && action.Kind == "model.generate") ||
					(name == "tool-policy" && toolChecks == 1) ||
					(name == "execution-policy" && toolChecks == 2) {
					return policy.Decision{}, failure
				}
				return policy.Decision{Allowed: true}, nil
			})
			if name == "approval" {
				opts.OnInterruptDecision = func(context.Context, agent.Interrupt) (agent.InterruptDecision, error) {
					return agent.InterruptDecision{}, failure
				}
			}
			completed := false
			opts.Events = event.FuncSink(func(_ context.Context, ev event.Event) error {
				completed = completed || ev.Type == "run.completed"
				if name == "event" && ev.Type == "tool.call" {
					return failure
				}
				return nil
			})
			_, err := runGovernedWorkspace(context.Background(), opts, session, "write")
			if !errors.Is(err, failure) || completed {
				t.Fatalf("dependency failure lost: completed=%v err=%v", completed, err)
			}
			assertNoWorkspaceWrite(t, session)
		})
	}
}

func TestGovernedWorkspaceRejectsChangesAfterApproval(t *testing.T) {
	for _, phase := range []string{"hook", "event", "stream", "masked-error"} {
		t.Run(phase, func(t *testing.T) {
			opts, session, _ := governedFixture(t)
			opts.Hooks.OnToolCall = func(_ context.Context, _ string, call model.ToolCall) error {
				if phase == "hook" || phase == "masked-error" {
					call.Arguments["content"] = "not approved"
				}
				return nil
			}
			if phase == "masked-error" {
				opts.Middleware = []agent.Middleware{{AfterTool: func(_ context.Context, _ *agent.ToolCall, result *agent.ToolResult) error {
					result.Err = nil
					return nil
				}}}
			}
			completed := false
			opts.Events = event.FuncSink(func(_ context.Context, ev event.Event) error {
				completed = completed || ev.Type == "run.completed"
				if phase == "event" && ev.Type == "tool.call" {
					ev.Data["arguments"].(map[string]any)["content"] = "not approved"
				}
				return nil
			})
			opts.OnStream = func(part agent.StreamPart) error {
				if phase == "stream" && part.Kind == agent.StreamTasks {
					data := part.Data.(map[string]any)
					if data["status"] == "start" {
						data["arguments"].(map[string]any)["content"] = "not approved"
					}
				}
				return nil
			}
			_, err := runGovernedWorkspace(context.Background(), opts, session, "write")
			if err == nil || !strings.Contains(err.Error(), "approval") || completed {
				t.Fatalf("changed operation admitted: completed=%v err=%v", completed, err)
			}
			assertNoWorkspaceWrite(t, session)
		})
	}
}

type workspaceModelFunc func(context.Context, model.Request) (model.Response, error)

func (f workspaceModelFunc) Generate(ctx context.Context, req model.Request) (model.Response, error) {
	return f(ctx, req)
}

func workspaceBatchModel() model.Model {
	first := true
	return workspaceModelFunc(func(context.Context, model.Request) (model.Response, error) {
		if !first {
			return model.Response{Message: model.Message{Content: "done"}}, nil
		}
		first = false
		return model.Response{Message: model.Message{ToolCalls: []model.ToolCall{
			{ID: "one", Name: "fs.write", Arguments: map[string]any{"path": "one.txt", "content": "one"}},
			{ID: "two", Name: "fs.write", Arguments: map[string]any{"path": "two.txt", "content": "two"}},
		}}}, nil
	})
}

func TestGovernedWorkspaceConsumesEachApprovalOnce(t *testing.T) {
	for _, parallel := range []int{1, 2} {
		t.Run(fmt.Sprint(parallel), func(t *testing.T) {
			opts, session, _ := governedFixture(t)
			opts.MaxParallelTools = parallel
			opts.Model = workspaceBatchModel()
			opts.Hooks.OnToolCall = func(_ context.Context, _ string, call model.ToolCall) error {
				if call.ID == "two" {
					call.Arguments["path"] = "one.txt"
					call.Arguments["content"] = "one"
				}
				return nil
			}
			var invocations atomic.Int32
			underlying, err := opts.Tools.Get("fs.write")
			if err != nil {
				t.Fatal(err)
			}
			opts.Tools.Register(workspaceTool{Tool: underlying, invoke: func(ctx context.Context, args map[string]any) (any, error) {
				invocations.Add(1)
				return underlying.Invoke(ctx, args)
			}})
			_, err = runGovernedWorkspace(context.Background(), opts, session, "write twice")
			if !errors.Is(err, errWorkspaceGuard) || invocations.Load() != 1 {
				t.Fatalf("approval reused: invocations=%d err=%v", invocations.Load(), err)
			}
			if _, err := os.Stat(filepath.Join(session.WorkspaceID, "two.txt")); !os.IsNotExist(err) {
				t.Fatalf("unapproved second file: %v", err)
			}
		})
	}
}

func TestGovernedWorkspaceRechecksQueuedAuthorization(t *testing.T) {
	opts, session, _ := governedFixture(t)
	opts.MaxParallelTools = 1
	opts.Model = workspaceBatchModel()
	var revoked atomic.Bool
	opts.Policy = policy.FuncHook(func(_ context.Context, action policy.Action) (policy.Decision, error) {
		return policy.Decision{Allowed: action.Kind != "tool.invoke" || !revoked.Load()}, nil
	})
	underlying, err := opts.Tools.Get("fs.write")
	if err != nil {
		t.Fatal(err)
	}
	opts.Tools.Register(workspaceTool{Tool: underlying, invoke: func(ctx context.Context, args map[string]any) (any, error) {
		result, err := underlying.Invoke(ctx, args)
		revoked.Store(true)
		return result, err
	}})
	_, err = runGovernedWorkspace(context.Background(), opts, session, "write twice")
	if !errors.Is(err, errWorkspaceGuard) {
		t.Fatalf("revocation ignored: %v", err)
	}
	data, readErr := os.ReadFile(filepath.Join(session.WorkspaceID, "one.txt"))
	if readErr != nil || string(data) != "one" {
		t.Fatalf("first committed effect lost: data=%q err=%v", data, readErr)
	}
	if _, err := os.Stat(filepath.Join(session.WorkspaceID, "two.txt")); !os.IsNotExist(err) {
		t.Fatalf("revoked operation executed: %v", err)
	}
}

func TestGovernedWorkspaceBindsApprovedEdits(t *testing.T) {
	for _, phase := range []string{"unchanged", "before-tool", "approval-edit"} {
		t.Run(phase, func(t *testing.T) {
			opts, session, _ := governedFixture(t)
			want := "approved by demo\n"
			if phase == "before-tool" {
				want = "before approval"
				opts.Middleware = []agent.Middleware{{BeforeTool: func(_ context.Context, call *agent.ToolCall) error {
					call.Call.Arguments["content"] = want
					return nil
				}}}
			}
			if phase == "approval-edit" {
				want = "explicitly approved edit"
				opts.OnInterruptDecision = func(context.Context, agent.Interrupt) (agent.InterruptDecision, error) {
					return agent.InterruptDecision{Action: agent.InterruptEdit, Arguments: map[string]any{"path": "notes.md", "content": want}}, nil
				}
			}
			_, err := runGovernedWorkspace(context.Background(), opts, session, "write")
			if err != nil {
				t.Fatal(err)
			}
			data, err := os.ReadFile(filepath.Join(session.WorkspaceID, "notes.md"))
			if err != nil || string(data) != want {
				t.Fatalf("effect does not match approval: data=%q err=%v", data, err)
			}
		})
	}
}

func TestGovernedWorkspaceChecksPolicyAtInvocation(t *testing.T) {
	for _, outcome := range []string{"deny", "cancel", "mutate"} {
		t.Run(outcome, func(t *testing.T) {
			opts, session, _ := governedFixture(t)
			ctx, cancel := context.WithCancel(context.Background())
			defer cancel()
			checks := 0
			opts.Policy = policy.FuncHook(func(_ context.Context, action policy.Action) (policy.Decision, error) {
				if action.Kind == "tool.invoke" {
					checks++
					if checks == 2 {
						switch outcome {
						case "deny":
							return policy.Decision{}, nil
						case "cancel":
							cancel()
						case "mutate":
							action.Arguments["content"] = "changed by policy"
						}
					}
				}
				return policy.Decision{Allowed: true}, nil
			})
			_, err := runGovernedWorkspace(ctx, opts, session, "write")
			if !errors.Is(err, errWorkspaceGuard) || (outcome == "cancel" && !errors.Is(err, context.Canceled)) {
				t.Fatalf("execution-boundary control bypassed: %v", err)
			}
			assertNoWorkspaceWrite(t, session)
		})
	}
}

func TestGovernedWorkspaceStopsQueuedWritesAfterGuardFailure(t *testing.T) {
	opts, session, _ := governedFixture(t)
	opts.Model = workspaceBatchModel()
	opts.MaxParallelTools = 1
	opts.Hooks.OnToolCall = func(_ context.Context, _ string, call model.ToolCall) error {
		if call.ID == "one" {
			call.Arguments["content"] = "unapproved first operation"
		}
		return nil
	}
	_, err := runGovernedWorkspace(context.Background(), opts, session, "write twice")
	if !errors.Is(err, errWorkspaceGuard) {
		t.Fatalf("first rejection was not propagated: %v", err)
	}
	assertNoWorkspaceWrite(t, session)
}

func TestGovernedWorkspaceApprovalStateIsPerRun(t *testing.T) {
	opts, session, _ := governedFixture(t)
	_, err := runGovernedWorkspace(context.Background(), opts, session, "write")
	if err != nil {
		t.Fatal(err)
	}
	opts.Model = &scriptedModel{mode: "write"}
	opts.OnInterruptDecision = func(context.Context, agent.Interrupt) (agent.InterruptDecision, error) {
		return agent.InterruptDecision{Action: agent.InterruptReject}, nil
	}
	_, err = runGovernedWorkspace(context.Background(), opts, session, "write again")
	if !errors.Is(err, agent.ErrApprovalDenied) {
		t.Fatalf("prior approval reused: %v", err)
	}
	data, err := os.ReadFile(filepath.Join(session.WorkspaceID, "notes.md"))
	if err != nil || string(data) != "approved by demo\n" {
		t.Fatalf("prior effect changed: data=%q err=%v", data, err)
	}
}

func TestGovernedWorkspacePreservesScopedSchemas(t *testing.T) {
	opts, session, _ := governedFixture(t)
	registered, err := opts.Tools.Get("fs.write")
	if err != nil {
		t.Fatal(err)
	}
	want := []model.ToolSpec{registered.(tool.SpecProvider).Spec()}
	opts.Model = workspaceModelFunc(func(_ context.Context, req model.Request) (model.Response, error) {
		if !reflect.DeepEqual(req.Tools, want) {
			t.Fatalf("scoped schemas changed: tools=%v want=%v", req.Tools, want)
		}
		return model.Response{Message: model.Message{Content: "no operation"}}, nil
	})
	if _, err := runGovernedWorkspace(context.Background(), opts, session, "inspect tools"); err != nil {
		t.Fatal(err)
	}
	assertNoWorkspaceWrite(t, session)
}
