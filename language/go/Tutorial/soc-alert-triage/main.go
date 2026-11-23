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
	"github.com/axisvela/praxo-core/v2/pkg/event"
	"github.com/axisvela/praxo-core/v2/pkg/model"
	"github.com/axisvela/praxo-core/v2/pkg/policy"
	"github.com/axisvela/praxo-core/v2/pkg/tool"
)

const alertID = "alert-100"

var errAlertUnavailable = errors.New("ALERT_SOURCE_UNAVAILABLE")

// AlertSource is the application-owned dependency behind the read tool.
type AlertSource interface {
	Alert(ctx context.Context, id string) (map[string]any, error)
}

type fixtureSource struct {
	simulateFailure bool
	reads           int
}

func (s *fixtureSource) Alert(_ context.Context, id string) (map[string]any, error) {
	s.reads++
	if s.simulateFailure {
		return nil, errAlertUnavailable
	}
	return map[string]any{
		"alert_id":       id,
		"severity":       "high",
		"host":           "edge-web-01",
		"technique":      "brute_force",
		"events":         42,
		"reporter_email": "analyst@example.com",
		"contact_phone":  "555-123-4567",
		"source":         "alert_fixture",
	}, nil
}

type readAlertTool struct{ source AlertSource }

func (readAlertTool) Name() string { return "read_alert" }

func (readAlertTool) Description() string {
	return "Read a fixed SOC alert through the application-owned source; PII is redacted."
}

func (readAlertTool) Spec() model.ToolSpec {
	return model.ToolSpec{
		Name:        "read_alert",
		Description: "Read a fixed SOC alert through the application-owned source.",
		Parameters: map[string]any{
			"type":       "object",
			"properties": map[string]any{"alert_id": map[string]any{"type": "string"}},
		},
	}
}

func (t readAlertTool) Invoke(ctx context.Context, args map[string]any) (any, error) {
	id, _ := args["alert_id"].(string)
	if id == "" {
		id = alertID
	}
	return t.source.Alert(ctx, id)
}

type draftContainmentTool struct{ calls *int }

func (draftContainmentTool) Name() string { return "draft_containment" }

func (draftContainmentTool) Description() string {
	return "Draft a review-only host isolation without a host action."
}

func (draftContainmentTool) Spec() model.ToolSpec {
	return model.ToolSpec{
		Name:        "draft_containment",
		Description: "Draft a review-only host isolation without a host action.",
		Parameters: map[string]any{
			"type": "object",
			"properties": map[string]any{
				"alert_id": map[string]any{"type": "string"},
				"host":     map[string]any{"type": "string"},
				"action":   map[string]any{"type": "string"},
			},
		},
	}
}

func (t draftContainmentTool) Invoke(_ context.Context, args map[string]any) (any, error) {
	*t.calls++
	id, _ := args["alert_id"].(string)
	if id == "" {
		id = alertID
	}
	host, _ := args["host"].(string)
	action, _ := args["action"].(string)
	if action == "" {
		action = "isolate_host"
	}
	return map[string]any{
		"draft_id":        "containment-100",
		"alert_id":        id,
		"host":            host,
		"action":          action,
		"status":          "draft_only",
		"review_required": true,
		"host_actions":    0,
	}, nil
}

type fixtureModel struct{ alert string }

func (m *fixtureModel) Generate(_ context.Context, req model.Request) (model.Response, error) {
	var toolMessages []model.Message
	for _, message := range req.Messages {
		if message.Role == model.RoleTool {
			toolMessages = append(toolMessages, message)
		}
	}
	switch len(toolMessages) {
	case 0:
		return model.Response{Message: model.Message{
			Role: model.RoleAssistant,
			ToolCalls: []model.ToolCall{{
				ID:        "read-1",
				Name:      "read_alert",
				Arguments: map[string]any{"alert_id": m.alert},
			}},
		}}, nil
	case 1:
		var alert map[string]any
		_ = json.Unmarshal([]byte(toolMessages[0].Content), &alert)
		host, _ := alert["host"].(string)
		return model.Response{Message: model.Message{
			Role: model.RoleAssistant,
			ToolCalls: []model.ToolCall{{
				ID:   "containment-1",
				Name: "draft_containment",
				Arguments: map[string]any{
					"alert_id": m.alert,
					"host":     host,
					"action":   "isolate_host",
				},
			}},
		}}, nil
	default:
		var alert any
		var containment any
		_ = json.Unmarshal([]byte(toolMessages[0].Content), &alert)
		_ = json.Unmarshal([]byte(toolMessages[1].Content), &containment)
		report := map[string]any{
			"alert":         alert,
			"containment":   containment,
			"policy":        "read and draft only; host actions remain application-owned",
			"host_actions":  0,
			"pii_redaction": "applied by Core PIIMiddleware before model-bound messages",
		}
		raw, err := json.Marshal(report)
		if err != nil {
			return model.Response{}, err
		}
		return model.Response{Message: model.Message{Role: model.RoleAssistant, Content: string(raw)}}, nil
	}
}

type outcome struct {
	output string
	err    error
	reads  int
	drafts int
	events []string
}

