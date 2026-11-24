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

const shipmentID = "shipment-100"

var errShipmentUnavailable = errors.New("SHIPMENT_INDEX_UNAVAILABLE")

type ShipmentSource interface {
	Documents(ctx context.Context, shipment string) (map[string]any, error)
}

type fixtureShipmentSource struct {
	simulateFailure bool
	reads           int
}

func (s *fixtureShipmentSource) Documents(_ context.Context, shipment string) (map[string]any, error) {
	s.reads++
	if s.simulateFailure {
		return nil, errShipmentUnavailable
	}
	return map[string]any{
		"shipment_id": shipment,
		"documents":   3,
		"missing":     []any{"certificate-of-origin"},
		"routes": []any{
			map[string]any{"id": "direct", "days": 12},
			map[string]any{"id": "transship", "days": 16},
		},
		"source": "shipment_fixture",
	}, nil
}

type readShipmentTool struct{ source ShipmentSource }

func (readShipmentTool) Name() string { return "read_shipment" }

func (readShipmentTool) Description() string {
	return "Validate fixed customs document fields; no filing or network access."
}

func (readShipmentTool) Spec() model.ToolSpec {
	return model.ToolSpec{
		Name:        "read_shipment",
		Description: "Validate fixed customs document fields.",
		Parameters: map[string]any{
			"type":       "object",
			"properties": map[string]any{"shipment_id": map[string]any{"type": "string"}},
		},
	}
}

func (t readShipmentTool) Invoke(ctx context.Context, args map[string]any) (any, error) {
	id, _ := args["shipment_id"].(string)
	if id == "" {
		id = shipmentID
	}
	return t.source.Documents(ctx, id)
}

type draftCustomsTool struct{ calls *int }

func (draftCustomsTool) Name() string { return "draft_customs" }

func (draftCustomsTool) Description() string {
	return "Draft a review-only reroute; never files customs documents."
}

func (draftCustomsTool) Spec() model.ToolSpec {
	return model.ToolSpec{
		Name:        "draft_customs",
		Description: "Draft a review-only customs reroute.",
		Parameters: map[string]any{
			"type": "object",
			"properties": map[string]any{
				"shipment_id": map[string]any{"type": "string"},
				"action":      map[string]any{"type": "string"},
			},
		},
	}
}

func (t draftCustomsTool) Invoke(_ context.Context, args map[string]any) (any, error) {
	*t.calls++
	id, _ := args["shipment_id"].(string)
	if id == "" {
		id = shipmentID
	}
	action, _ := args["action"].(string)
	if action == "" {
		action = "draft_reroute"
	}
	return map[string]any{
		"draft_id":        "customs-100",
		"shipment_id":     id,
		"action":          action,
		"route":           "transship",
		"status":          "draft_only",
		"review_required": true,
		"filings":         0,
	}, nil
}

