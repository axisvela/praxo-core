package main

import (
	"context"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"os"

	"github.com/axisvela/praxo-core/v2/pkg/agent"
	"github.com/axisvela/praxo-core/v2/pkg/event"
	"github.com/axisvela/praxo-core/v2/pkg/model"
	"github.com/axisvela/praxo-core/v2/pkg/policy"
	"github.com/axisvela/praxo-core/v2/pkg/tool"
)

const incidentID = "incident-100"

var errSourceUnavailable = errors.New("INCIDENT_SOURCE_UNAVAILABLE")

// IncidentSource is the application-owned dependency behind the tools.
type IncidentSource interface {
	Snapshot(ctx context.Context, id string) (map[string]any, error)
}

type fixtureSource struct {
	simulateFailure bool
	reads           int
}

func (s *fixtureSource) Snapshot(_ context.Context, id string) (map[string]any, error) {
	s.reads++
	if s.simulateFailure {
		return nil, errSourceUnavailable
	}
	return map[string]any{
		"incident_id":  id,
		"severity":     "high",
		"service":      "checkout-api",
		"status":       "mitigating",
		"open_alerts":  3,
		"source":       "source_fixture",
		"owner_review": true,
	}, nil
}

type readIncidentTool struct{ source IncidentSource }

func (readIncidentTool) Name() string { return "read_incident" }

func (readIncidentTool) Description() string {
	return "Read an incident snapshot from the application-owned source."
}

func (readIncidentTool) Spec() model.ToolSpec {
	return model.ToolSpec{
		Name:        "read_incident",
		Description: "Read an incident snapshot from the application-owned source.",
		Parameters: map[string]any{
			"type": "object",
			"properties": map[string]any{
				"incident_id": map[string]any{"type": "string"},
			},
		},
	}
}

func (t readIncidentTool) Invoke(ctx context.Context, args map[string]any) (any, error) {
	id, _ := args["incident_id"].(string)
	if id == "" {
		id = incidentID
	}
	return t.source.Snapshot(ctx, id)
}

type draftUpdateTool struct{ writes *int }

func (draftUpdateTool) Name() string { return "draft_update" }

func (draftUpdateTool) Description() string {
	return "Draft an operator update without writing to the incident."
}

func (draftUpdateTool) Spec() model.ToolSpec {
	return model.ToolSpec{
		Name:        "draft_update",
		Description: "Draft an operator update without writing to the incident.",
		Parameters: map[string]any{
			"type": "object",
			"properties": map[string]any{
				"incident_id": map[string]any{"type": "string"},
				"action":      map[string]any{"type": "string"},
			},
		},
	}
}

func (t draftUpdateTool) Invoke(_ context.Context, args map[string]any) (any, error) {
	id, _ := args["incident_id"].(string)
	if id == "" {
		id = incidentID
	}
	action, _ := args["action"].(string)
	if action == "" {
		action = "notify_oncall"
	}
	return map[string]any{
		"draft_id":        "update-100",
		"incident_id":     id,
		"action":          action,
		"status":          "draft_only",
		"review_required": true,
		"incident_writes": *t.writes,
	}, nil
}

type fixtureModel struct{ incident string }

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
				Name:      "read_incident",
				Arguments: map[string]any{"incident_id": m.incident},
			}},
		}}, nil
	case 1:
		return model.Response{Message: model.Message{
			Role: model.RoleAssistant,
			ToolCalls: []model.ToolCall{{
				ID:   "update-1",
				Name: "draft_update",
				Arguments: map[string]any{
					"incident_id": m.incident,
					"action":      "notify_oncall",
					"reason":      "three open alerts on the checkout service",
				},
			}},
		}}, nil
	default:
		var snapshot any
		var draft any
		_ = json.Unmarshal([]byte(toolMessages[0].Content), &snapshot)
		_ = json.Unmarshal([]byte(toolMessages[1].Content), &draft)
		report := map[string]any{
			"incident":        snapshot,
			"draft":           draft,
			"policy":          "read and draft only; incident writes remain application-owned",
			"incident_writes": 0,
		}
		raw, err := json.Marshal(report)
		if err != nil {
			return model.Response{}, err
		}
		return model.Response{Message: model.Message{
			Role:    model.RoleAssistant,
			Content: string(raw),
		}}, nil
	}
}

type outcome struct {
	output string
	err    error
	reads  int
	writes int
	events []string
}