func runScenario(ctx context.Context, alert string, simulateFailure bool) outcome {
	source := &fixtureSource{simulateFailure: simulateFailure}
	draftCalls := 0

	tools := tool.NewRegistry()
	tools.Register(readAlertTool{source: source})
	tools.Register(draftContainmentTool{calls: &draftCalls})

	redactor := agent.NewPIIRedactor(agent.DefaultPIIRules()...)
	var events []string
	ag, err := agent.New(agent.Options{
		Model:            &fixtureModel{alert: alert},
		SystemPrompt:     "You triage one SOC alert. Read evidence and draft a review action only.",
		Tools:            tools,
		MaxSteps:         5,
		AllowedTools:     []string{"read_alert", "draft_containment"},
		RequirePolicy:    true,
		RequireToolScope: true,
		PIIRedactor:      &redactor,
		Policy: policy.FuncHook(func(_ context.Context, action policy.Action) (policy.Decision, error) {
			if action.Kind == "model.generate" {
				return policy.Decision{Allowed: true, Reason: "deterministic SOC triage"}, nil
			}
			if action.Kind != "tool.invoke" {
				return policy.Decision{Allowed: false, Reason: "unsupported action"}, nil
			}
			id, _ := action.Arguments["alert_id"].(string)
			inScope := id == alertID
			switch action.ToolName {
			case "read_alert":
				return policy.Decision{Allowed: inScope, Reason: "only alert-100 read is allowed"}, nil
			case "draft_containment":
				act, _ := action.Arguments["action"].(string)
				allowed := inScope && act == "isolate_host"
				return policy.Decision{Allowed: allowed, Reason: "only alert-100 isolate_host draft is allowed"}, nil
			}
			return policy.Decision{Allowed: false, Reason: "unknown tool"}, nil
		}),
		Events: event.FuncSink(func(_ context.Context, ev event.Event) error {
			events = append(events, ev.Type)
			return nil
		}),
	})
	if err != nil {
		return outcome{err: err, reads: source.reads, drafts: draftCalls, events: events}
	}

	result, runErr := ag.Run(ctx, agent.Session{
		ID:          "go-soc-alert-triage",
		TenantID:    "local",
		WorkspaceID: "default",
	}, "Triage the fixed alert and draft a review-only containment.")
	got := outcome{reads: source.reads, drafts: draftCalls, events: events}
	if runErr != nil {
		got.err = runErr
		return got
	}
	got.output = result.Output
	return got
}

func hasEvent(events []string, want string) bool {
	for _, value := range events {
		if value == want {
			return true
		}
	}
	return false
}

func runTests(ctx context.Context, stdout io.Writer) error {
	success := runScenario(ctx, alertID, false)
	if success.err != nil {
		return fmt.Errorf("success path failed: %w", success.err)
	}
	if success.reads != 1 || success.drafts != 1 {
		return fmt.Errorf("success verification failed: reads=%d drafts=%d", success.reads, success.drafts)
	}
	if strings.Contains(success.output, "analyst@example.com") ||
		strings.Contains(success.output, "555-123-4567") {
		return fmt.Errorf("raw PII leaked into report")
	}
	if !strings.Contains(success.output, "[REDACTED:email]") ||
		!strings.Contains(success.output, "[REDACTED:phone]") {
		return fmt.Errorf("redaction placeholders missing: %s", success.output)
	}
	var report map[string]any
	if err := json.Unmarshal([]byte(success.output), &report); err != nil {
		return fmt.Errorf("success output is not JSON: %w", err)
	}
	containment, _ := report["containment"].(map[string]any)
	if containment["status"] != "draft_only" || containment["host_actions"] != float64(0) ||
		report["host_actions"] != float64(0) {
		return fmt.Errorf("success verification failed: containment=%v", containment)
	}
	if !hasEvent(success.events, "run.started") || !hasEvent(success.events, "tool.call") ||
		!hasEvent(success.events, "run.completed") {
		return fmt.Errorf("success events missing: %v", success.events)
	}
	fmt.Fprintln(stdout, "success: alert-100 severity=high action=isolate_host status=draft_only writes=0 reads=1 pii=redacted")

	denied := runScenario(ctx, "alert-200", false)
	if denied.err == nil || denied.reads != 0 {
		return fmt.Errorf("deny verification failed: reads=%d err=%v", denied.reads, denied.err)
	}
	fmt.Fprintln(stdout, "deny: policy denied reads=0")

	failure := runScenario(ctx, alertID, true)
	if !errors.Is(failure.err, errAlertUnavailable) || failure.reads != 1 || failure.drafts != 0 {
		return fmt.Errorf("failure verification failed: reads=%d err=%v", failure.reads, failure.err)
	}
	fmt.Fprintln(stdout, "failure: ALERT_SOURCE_UNAVAILABLE reads=1")
	return nil
}

func main() {
	testMode := flag.Bool("test", false, "run the deterministic tutorial checks")
	alert := flag.String("alert", alertID, "alert id to triage")
	simulateFailure := flag.Bool("simulate-failure", false, "make the alert source fail")
	flag.Parse()

	ctx := context.Background()
	if *testMode {
		if err := runTests(ctx, os.Stdout); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		return
	}

	got := runScenario(ctx, *alert, *simulateFailure)
	if got.err != nil {
		fmt.Fprintf(os.Stderr, "error: %v reads=%d\n", got.err, got.reads)
		os.Exit(1)
	}
	fmt.Fprintln(os.Stdout, got.output)
	fmt.Fprintf(os.Stdout, "reads=%d\n", got.reads)
}
