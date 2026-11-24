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
	"github.com/axisvela/praxo-core/v2/pkg/model"
	"github.com/axisvela/praxo-core/v2/pkg/policy"
	"github.com/axisvela/praxo-core/v2/pkg/tool"
)

const eventID = "event-100"

var errRoadUnavailable = errors.New("ROAD_INDEX_UNAVAILABLE")

type RoadSource interface {
	Closures(ctx context.Context, event string) (map[string]any, error)
}

type fixtureRoadSource struct {
	simulateFailure bool
	reads           int
}

func (s *fixtureRoadSource) Closures(_ context.Context, event string) (map[string]any, error) {
	s.reads++
	if s.simulateFailure {
		return nil, errRoadUnavailable
	}
	return map[string]any{
		"event_id": event,
		"closures": []any{
			map[string]any{"road": "road-1", "status": "closed"},
			map[string]any{"road": "road-2", "status": "open"},
		},
		"depots":   2,
		"shelters": 1,
		"source":   "road_fixture",
	}, nil
}

type readEventTool struct{ source RoadSource }

func (readEventTool) Name() string { return "read_event" }

func (readEventTool) Description() string {
	return "Read fixed road closures for an emergency event; no live dispatch."
}

func (readEventTool) Spec() model.ToolSpec {
	return model.ToolSpec{
		Name:        "read_event",
		Description: "Read fixed road closures for an emergency event.",
		Parameters: map[string]any{
			"type":       "object",
			"properties": map[string]any{"event_id": map[string]any{"type": "string"}},
		},
	}
}

func (t readEventTool) Invoke(ctx context.Context, args map[string]any) (any, error) {
	id, _ := args["event_id"].(string)
	if id == "" {
		id = eventID
	}
	return t.source.Closures(ctx, id)
}

type draftAllocationTool struct{ calls *int }

func (draftAllocationTool) Name() string { return "draft_allocation" }

func (draftAllocationTool) Description() string {
	return "Draft a review-only relief route allocation; never dispatches."
}

func (draftAllocationTool) Spec() model.ToolSpec {
	return model.ToolSpec{
		Name:        "draft_allocation",
		Description: "Draft a review-only relief route allocation.",
		Parameters: map[string]any{
			"type": "object",
			"properties": map[string]any{
				"event_id": map[string]any{"type": "string"},
				"action":   map[string]any{"type": "string"},
			},
		},
	}
}

func (t draftAllocationTool) Invoke(_ context.Context, args map[string]any) (any, error) {
	*t.calls++
	id, _ := args["event_id"].(string)
	if id == "" {
		id = eventID
	}
	action, _ := args["action"].(string)
	if action == "" {
		action = "draft_allocation"
	}
	return map[string]any{
		"plan_id":         "relief-100",
		"event_id":        id,
		"action":          action,
		"routes":          2,
		"constraints_ok":  true,
		"status":          "draft_only",
		"review_required": true,
		"dispatches":      0,
		"rescue_orders":   0,
	}, nil
}

type fixtureModel struct{ event string }

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
				Name:      "read_event",
				Arguments: map[string]any{"event_id": m.event},
			}},
		}}, nil
	case 1:
		return model.Response{Message: model.Message{
			Role: model.RoleAssistant,
			ToolCalls: []model.ToolCall{{
				ID:   "plan-1",
				Name: "draft_allocation",
				Arguments: map[string]any{
					"event_id": m.event,
					"action":   "draft_allocation",
				},
			}},
		}}, nil
	default:
		var event any
		var plan any
		_ = json.Unmarshal([]byte(toolMessages[0].Content), &event)
		_ = json.Unmarshal([]byte(toolMessages[1].Content), &plan)
		report := map[string]any{
			"event":          event,
			"plan":           plan,
			"policy":         "read and draft only; dispatch and rescue directions remain application-owned",
			"dispatches":     0,
			"rescue_orders":  0,
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
}