type fixtureModel struct{ shipment string }

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
				Name:      "read_shipment",
				Arguments: map[string]any{"shipment_id": m.shipment},
			}},
		}}, nil
	case 1:
		return model.Response{Message: model.Message{
			Role: model.RoleAssistant,
			ToolCalls: []model.ToolCall{{
				ID:   "draft-1",
				Name: "draft_customs",
				Arguments: map[string]any{
					"shipment_id": m.shipment,
					"action":      "draft_reroute",
				},
			}},
		}}, nil
	default:
		var shipment any
		var draft any
		_ = json.Unmarshal([]byte(toolMessages[0].Content), &shipment)
		_ = json.Unmarshal([]byte(toolMessages[1].Content), &draft)
		report := map[string]any{
			"shipment": shipment,
			"draft":    draft,
			"policy":   "validate and draft only; customs filing remains application-owned",
			"filings":  0,
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

func runScenario(ctx context.Context, shipment string, simulateFailure bool) outcome {
	source := &fixtureShipmentSource{simulateFailure: simulateFailure}
	draftCalls := 0

	tools := tool.NewRegistry()
	tools.Register(readShipmentTool{source: source})
	tools.Register(draftCustomsTool{calls: &draftCalls})

	ag, err := agent.New(agent.Options{
		Model:            &fixtureModel{shipment: shipment},
		SystemPrompt:     "You validate one fixed customs shipment. Read and draft only.",
		Tools:            tools,
		MaxSteps:         5,
		AllowedTools:     []string{"read_shipment", "draft_customs"},
		RequirePolicy:    true,
		RequireToolScope: true,
		Policy: policy.FuncHook(func(_ context.Context, action policy.Action) (policy.Decision, error) {
			if action.Kind == "model.generate" {
				return policy.Decision{Allowed: true, Reason: "deterministic customs review"}, nil
			}
			if action.Kind != "tool.invoke" {
				return policy.Decision{Allowed: false, Reason: "unsupported action"}, nil
			}
			inScope, _ := action.Arguments["shipment_id"].(string)
			allowed := inScope == shipmentID
			switch action.ToolName {
			case "read_shipment":
				return policy.Decision{Allowed: allowed, Reason: "only shipment-100 is in scope"}, nil
			case "draft_customs":
				act, _ := action.Arguments["action"].(string)
				return policy.Decision{Allowed: allowed && act == "draft_reroute", Reason: "only a review-only reroute draft is allowed"}, nil
			}
			return policy.Decision{Allowed: false, Reason: "unknown tool"}, nil
		}),
	})
	if err != nil {
		return outcome{err: err, reads: source.reads, drafts: draftCalls}
	}

	result, runErr := ag.Run(ctx, agent.Session{
		ID:          "go-customs-reroute",
		TenantID:    "local",
		WorkspaceID: "default",
	}, "Validate the fixed shipment and draft a review-only reroute.")
	got := outcome{reads: source.reads, drafts: draftCalls}
	if runErr != nil {
		got.err = runErr
		return got
	}
	got.output = result.Output
	return got
}

func runTests(ctx context.Context, stdout io.Writer) error {
	success := runScenario(ctx, shipmentID, false)
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
	shipment, _ := report["shipment"].(map[string]any)
	draft, _ := report["draft"].(map[string]any)
	missing, _ := shipment["missing"].([]any)
	if len(missing) != 1 || draft["status"] != "draft_only" ||
		draft["route"] != "transship" || draft["filings"] != float64(0) ||
		report["filings"] != float64(0) {
		return fmt.Errorf("success verification failed: shipment=%v draft=%v", shipment, draft)
	}
	fmt.Fprintln(stdout, "success: shipment-100 documents=3 missing=1 route=transship status=draft_only filings=0 reads=1")

	denied := runScenario(ctx, "shipment-200", false)
	if denied.err == nil || denied.reads != 0 || denied.drafts != 0 {
		return fmt.Errorf("deny verification failed: reads=%d drafts=%d err=%v", denied.reads, denied.drafts, denied.err)
	}
	fmt.Fprintln(stdout, "deny: policy denied reads=0")

	failure := runScenario(ctx, shipmentID, true)
	if !errors.Is(failure.err, errShipmentUnavailable) || failure.reads != 1 || failure.drafts != 0 {
		return fmt.Errorf("failure verification failed: reads=%d err=%v", failure.reads, failure.err)
	}
	fmt.Fprintln(stdout, "failure: SHIPMENT_INDEX_UNAVAILABLE reads=1")
	return nil
}

func main() {
	testMode := flag.Bool("test", false, "run the deterministic tutorial checks")
	shipment := flag.String("shipment", shipmentID, "customs shipment id")
	simulateFailure := flag.Bool("simulate-failure", false, "make the shipment index fail")
	flag.Parse()

	ctx := context.Background()
	if *testMode {
		if err := runTests(ctx, os.Stdout); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		return
	}

	got := runScenario(ctx, *shipment, *simulateFailure)
	if got.err != nil {
		fmt.Fprintf(os.Stderr, "error: %v reads=%d\n", got.err, got.reads)
		os.Exit(1)
	}
	fmt.Fprintln(os.Stdout, got.output)
	fmt.Fprintf(os.Stdout, "reads=%d\n", got.reads)
}
