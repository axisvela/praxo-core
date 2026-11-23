package main

import (
	"context"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"

	"github.com/axisvela/praxo-core/v2/pkg/agent"
	"github.com/axisvela/praxo-core/v2/pkg/model"
	"github.com/axisvela/praxo-core/v2/pkg/policy"
	"github.com/axisvela/praxo-core/v2/pkg/tool"
	"github.com/axisvela/praxo-core/v2/pkg/vfs/localfs"
)

const evidencePath = "evidence-100.txt"

var errEvidenceUnavailable = errors.New("EVIDENCE_UNAVAILABLE")

const fixtureEvidence = "case-100 incident timeline\ncritical: unauthorized access on edge-web-01\nreview: isolate host and preserve logs\n"

type readEvidenceTool struct {
	backend         *localfs.Backend
	simulateFailure bool
	calls           int
}

func (readEvidenceTool) Name() string { return "read_evidence" }

func (readEvidenceTool) Description() string {
	return "Read one evidence file from the confined vault backend."
}

func (readEvidenceTool) Spec() model.ToolSpec {
	return model.ToolSpec{
		Name:        "read_evidence",
		Description: "Read one evidence file from the confined vault backend.",
		Parameters: map[string]any{
			"type":       "object",
			"properties": map[string]any{"path": map[string]any{"type": "string"}},
		},
	}
}

func (t *readEvidenceTool) Invoke(ctx context.Context, args map[string]any) (any, error) {
	t.calls++
	if t.simulateFailure {
		return nil, errEvidenceUnavailable
	}
	path, _ := args["path"].(string)
	if path == "" {
		path = evidencePath
	}
	data, err := t.backend.Read(ctx, path)
	if err != nil {
		return nil, err
	}
	text := string(data)
	severity := "low"
	if strings.Contains(text, "critical") {
		severity = "critical"
	}
	return map[string]any{
		"path":     path,
		"lines":    strings.Count(strings.TrimRight(text, "\n"), "\n") + 1,
		"severity": severity,
		"source":   "vault_fixture",
	}, nil
}

type draftFindingTool struct{ calls *int }

func (draftFindingTool) Name() string { return "draft_finding" }

func (draftFindingTool) Description() string {
	return "Draft a review-only finding without a case-system write."
}

func (draftFindingTool) Spec() model.ToolSpec {
	return model.ToolSpec{
		Name:        "draft_finding",
		Description: "Draft a review-only finding without a case-system write.",
		Parameters: map[string]any{
			"type": "object",
			"properties": map[string]any{
				"evidence_path": map[string]any{"type": "string"},
				"action":        map[string]any{"type": "string"},
			},
		},
	}
}

func (t draftFindingTool) Invoke(_ context.Context, args map[string]any) (any, error) {
	*t.calls++
	path, _ := args["evidence_path"].(string)
	action, _ := args["action"].(string)
	if action == "" {
		action = "open_review"
	}
	return map[string]any{
		"finding_id":      "finding-100",
		"evidence_path":   path,
		"action":          action,
		"status":          "draft_only",
		"review_required": true,
		"case_writes":     0,
	}, nil
}

type fixtureModel struct{ path string }

func toolMessages(messages []model.Message) []model.Message {
	var out []model.Message
	for _, message := range messages {
		if message.Role == model.RoleTool {
			out = append(out, message)
		}
	}
	return out
}

func (m *fixtureModel) Generate(_ context.Context, req model.Request) (model.Response, error) {
	tools := toolMessages(req.Messages)
	switch len(tools) {
	case 0:
		return model.Response{Message: model.Message{
			Role: model.RoleAssistant,
			ToolCalls: []model.ToolCall{{
				ID:        "read-1",
				Name:      "read_evidence",
				Arguments: map[string]any{"path": m.path},
			}},
		}}, nil
	case 1:
		return model.Response{Message: model.Message{
			Role: model.RoleAssistant,
			ToolCalls: []model.ToolCall{{
				ID:   "finding-1",
				Name: "draft_finding",
				Arguments: map[string]any{
					"evidence_path": m.path,
					"action":        "open_review",
				},
			}},
		}}, nil
	default:
		var evidence any
		var finding any
		_ = json.Unmarshal([]byte(tools[0].Content), &evidence)
		_ = json.Unmarshal([]byte(tools[1].Content), &finding)
		report := map[string]any{
			"stage":       "finding_drafted",
			"evidence":    evidence,
			"finding":     finding,
			"case_writes": 0,
		}
		raw, err := json.Marshal(report)
		if err != nil {
			return model.Response{}, err
		}
		return model.Response{Message: model.Message{Role: model.RoleAssistant, Content: string(raw)}}, nil
	}
}

func authorize(_ context.Context, action policy.Action) (policy.Decision, error) {
	if action.Kind == "model.generate" {
		return policy.Decision{Allowed: true, Reason: "deterministic evidence review"}, nil
	}
	if action.Kind != "tool.invoke" {
		return policy.Decision{Allowed: false, Reason: "unsupported action"}, nil
	}
	switch action.ToolName {
	case "read_evidence":
		path, _ := action.Arguments["path"].(string)
		allowed := path == evidencePath
		return policy.Decision{Allowed: allowed, Reason: "only the allowlisted evidence file is readable"}, nil
	case "draft_finding":
		path, _ := action.Arguments["evidence_path"].(string)
		act, _ := action.Arguments["action"].(string)
		allowed := path == evidencePath && act == "open_review"
		return policy.Decision{Allowed: allowed, Reason: "only an evidence-100 open_review draft is allowed"}, nil
	}
	return policy.Decision{Allowed: false, Reason: "unknown tool"}, nil
}

