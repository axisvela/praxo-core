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

const tenantID = "tenant-100"

var errAuditUnavailable = errors.New("TENANT_AUDIT_UNAVAILABLE")

type AuditSource interface {
	Events(ctx context.Context, tenant string) ([]map[string]any, error)
}

type fixtureSource struct {
	simulateFailure bool
	reads           int
}

func (s *fixtureSource) Events(_ context.Context, tenant string) ([]map[string]any, error) {
	s.reads++
	if s.simulateFailure {
		return nil, errAuditUnavailable
	}
	return []map[string]any{
		{"principal": "svc-a", "resource": "orders/read", "granted": "write", "used": "read", "verdict": "overgranted"},
		{"principal": "svc-b", "resource": "billing/read", "granted": "admin", "used": "read", "verdict": "overgranted"},
		{"principal": "svc-c", "resource": "orders/read", "granted": "read", "used": "read", "verdict": "aligned"},
	}, nil
}

type readEventsTool struct{ source AuditSource }

func (readEventsTool) Name() string { return "read_access_events" }

func (readEventsTool) Description() string {
	return "Read fixed access events and compute over-granted permissions."
}

func (readEventsTool) Spec() model.ToolSpec {
	return model.ToolSpec{
		Name:        "read_access_events",
		Description: "Read fixed access events and compute over-granted permissions.",
		Parameters: map[string]any{
			"type":       "object",
			"properties": map[string]any{"tenant": map[string]any{"type": "string"}},
		},
	}
}

func (t readEventsTool) Invoke(ctx context.Context, args map[string]any) (any, error) {
	tenant, _ := args["tenant"].(string)
	if tenant == "" {
		tenant = tenantID
	}
	events, err := t.source.Events(ctx, tenant)
	if err != nil {
		return nil, err
	}
	recommended := []map[string]any{
		{"principal": "svc-a", "from": "write", "to": "read"},
		{"principal": "svc-b", "from": "admin", "to": "read"},
	}
	return map[string]any{
		"tenant":      tenantID,
		"events":      events,
		"overgranted": 2,
		"recommended": recommended,
		"source":      "access_fixture",
	}, nil
}

type draftChangeTool struct{ drafts *int }

func (draftChangeTool) Name() string { return "draft_policy_change" }

func (draftChangeTool) Description() string {
	return "Draft a review-only permission narrowing; never changes live grants."
}

func (draftChangeTool) Spec() model.ToolSpec {
	return model.ToolSpec{
		Name:        "draft_policy_change",
		Description: "Draft a review-only permission narrowing; never changes live grants.",
		Parameters: map[string]any{
			"type": "object",
			"properties": map[string]any{
				"tenant": map[string]any{"type": "string"},
				"action": map[string]any{"type": "string"},
			},
		},
	}
}

func (t draftChangeTool) Invoke(_ context.Context, args map[string]any) (any, error) {
	*t.drafts++
	tenant, _ := args["tenant"].(string)
	if tenant == "" {
		tenant = tenantID
	}
	action, _ := args["action"].(string)
	if action == "" {
		action = "narrow_grants"
	}
	return map[string]any{
		"change_id":       "zt-100",
		"tenant":          tenant,
		"action":          action,
		"status":          "draft_only",
		"review_required": true,
		"changes_applied": 0,
	}, nil
}

type fixtureModel struct{ tenant string }

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
				ID:        "events-1",
				Name:      "read_access_events",
				Arguments: map[string]any{"tenant": m.tenant},
			}},
		}}, nil
	case 1:
		return model.Response{Message: model.Message{
			Role: model.RoleAssistant,
			ToolCalls: []model.ToolCall{{
				ID:   "change-1",
				Name: "draft_policy_change",
				Arguments: map[string]any{
					"tenant": m.tenant,
					"action": "narrow_grants",
				},
			}},
		}}, nil
	default:
		var audit any
		var change any
		_ = json.Unmarshal([]byte(tools[0].Content), &audit)
		_ = json.Unmarshal([]byte(tools[len(tools)-1].Content), &change)
		report := map[string]any{
			"stage":           "policy_change_drafted",
			"audit":           audit,
			"change":          change,
			"changes_applied": 0,
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
		return policy.Decision{Allowed: true, Reason: "deterministic zero-trust review"}, nil
	}
	if action.Kind != "tool.invoke" {
		return policy.Decision{Allowed: false, Reason: "unsupported action"}, nil
	}
	tenant, _ := action.Arguments["tenant"].(string)
	inScope := tenant == tenantID
	switch action.ToolName {
	case "read_access_events":
		return policy.Decision{Allowed: inScope, Reason: "only tenant-100 is in review scope"}, nil
	case "draft_policy_change":
		act, _ := action.Arguments["action"].(string)
		allowed := inScope && act == "narrow_grants"
		return policy.Decision{Allowed: allowed, Reason: "only a tenant-100 narrow_grants draft is allowed"}, nil
	}
	return policy.Decision{Allowed: false, Reason: "unknown tool"}, nil
}