func runScenario(ctx context.Context, event string, simulateFailure bool) outcome {
	source := &fixtureRoadSource{simulateFailure: simulateFailure}
	draftCalls := 0

	tools := tool.NewRegistry()
	tools.Register(readEventTool{source: source})
	tools.Register(draftAllocationTool{calls: &draftCalls})

	ag, err := agent.New(agent.Options{
		Model:            &fixtureModel{event: event},
		SystemPrompt:     "You plan relief routes for one fixed emergency event. Read and draft only.",
		Tools:            tools,
		MaxSteps:         5,
		AllowedTools:     []string{"read_event", "draft_allocation"},
		RequirePolicy:    true,
		RequireToolScope: true,
		Policy: policy.FuncHook(func(_ context.Context, action policy.Action) (policy.Decision, error) {
			if action.Kind == "model.generate" {
				return policy.Decision{Allowed: true, Reason: "deterministic emergency planning"}, nil
			}
			if action.Kind != "tool.invoke" {
				return policy.Decision{Allowed: false, Reason: "unsupported action"}, nil
			}
			inScope, _ := action.Arguments["event_id"].(string)
			allowed := inScope == eventID
			switch action.ToolName {
			case "read_event":
				return policy.Decision{Allowed: allowed, Reason: "only event-100 is in scope"}, nil
			case "draft_allocation":
				act, _ := action.Arguments["action"].(string)
				return policy.Decision{Allowed: allowed && act == "draft_allocation", Reason: "only a review-only allocation draft is allowed"}, nil
			}
			return policy.Decision{Allowed: false, Reason: "unknown tool"}, nil
		}),
	})
	if err != nil {
		return outcome{err: err, reads: source.reads, drafts: draftCalls}
	}

	result, runErr := ag.Run(ctx, agent.Session{
		ID:          "go-emergency-route-plan",
		TenantID:    "local",
		WorkspaceID: "default",
	}, "Read the fixed closures and draft a review-only relief allocation.")
	got := outcome{reads: source.reads, drafts: draftCalls}
	if runErr != nil {
		got.err = runErr
		return got
	}
	got.output = result.Output
	return got
}

func runTests(ctx context.Context, stdout io.Writer) error {
	success := runScenario(ctx, eventID, false)
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
	event, _ := report["event"].(map[string]any)
	plan, _ := report["plan"].(map[string]any)
	closures, _ := event["closures"].([]any)
	if len(closures) != 2 || plan["status"] != "draft_only" ||
		plan["routes"] != float64(2) || plan["dispatches"] != float64(0) ||
		plan["rescue_orders"] != float64(0) || report["dispatches"] != float64(0) {
		return fmt.Errorf("success verification failed: event=%v plan=%v", event, plan)
	}
	fmt.Fprintln(stdout, "success: event-100 closures=2 routes=2 status=draft_only dispatches=0 reads=1")

	denied := runScenario(ctx, "event-200", false)
	if denied.err == nil || denied.reads != 0 || denied.drafts != 0 {
		return fmt.Errorf("deny verification failed: reads=%d drafts=%d err=%v", denied.reads, denied.drafts, denied.err)
	}
	fmt.Fprintln(stdout, "deny: policy denied reads=0")

	failure := runScenario(ctx, eventID, true)
	if !errors.Is(failure.err, errRoadUnavailable) || failure.reads != 1 || failure.drafts != 0 {
		return fmt.Errorf("failure verification failed: reads=%d err=%v", failure.reads, failure.err)
	}
	fmt.Fprintln(stdout, "failure: ROAD_INDEX_UNAVAILABLE reads=1")
	return nil
}

func main() {
	testMode := flag.Bool("test", false, "run the deterministic tutorial checks")
	event := flag.String("event", eventID, "emergency event id")
	simulateFailure := flag.Bool("simulate-failure", false, "make the road index fail")
	flag.Parse()

	ctx := context.Background()
	if *testMode {
		if err := runTests(ctx, os.Stdout); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		return
	}

	got := runScenario(ctx, *event, *simulateFailure)
	if got.err != nil {
		fmt.Fprintf(os.Stderr, "error: %v reads=%d\n", got.err, got.reads)
		os.Exit(1)
	}
	fmt.Fprintln(os.Stdout, got.output)
	fmt.Fprintf(os.Stdout, "reads=%d\n", got.reads)
}
