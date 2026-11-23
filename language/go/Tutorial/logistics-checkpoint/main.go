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
	"time"

	"github.com/axisvela/praxo-core/v2/pkg/agent"
	"github.com/axisvela/praxo-core/v2/pkg/checkpoint"
	"github.com/axisvela/praxo-core/v2/pkg/model"
	"github.com/axisvela/praxo-core/v2/pkg/policy"
	"github.com/axisvela/praxo-core/v2/pkg/tool"
)

const shipmentID = "shipment-100"

var errShipmentUnavailable = errors.New("SHIPMENT_SOURCE_UNAVAILABLE")

// ShipmentSource is the application-owned dependency behind the read tool.
type ShipmentSource interface {
	Load(ctx context.Context, id string) (map[string]any, error)
}

type fixtureSource struct {
	simulateFailure bool
	reads           int
}

func (s *fixtureSource) Load(_ context.Context, id string) (map[string]any, error) {
	s.reads++
	if s.simulateFailure {
		return nil, errShipmentUnavailable
	}
	return map[string]any{
		"shipment_id": id,
		"origin":      "rotterdam",
		"destination": "singapore",
		"status":      "delayed",
		"eta_hours":   38,
		"source":      "shipment_fixture",
	}, nil
}

type readShipmentTool struct{ source ShipmentSource }

func (readShipmentTool) Name() string { return "read_shipment" }

func (readShipmentTool) Description() string {
	return "Read a fixed shipment through the application-owned source."
}