func setupVault() (string, func(), error) {
	parent, err := os.MkdirTemp("", "praxo-evidence-")
	if err != nil {
		return "", nil, err
	}
	cleanup := func() { _ = os.RemoveAll(parent) }
	vault := filepath.Join(parent, "vault")
	if err := os.MkdirAll(vault, 0o700); err != nil {
		cleanup()
		return "", nil, err
	}
	if err := os.WriteFile(filepath.Join(vault, evidencePath), []byte(fixtureEvidence), 0o600); err != nil {
		cleanup()
		return "", nil, err
	}
	if err := os.WriteFile(filepath.Join(parent, "secret.txt"), []byte("TOP SECRET"), 0o600); err != nil {
		cleanup()
		return "", nil, err
	}
	return vault, cleanup, nil
}

type outcome struct {
	output string
	err    error
	reads  int
	drafts int
}

func runScenario(ctx context.Context, path string, simulateFailure bool) (outcome, *localfs.Backend, func()) {
	vault, cleanup, err := setupVault()
	if err != nil {
		return outcome{err: err}, nil, func() {}
	}
	backend, err := localfs.New(vault)
	if err != nil {
		cleanup()
		return outcome{err: err}, nil, func() {}
	}

	read := &readEvidenceTool{backend: backend, simulateFailure: simulateFailure}
	drafts := 0
	tools := tool.NewRegistry()
	tools.Register(read)
	tools.Register(draftFindingTool{calls: &drafts})

	ag, err := agent.New(agent.Options{
		Model:            &fixtureModel{path: path},
		Tools:            tools,
		MaxSteps:         5,
		AllowedTools:     []string{"read_evidence", "draft_finding"},
		RequirePolicy:    true,
		RequireToolScope: true,
		Policy:           policy.FuncHook(authorize),
	})
	if err != nil {
		cleanup()
		return outcome{err: err, reads: read.calls, drafts: drafts}, backend, func() {}
	}
	result, runErr := ag.Run(ctx, agent.Session{
		ID:          "go-evidence-vault",
		TenantID:    "local",
		WorkspaceID: "default",
	}, "Review the fixed evidence file and draft a finding.")
	got := outcome{reads: read.calls, drafts: drafts}
	if runErr != nil {
		got.err = runErr
		return got, backend, cleanup
	}
	got.output = result.Output
	return got, backend, cleanup
}

func runTests(ctx context.Context, stdout io.Writer) error {
	success, backend, cleanup := runScenario(ctx, evidencePath, false)
	if success.err != nil {
		cleanup()
		return fmt.Errorf("success path failed: %w", success.err)
	}
	if success.reads != 1 || success.drafts != 1 {
		cleanup()
		return fmt.Errorf("success verification failed: reads=%d drafts=%d", success.reads, success.drafts)
	}
	var report map[string]any
	if err := json.Unmarshal([]byte(success.output), &report); err != nil {
		cleanup()
		return fmt.Errorf("success output is not JSON: %w", err)
	}
	finding, _ := report["finding"].(map[string]any)
	evidence, _ := report["evidence"].(map[string]any)
	if finding["status"] != "draft_only" || finding["case_writes"] != float64(0) ||
		evidence["severity"] != "critical" || report["case_writes"] != float64(0) {
		cleanup()
		return fmt.Errorf("success verification failed: %s", success.output)
	}

	if _, err := backend.Read(ctx, "../secret.txt"); err == nil {
		cleanup()
		return fmt.Errorf("vault leaked a file outside its root")
	}
	if _, err := backend.Read(ctx, filepath.Join(string(filepath.Separator), "etc", "passwd")); err == nil {
		cleanup()
		return fmt.Errorf("vault accepted an absolute path")
	}
	cleanup()
	fmt.Fprintln(stdout, "success: evidence-100 severity=critical action=open_review status=draft_only writes=0 reads=1")
	fmt.Fprintln(stdout, "containment: traversal and absolute paths rejected")

	denied, _, cleanup := runScenario(ctx, "../secret.txt", false)
	if denied.err == nil || denied.reads != 0 {
		cleanup()
		return fmt.Errorf("deny verification failed: reads=%d err=%v", denied.reads, denied.err)
	}
	cleanup()
	fmt.Fprintln(stdout, "deny: policy denied reads=0")

	failure, _, cleanup := runScenario(ctx, evidencePath, true)
	if !errors.Is(failure.err, errEvidenceUnavailable) || failure.reads != 1 {
		cleanup()
		return fmt.Errorf("failure verification failed: reads=%d err=%v", failure.reads, failure.err)
	}
	cleanup()
	fmt.Fprintln(stdout, "failure: EVIDENCE_UNAVAILABLE reads=1")
	return nil
}

func main() {
	testMode := flag.Bool("test", false, "run the deterministic tutorial checks")
	path := flag.String("path", evidencePath, "virtual evidence path to read")
	simulateFailure := flag.Bool("simulate-failure", false, "make the evidence backend fail")
	flag.Parse()

	ctx := context.Background()
	if *testMode {
		if err := runTests(ctx, os.Stdout); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		return
	}

	got, _, cleanup := runScenario(ctx, *path, *simulateFailure)
	defer cleanup()
	if got.err != nil {
		fmt.Fprintf(os.Stderr, "error: %v reads=%d\n", got.err, got.reads)
		os.Exit(1)
	}
	fmt.Fprintln(os.Stdout, got.output)
	fmt.Fprintf(os.Stdout, "reads=%d\n", got.reads)
}