func runScenario(ctx context.Context, incident string, simulateFailure bool) outcome {
	source := &fixtureSource{simulateFailure: simulateFailure}
	writes := 0

	tools := tool.NewRegistry()
	tools.Register(readIncidentTool{source: source})
	tools.Register(draftUpdateTool{writes: &writes})

	var events []string
	ag, err := agent.New(agent.Options{
		Model:            &fixtureModel{incident: incident},
		SystemPrompt:     "You coordinate one incident. Use tools and never mutate the incident.",
		Tools:            tools,
		MaxSteps:         5,
		AllowedTools:     []string{"read_incident", "draft_update"},
		RequirePolicy:    true,
		RequireToolScope: true,
		Policy: policy.FuncHook(func(_ context.Context, action policy.Action) (policy.Decision, error) {
			if action.Kind == "model.generate" {
				return policy.Decision{Allowed: true, Reason: "deterministic incident coordination"}, nil
			}
			if action.Kind != "tool.invoke" {
				return policy.Decision{Allowed: false, Reason: "unsupported action"}, nil
			}
			id, _ := action.Arguments["incident_id"].(string)
			inScope := id == incidentID
			switch action.ToolName {
			case "read_incident":
				return policy.Decision{Allowed: inScope, Reason: "only incident-100 read is allowed"}, nil
			case "draft_update":
				actionName, _ := action.Arguments["action"].(string)
				allowed := inScope && actionName == "notify_oncall"
				return policy.Decision{Allowed: allowed, Reason: "only incident-100 notify_oncall draft is allowed"}, nil
			}
			return policy.Decision{Allowed: false, Reason: "unknown tool"}, nil
		}),
		Events: event.FuncSink(func(_ context.Context, ev event.Event) error {
			events = append(events, ev.Type)
			return nil
		}),
	})
	if err != nil {
		return outcome{err: err, reads: source.reads, writes: writes, events: events}
	}

	result, runErr := ag.Run(ctx, agent.Session{
		ID:          "go-incident-coordination",
		TenantID:    "local",
		WorkspaceID: "default",
	}, "Coordinate the fixed incident and draft an operator update.")
	got := outcome{reads: source.reads, writes: writes, events: events}
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
	success := runScenario(ctx, incidentID, false)
	if success.err != nil {
		return fmt.Errorf("success path failed: %w", success.err)
	}
	var report map[string]any
	if err := json.Unmarshal([]byte(success.output), &report); err != nil {
		return fmt.Errorf("success output is not JSON: %w", err)
	}
	incident, _ := report["incident"].(map[string]any)
	draft, _ := report["draft"].(map[string]any)
	if incident["severity"] != "high" || draft["status"] != "draft_only" ||
		draft["action"] != "notify_oncall" || report["incident_writes"] != float64(0) ||
		success.reads != 1 || success.writes != 0 {
		return fmt.Errorf("success verification failed: reads=%d writes=%d", success.reads, success.writes)
	}
	if !hasEvent(success.events, "run.started") || !hasEvent(success.events, "tool.call") ||
		!hasEvent(success.events, "run.completed") {
		return fmt.Errorf("success events missing: %v", success.events)
	}
	fmt.Fprintln(stdout, "success: incident-100 severity=high action=notify_oncall status=draft_only writes=0 reads=1 events=3")

	denied := runScenario(ctx, "incident-200", false)
	if denied.err == nil || denied.reads != 0 {
		return fmt.Errorf("deny verification failed: reads=%d err=%v", denied.reads, denied.err)
	}
	fmt.Fprintln(stdout, "deny: policy denied reads=0")

	failure := runScenario(ctx, incidentID, true)
	if !errors.Is(failure.err, errSourceUnavailable) || failure.reads != 1 || failure.writes != 0 {
		return fmt.Errorf("failure verification failed: reads=%d err=%v", failure.reads, failure.err)
	}
	fmt.Fprintln(stdout, "failure: INCIDENT_SOURCE_UNAVAILABLE reads=1")
	return nil
}

func main() {
	testMode := flag.Bool("test", false, "run the deterministic tutorial checks")
	incident := flag.String("incident", incidentID, "incident id to coordinate")
	simulateFailure := flag.Bool("simulate-failure", false, "make the incident source fail")
	flag.Parse()

	ctx := context.Background()
	if *testMode {
		if err := runTests(ctx, os.Stdout); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		return
	}

	got := runScenario(ctx, *incident, *simulateFailure)
	if got.err != nil {
		fmt.Fprintf(os.Stderr, "error: %v reads=%d\n", got.err, got.reads)
		os.Exit(1)
	}
	fmt.Fprintln(os.Stdout, got.output)
	fmt.Fprintf(os.Stdout, "reads=%d\n", got.reads)
}