func (readShipmentTool) Spec() model.ToolSpec {
	return model.ToolSpec{
		Name:        "read_shipment",
		Description: "Read a fixed shipment through the application-owned source.",
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
	return t.source.Load(ctx, id)
}

type draftRerouteTool struct{ drafts *int }

func (draftRerouteTool) Name() string { return "draft_reroute" }

func (draftRerouteTool) Description() string {
	return "Draft a review-only reroute without changing the route."
}

func (draftRerouteTool) Spec() model.ToolSpec {
	return model.ToolSpec{
		Name:        "draft_reroute",
		Description: "Draft a review-only reroute without changing the route.",
		Parameters: map[string]any{
			"type": "object",
			"properties": map[string]any{
				"shipment_id": map[string]any{"type": "string"},
				"action":      map[string]any{"type": "string"},
			},
		},
	}
}

func (t draftRerouteTool) Invoke(_ context.Context, args map[string]any) (any, error) {
	*t.drafts++
	id, _ := args["shipment_id"].(string)
	if id == "" {
		id = shipmentID
	}
	return map[string]any{
		"draft_id":        "reroute-100",
		"shipment_id":     id,
		"new_route":       "hub-b",
		"status":          "draft_only",
		"review_required": true,
		"route_writes":    0,
	}, nil
}

type fixtureModel struct {
	shipment string
	last     []model.Message
}

func toolMessages(messages []model.Message) []model.Message {
	var out []model.Message
	for _, message := range messages {
		if message.Role == model.RoleTool {
			out = append(out, message)
		}
	}
	return out
}

func lastUserContent(messages []model.Message) string {
	for index := len(messages) - 1; index >= 0; index-- {
		if messages[index].Role == model.RoleUser {
			return messages[index].Content
		}
	}
	return ""
}

func (m *fixtureModel) Generate(_ context.Context, req model.Request) (model.Response, error) {
	m.last = append([]model.Message(nil), req.Messages...)
	tools := toolMessages(req.Messages)
	prompt := strings.ToLower(lastUserContent(req.Messages))
	wantsDraft := strings.Contains(prompt, "draft")

	switch {
	case len(tools) == 0:
		return model.Response{Message: model.Message{
			Role: model.RoleAssistant,
			ToolCalls: []model.ToolCall{{
				ID:        "read-1",
				Name:      "read_shipment",
				Arguments: map[string]any{"shipment_id": m.shipment},
			}},
		}}, nil
	case wantsDraft && len(tools) == 1:
		return model.Response{Message: model.Message{
			Role: model.RoleAssistant,
			ToolCalls: []model.ToolCall{{
				ID:   "reroute-1",
				Name: "draft_reroute",
				Arguments: map[string]any{
					"shipment_id": m.shipment,
					"action":      "reroute",
				},
			}},
		}}, nil
	case wantsDraft:
		var shipment any
		var reroute any
		_ = json.Unmarshal([]byte(tools[0].Content), &shipment)
		_ = json.Unmarshal([]byte(tools[1].Content), &reroute)
		report := map[string]any{
			"stage":        "reroute_drafted",
			"shipment":     shipment,
			"reroute":      reroute,
			"route_writes": 0,
		}
		return model.Response{Message: model.Message{Role: model.RoleAssistant, Content: mustJSON(report)}}, nil
	default:
		var shipment any
		_ = json.Unmarshal([]byte(tools[0].Content), &shipment)
		report := map[string]any{
			"stage":          "assessed",
			"shipment":       shipment,
			"recommendation": "reroute",
			"route_writes":   0,
		}
		return model.Response{Message: model.Message{Role: model.RoleAssistant, Content: mustJSON(report)}}, nil
	}
}

func mustJSON(value any) string {
	raw, err := json.Marshal(value)
	if err != nil {
		return "{}"
	}
	return string(raw)
}

type memoryStore struct{ data map[string][]byte }

func (s *memoryStore) save(cp *checkpoint.Checkpoint) error {
	raw, err := json.Marshal(cp)
	if err != nil {
		return err
	}
	s.data[cp.SessionID] = raw
	return nil
}

func (s *memoryStore) load(sessionID string) (*checkpoint.Checkpoint, error) {
	raw := s.data[sessionID]
	if raw == nil {
		return nil, nil
	}
	var cp checkpoint.Checkpoint
	if err := json.Unmarshal(raw, &cp); err != nil {
		return nil, err
	}
	return &cp, nil
}

func toCheckpoint(messages []model.Message) []checkpoint.Message {
	out := make([]checkpoint.Message, 0, len(messages))
	for _, message := range messages {
		out = append(out, checkpoint.Message{Role: message.Role, Content: message.Content})
	}
	return out
}

func toModel(messages []checkpoint.Message) []model.Message {
	out := make([]model.Message, 0, len(messages))
	for _, message := range messages {
		out = append(out, model.Message{Role: message.Role, Content: message.Content})
	}
	return out
}

func authorize(_ context.Context, action policy.Action) (policy.Decision, error) {
	if action.Kind == "model.generate" {
		return policy.Decision{Allowed: true, Reason: "deterministic logistics coordination"}, nil
	}
	if action.Kind != "tool.invoke" {
		return policy.Decision{Allowed: false, Reason: "unsupported action"}, nil
	}
	id, _ := action.Arguments["shipment_id"].(string)
	inScope := id == shipmentID
	switch action.ToolName {
	case "read_shipment":
		return policy.Decision{Allowed: inScope, Reason: "only shipment-100 read is allowed"}, nil
	case "draft_reroute":
		act, _ := action.Arguments["action"].(string)
		allowed := inScope && act == "reroute"
		return policy.Decision{Allowed: allowed, Reason: "only shipment-100 reroute draft is allowed"}, nil
	}
	return policy.Decision{Allowed: false, Reason: "unknown tool"}, nil
}

func newAgent(idx *fixtureModel, source ShipmentSource, drafts *int) (*agent.Agent, error) {
	tools := tool.NewRegistry()
	tools.Register(readShipmentTool{source: source})
	tools.Register(draftRerouteTool{drafts: drafts})
	return agent.New(agent.Options{
		Model:            idx,
		Tools:            tools,
		MaxSteps:         5,
		AllowedTools:     []string{"read_shipment", "draft_reroute"},
		RequirePolicy:    true,
		RequireToolScope: true,
		Policy:           policy.FuncHook(authorize),
	})
}

func transcript(snapshot *fixtureModel, output string) []model.Message {
	messages := append([]model.Message(nil), snapshot.last...)
	messages = append(messages, model.Message{Role: model.RoleAssistant, Content: output})
	return messages
}

type outcome struct {
	stage   string
	reads   int
	drafts  int
	cpCount int
	err     error
}

func runWorkflow(ctx context.Context, simulateFailure bool) (outcome, outcome) {
	source := &fixtureSource{simulateFailure: simulateFailure}
	drafts := 0
	store := &memoryStore{data: map[string][]byte{}}
	sessionID := "go-logistics-checkpoint"

	assessModel := &fixtureModel{shipment: shipmentID}
	assessAgent, err := newAgent(assessModel, source, &drafts)
	if err != nil {
		return outcome{err: err}, outcome{err: err}
	}
	assess, err := assessAgent.Run(ctx, agent.Session{ID: sessionID},
		"Assess shipment shipment-100 and report whether a reroute is needed.")
	if err != nil {
		return outcome{err: err, reads: source.reads, drafts: drafts}, outcome{err: err}
	}
	assessMessages := transcript(assessModel, assess.Output)
	_ = store.save(&checkpoint.Checkpoint{
		ID:        "cp-1",
		SessionID: sessionID,
		RunID:     assess.RunID,
		Version:   1,
		Status:    "awaiting_approval",
		TenantID:  "local",
		Messages:  toCheckpoint(assessMessages),
		CreatedAt: time.Unix(0, 0).UTC(),
	})

	loaded, err := store.load(sessionID)
	if err != nil || loaded == nil {
		return outcome{err: err, reads: source.reads, drafts: drafts}, outcome{err: err}
	}
	first := outcome{stage: stageOf(assess.Output), reads: source.reads, drafts: drafts, cpCount: len(loaded.Messages)}
	resumeModel := &fixtureModel{shipment: shipmentID}
	resumeAgent, err := newAgent(resumeModel, source, &drafts)
	if err != nil {
		return outcome{err: err, reads: source.reads, drafts: drafts}, outcome{err: err}
	}
	resumed, err := resumeAgent.Run(ctx, agent.Session{ID: sessionID, Messages: toModel(loaded.Messages)},
		"Resume: draft the approved reroute for shipment-100.")
	if err != nil {
		return outcome{err: err, reads: source.reads, drafts: drafts}, outcome{err: err}
	}
	resumeMessages := transcript(resumeModel, resumed.Output)
	_ = store.save(&checkpoint.Checkpoint{
		ID:        "cp-2",
		SessionID: sessionID,
		RunID:     resumed.RunID,
		Version:   2,
		Status:    "reroute_drafted",
		TenantID:  "local",
		Messages:  toCheckpoint(resumeMessages),
		CreatedAt: time.Unix(1, 0).UTC(),
	})

	finalCP, _ := store.load(sessionID)
	second := outcome{stage: stageOf(resumed.Output), reads: source.reads, drafts: drafts}
	if finalCP != nil {
		second.cpCount = len(finalCP.Messages)
	}
	return first, second
}

func stageOf(output string) string {
	var report map[string]any
	if err := json.Unmarshal([]byte(output), &report); err != nil {
		return ""
	}
	stage, _ := report["stage"].(string)
	return stage
}

func runTests(ctx context.Context, stdout io.Writer) error {
	assess, resumed := runWorkflow(ctx, false)
	if assess.err != nil || resumed.err != nil {
		return fmt.Errorf("workflow failed: assess=%v resume=%v", assess.err, resumed.err)
	}
	if assess.stage != "assessed" || assess.reads != 1 || assess.drafts != 0 {
		return fmt.Errorf("assess verification failed: %+v", assess)
	}
	if resumed.stage != "reroute_drafted" || resumed.reads != 1 || resumed.drafts != 1 {
		return fmt.Errorf("resume verification failed: %+v", resumed)
	}
	if resumed.reads != 1 {
		return fmt.Errorf("resume re-read shipment: reads=%d", resumed.reads)
	}
	if resumed.cpCount <= assess.cpCount {
		return fmt.Errorf("checkpoint did not grow: before=%d after=%d", assess.cpCount, resumed.cpCount)
	}
	fmt.Fprintln(stdout, "assess: shipment-100 stage=assessed reads=1 drafts=0")
	fmt.Fprintln(stdout, "resume: shipment-100 stage=reroute_drafted reads=1 drafts=1 route_writes=0")
	fmt.Fprintln(stdout, "checkpoint: restored and extended without re-reading")

	failedAssess, _ := runWorkflow(ctx, true)
	if failedAssess.err == nil || failedAssess.reads != 1 {
		return fmt.Errorf("failure path wrong: %+v", failedAssess)
	}
	fmt.Fprintln(stdout, "failure: SHIPMENT_SOURCE_UNAVAILABLE reads=1")
	return nil
}

func main() {
	testMode := flag.Bool("test", false, "run the deterministic tutorial checks")
	simulateFailure := flag.Bool("simulate-failure", false, "make the shipment source fail")
	flag.Parse()

	ctx := context.Background()
	if *testMode {
		if err := runTests(ctx, os.Stdout); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		return
	}

	assess, resumed := runWorkflow(ctx, *simulateFailure)
	if assess.err != nil {
		fmt.Fprintf(os.Stderr, "error: %v reads=%d\n", assess.err, assess.reads)
		os.Exit(1)
	}
	fmt.Printf("assess stage: %s\n", assess.stage)
	if resumed.err == nil {
		fmt.Printf("resume stage: %s\n", resumed.stage)
	}
}
