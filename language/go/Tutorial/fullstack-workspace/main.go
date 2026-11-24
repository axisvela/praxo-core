package main

import (
	"context"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"strings"

	"github.com/axisvela/praxo-core/v2/pkg/agent"
	"github.com/axisvela/praxo-core/v2/pkg/model"
	"github.com/axisvela/praxo-core/v2/pkg/policy"
	"github.com/axisvela/praxo-core/v2/pkg/tool"
)

const workspaceID = "workspace-100"

var errWorkspaceUnavailable = errors.New("WORKSPACE_UNAVAILABLE")

type fixtureWorkspace struct {
	simulateFailure bool
	reads           int
	files           map[string]string
}

func newFixtureWorkspace(simulateFailure bool) *fixtureWorkspace {
	return &fixtureWorkspace{
		simulateFailure: simulateFailure,
		files: map[string]string{
			"app.go":       "package main\n",
			"main_test.go": "package main\n",
		},
	}
}

func (s *fixtureWorkspace) Read(_ context.Context, workspace string) (map[string]any, error) {
	s.reads++
	if s.simulateFailure {
		return nil, errWorkspaceUnavailable
	}
	return map[string]any{
		"workspace_id": workspace,
		"empty":        true,
		"files":        []any{"app.go", "main_test.go"},
		"allowlist":    []any{"app.go"},
		"source":       "workspace_fixture",
	}, nil
}

func (s *fixtureWorkspace) Apply(workspace, file, action string) map[string]any {
	s.files[file] = "package main\n\nfunc main() {}\n"
	return map[string]any{
		"edit_id":       "edit-100",
		"workspace":     workspace,
		"file":          file,
		"action":        action,
		"changed":       1,
		"written_bytes": len(s.files[file]),
		"status":        "applied_fixture",
		"deployments":   0,
	}
}

func (s *fixtureWorkspace) Diagnostics(workspace, action string) map[string]any {
	source := s.files["app.go"]
	diagnostics := 0
	buildStatus := "ok_fixture"
	if !strings.Contains(source, "package main") || !strings.Contains(source, "func main()") {
		diagnostics = 1
		buildStatus = "missing_entrypoint"
	}
	return map[string]any{
		"diagnostics_id": "diagnostics-100",
		"workspace":      workspace,
		"action":         action,
		"diagnostics":    diagnostics,
		"build_status":   buildStatus,
		"deployments":    0,
	}
}

type readWorkspaceTool struct{ source *fixtureWorkspace }

func (readWorkspaceTool) Name() string { return "read_workspace" }

func (readWorkspaceTool) Description() string {
	return "Read a fixed allowlisted workspace; no host filesystem access."
}

func (readWorkspaceTool) Spec() model.ToolSpec {
	return model.ToolSpec{
		Name:        "read_workspace",
		Description: "Read a fixed allowlisted workspace.",
		Parameters: map[string]any{
			"type":       "object",
			"properties": map[string]any{"workspace": map[string]any{"type": "string"}},
		},
	}
}

func (t readWorkspaceTool) Invoke(ctx context.Context, args map[string]any) (any, error) {
	id, _ := args["workspace"].(string)
	if id == "" {
		id = workspaceID
	}
	return t.source.Read(ctx, id)
}

type applyEditTool struct {
	workspace *fixtureWorkspace
	calls     *int
}

func (applyEditTool) Name() string { return "apply_edit" }

func (applyEditTool) Description() string {
	return "Apply one bounded edit to an allowlisted fixture file; no deployment."
}

func (applyEditTool) Spec() model.ToolSpec {
	return model.ToolSpec{
		Name:        "apply_edit",
		Description: "Apply one bounded edit to an allowlisted fixture file.",
		Parameters: map[string]any{
			"type": "object",
			"properties": map[string]any{
				"workspace": map[string]any{"type": "string"},
				"file":      map[string]any{"type": "string"},
				"action":    map[string]any{"type": "string"},
			},
		},
	}
}

func (t applyEditTool) Invoke(_ context.Context, args map[string]any) (any, error) {
	*t.calls++
	workspace, _ := args["workspace"].(string)
	if workspace == "" {
		workspace = workspaceID
	}
	file, _ := args["file"].(string)
	if file == "" {
		file = "app.go"
	}
	action, _ := args["action"].(string)
	if action == "" {
		action = "apply_edit_bounded"
	}
	return t.workspace.Apply(workspace, file, action), nil
}