type outcome struct {
	output string
	reads  int
	drafts int
	err    error
}

func runScenario(ctx context.Context, tenant string, simulateFailure bool) outcome {
	source := &fixtureSource{simulateFailure: simulateFailure}
	drafts := 0
	tools := tool.NewRegistry()
	tools.Register(readEventsTool{source: source})
	tools.Register(draftChangeTool{drafts: &drafts})
	ag, err := agent.New(agent.Options{
		Model:            &fixtureModel{tenant: tenant},
		Tools:            tools,
		MaxSteps:         5,
		AllowedTools:     []string{"read_access_events", "draft_policy_change"},
		RequirePolicy:    true,
		RequireToolScope: true,
		Policy:           policy.FuncHook(authorize),
	})
	if err != nil {
		return outcome{err: err, reads: source.reads, drafts: drafts}
	}
	result, runErr := ag.Run(ctx, agent.Session{
		ID:          "go-zero-trust-review",
		TenantID:    "local",
		WorkspaceID: "default",
	}, "Review fixed access events and draft a narrower permission policy.")
	got := outcome{reads: source.reads, drafts: drafts}
	if runErr != nil {
		got.err = runErr
		return got
	}
	got.output = result.Output
	return got
}

func runTests(ctx context.Context, stdout io.Writer) error {
	success := runScenario(ctx, tenantID, false)
	if success.err != nil {
		return fmt.Errorf("success path failed: %w", success.err)
	}
	if success.reads != 1 || success.drafts != 1 {
		return fmt.Errorf("success verification failed: reads=%d drafts=%d", success.reads, success.drafts)
	}
	var report map[string]any
	if err := json.Unmarshal([]byte(success.output), &report); err != nil {
		return fmt.Errorf("success output is not JSON: %w", err)
	}
	audit, _ := report["audit"].(map[string]any)
	change, _ := report["change"].(map[string]any)
	if report["stage"] != "policy_change_drafted" || audit["overgranted"] != float64(2) ||
		change["status"] != "draft_only" || report["changes_applied"] != float64(0) {
		return fmt.Errorf("success verification failed: %s", success.output)
	}
	fmt.Fprintln(stdout, "success: tenant-100 overgranted=2 status=draft_only changes=0 reads=1")

	denied := runScenario(ctx, "tenant-200", false)
	if denied.err == nil || denied.reads != 0 {
		return fmt.Errorf("deny verification failed: reads=%d err=%v", denied.reads, denied.err)
	}
	if !strings.Contains(denied.err.Error(), "denied") {
		return fmt.Errorf("deny code failed: %v", denied.err)
	}
	fmt.Fprintln(stdout, "deny: policy denied reads=0")

	failed := runScenario(ctx, tenantID, true)
	if !errors.Is(failed.err, errAuditUnavailable) || failed.reads != 1 || failed.drafts != 0 {
		return fmt.Errorf("failure verification failed: reads=%d err=%v", failed.reads, failed.err)
	}
	fmt.Fprintln(stdout, "failure: TENANT_AUDIT_UNAVAILABLE reads=1")
	return nil
}

func main() {
	testMode := flag.Bool("test", false, "run the deterministic tutorial checks")
	tenant := flag.String("tenant", tenantID, "tenant id to review")
	simulateFailure := flag.Bool("simulate-failure", false, "make the audit source fail")
	flag.Parse()

	ctx := context.Background()
	if *testMode {
		if err := runTests(ctx, os.Stdout); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		return
	}
	got := runScenario(ctx, *tenant, *simulateFailure)
	if got.err != nil {
		fmt.Fprintf(os.Stderr, "error: %v reads=%d\n", got.err, got.reads)
		os.Exit(1)
	}
	fmt.Fprintln(os.Stdout, got.output)
	fmt.Fprintf(os.Stdout, "reads=%d\n", got.reads)
}