type inspectDiagnosticsTool struct {
	workspace *fixtureWorkspace
	calls     *int
}

func (inspectDiagnosticsTool) Name() string { return "inspect_diagnostics" }

func (inspectDiagnosticsTool) Description() string {
	return "Inspect fixed synthetic build diagnostics; no real compiler or deployment."
}

func (inspectDiagnosticsTool) Spec() model.ToolSpec {
	return model.ToolSpec{
		Name:        "inspect_diagnostics",
		Description: "Inspect fixed synthetic build diagnostics.",
		Parameters: map[string]any{
			"type": "object",
			"properties": map[string]any{
				"workspace": map[string]any{"type": "string"},
				"action":    map[string]any{"type": "string"},
			},
		},
	}
}

func (t inspectDiagnosticsTool) Invoke(_ context.Context, args map[string]any) (any, error) {
	*t.calls++
	workspace, _ := args["workspace"].(string)
	if workspace == "" {
		workspace = workspaceID
	}
	action, _ := args["action"].(string)
	if action == "" {
		action = "inspect"
	}
	return t.workspace.Diagnostics(workspace, action), nil
}

type fixtureModel struct{ workspace string }

func (m *fixtureModel) Generate(_ context.Context, req model.Request) (model.Response, error) {
	var toolMessages []model.Message
	for _, message := range req.Messages {
		if message.Role == model.RoleTool {
			toolMessages = append(toolMessages, message)
		}
	}
	call := func(id, name string, arguments map[string]any) model.Response {
		return model.Response{Message: model.Message{
			Role:      model.RoleAssistant,
			ToolCalls: []model.ToolCall{{ID: id, Name: name, Arguments: arguments}},
		}}
	}
	switch len(toolMessages) {
	case 0:
		return call("read-1", "read_workspace", map[string]any{"workspace": m.workspace}), nil
	case 1:
		return call("edit-1", "apply_edit", map[string]any{
			"workspace": m.workspace,
			"file":      "app.go",
			"action":    "apply_edit_bounded",
		}), nil
	case 2:
		return call("inspect-1", "inspect_diagnostics", map[string]any{
			"workspace": m.workspace,
			"action":    "inspect",
		}), nil
	default:
		var workspace any
		var edit any
		var diagnostics any
		_ = json.Unmarshal([]byte(toolMessages[0].Content), &workspace)
		_ = json.Unmarshal([]byte(toolMessages[1].Content), &edit)
		_ = json.Unmarshal([]byte(toolMessages[2].Content), &diagnostics)
		report := map[string]any{
			"workspace":   workspace,
			"edit":        edit,
			"diagnostics": diagnostics,
			"policy":      "bounded edit and fixture diagnostics only; deployment remains application-owned",
			"deployments": 0,
		}
		raw, err := json.Marshal(report)
		if err != nil {
			return model.Response{}, err
		}
		return model.Response{Message: model.Message{Role: model.RoleAssistant, Content: string(raw)}}, nil
	}
}

type outcome struct {
	output      string
	err         error
	reads       int
	edits       int
	diagnostics int
}

func runScenario(ctx context.Context, workspace string, simulateFailure bool) outcome {
	source := newFixtureWorkspace(simulateFailure)
	editCalls := 0
	diagnosticCalls := 0

	tools := tool.NewRegistry()
	tools.Register(readWorkspaceTool{source: source})
	tools.Register(applyEditTool{workspace: source, calls: &editCalls})
	tools.Register(inspectDiagnosticsTool{workspace: source, calls: &diagnosticCalls})

	ag, err := agent.New(agent.Options{
		Model:            &fixtureModel{workspace: workspace},
		SystemPrompt:     "You plan and edit one allowlisted fixture workspace. No deployment.",
		Tools:            tools,
		MaxSteps:         6,
		AllowedTools:     []string{"read_workspace", "apply_edit", "inspect_diagnostics"},
		RequirePolicy:    true,
		RequireToolScope: true,
		Policy: policy.FuncHook(func(_ context.Context, action policy.Action) (policy.Decision, error) {
			if action.Kind == "model.generate" {
				return policy.Decision{Allowed: true, Reason: "deterministic workspace plan"}, nil
			}
			if action.Kind != "tool.invoke" {
				return policy.Decision{Allowed: false, Reason: "unsupported action"}, nil
			}
			inScope, _ := action.Arguments["workspace"].(string)
			allowed := inScope == workspaceID
			switch action.ToolName {
			case "read_workspace":
				return policy.Decision{Allowed: allowed, Reason: "only workspace-100 is in scope"}, nil
			case "apply_edit":
				file, _ := action.Arguments["file"].(string)
				act, _ := action.Arguments["action"].(string)
				return policy.Decision{Allowed: allowed && file == "app.go" && act == "apply_edit_bounded", Reason: "only an allowlisted app.go bounded edit is allowed"}, nil
			case "inspect_diagnostics":
				act, _ := action.Arguments["action"].(string)
				return policy.Decision{Allowed: allowed && act == "inspect", Reason: "only fixture diagnostics are allowed"}, nil
			}
			return policy.Decision{Allowed: false, Reason: "unknown tool"}, nil
		}),
	})
	if err != nil {
		return outcome{err: err, reads: source.reads, edits: editCalls, diagnostics: diagnosticCalls}
	}

	result, runErr := ag.Run(ctx, agent.Session{
		ID:          "go-fullstack-workspace",
		TenantID:    "local",
		WorkspaceID: "default",
	}, "Plan, edit and inspect the fixed workspace without deploying.")
	got := outcome{reads: source.reads, edits: editCalls, diagnostics: diagnosticCalls}
	if runErr != nil {
		got.err = runErr
		return got
	}
	got.output = result.Output
	return got
}

func runTests(ctx context.Context, stdout io.Writer) error {
	success := runScenario(ctx, workspaceID, false)
	if success.err != nil {
		return fmt.Errorf("success path failed: %w", success.err)
	}
	if success.reads != 1 || success.edits != 1 || success.diagnostics != 1 {
		return fmt.Errorf("success verification failed: reads=%d edits=%d diagnostics=%d", success.reads, success.edits, success.diagnostics)
	}
	var report map[string]any
	if err := json.Unmarshal([]byte(success.output), &report); err != nil {
		return fmt.Errorf("success output is not JSON: %w", err)
	}
	edit, _ := report["edit"].(map[string]any)
	diagnostics, _ := report["diagnostics"].(map[string]any)
	if edit["status"] != "applied_fixture" || edit["changed"] != float64(1) ||
		edit["written_bytes"] != float64(len("package main\n\nfunc main() {}\n")) ||
		diagnostics["build_status"] != "ok_fixture" || diagnostics["diagnostics"] != float64(0) ||
		report["deployments"] != float64(0) {
		return fmt.Errorf("success verification failed: edit=%v diagnostics=%v", edit, diagnostics)
	}
	fmt.Fprintln(stdout, "success: workspace-100 files=2 edited=1 diagnostics=0 status=applied_fixture deployments=0 reads=1")

	denied := runScenario(ctx, "workspace-200", false)
	if denied.err == nil || denied.reads != 0 || denied.edits != 0 {
		return fmt.Errorf("deny verification failed: reads=%d edits=%d err=%v", denied.reads, denied.edits, denied.err)
	}
	fmt.Fprintln(stdout, "deny: policy denied reads=0")

	failure := runScenario(ctx, workspaceID, true)
	if !errors.Is(failure.err, errWorkspaceUnavailable) || failure.reads != 1 || failure.edits != 0 {
		return fmt.Errorf("failure verification failed: reads=%d err=%v", failure.reads, failure.err)
	}
	fmt.Fprintln(stdout, "failure: WORKSPACE_UNAVAILABLE reads=1")
	return nil
}

func main() {
	testMode := flag.Bool("test", false, "run the deterministic tutorial checks")
	workspace := flag.String("workspace", workspaceID, "allowlisted workspace id")
	simulateFailure := flag.Bool("simulate-failure", false, "make the workspace source fail")
	flag.Parse()

	ctx := context.Background()
	if *testMode {
		if err := runTests(ctx, os.Stdout); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		return
	}

	got := runScenario(ctx, *workspace, *simulateFailure)
	if got.err != nil {
		fmt.Fprintf(os.Stderr, "error: %v reads=%d\n", got.err, got.reads)
		os.Exit(1)
	}
	fmt.Fprintln(os.Stdout, got.output)
	fmt.Fprintf(os.Stdout, "reads=%d\n", got.reads)
}
