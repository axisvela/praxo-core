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

const matterID = "matter-100"

var errDocUnavailable = errors.New("DOCUMENT_INDEX_UNAVAILABLE")

type DocumentSource interface {
	Timeline(ctx context.Context, matter string) (map[string]any, error)
}

type fixtureDocumentSource struct {
	simulateFailure bool
	reads           int
}

func (s *fixtureDocumentSource) Timeline(_ context.Context, matter string) (map[string]any, error) {
	s.reads++
	if s.simulateFailure {
		return nil, errDocUnavailable
	}
	return map[string]any{
		"matter_id": matter,
		"documents": 3,
		"events":    4,
		"contradictions": []any{
			map[string]any{"id": "c-1", "between": []any{"doc-1", "doc-3"}},
		},
		"source": "document_fixture",
	}, nil
}

type readDocumentsTool struct{ source DocumentSource }

func (readDocumentsTool) Name() string { return "read_documents" }

func (readDocumentsTool) Description() string {
	return "Build a cited timeline from fixed synthetic documents; no legal advice."
}

func (readDocumentsTool) Spec() model.ToolSpec {
	return model.ToolSpec{
		Name:        "read_documents",
		Description: "Build a cited timeline from fixed synthetic documents.",
		Parameters: map[string]any{
			"type":       "object",
			"properties": map[string]any{"matter_id": map[string]any{"type": "string"}},
		},
	}
}

func (t readDocumentsTool) Invoke(ctx context.Context, args map[string]any) (any, error) {
	id, _ := args["matter_id"].(string)
	if id == "" {
		id = matterID
	}
	return t.source.Timeline(ctx, id)
}

type draftOutlineTool struct{ calls *int }

func (draftOutlineTool) Name() string { return "draft_outline" }

func (draftOutlineTool) Description() string {
	return "Draft a review-only evidence outline; never gives legal advice."
}

func (draftOutlineTool) Spec() model.ToolSpec {
	return model.ToolSpec{
		Name:        "draft_outline",
		Description: "Draft a review-only evidence outline.",
		Parameters: map[string]any{
			"type": "object",
			"properties": map[string]any{
				"matter_id": map[string]any{"type": "string"},
				"action":    map[string]any{"type": "string"},
			},
		},
	}
}

func (t draftOutlineTool) Invoke(_ context.Context, args map[string]any) (any, error) {
	*t.calls++
	id, _ := args["matter_id"].(string)
	if id == "" {
		id = matterID
	}
	action, _ := args["action"].(string)
	if action == "" {
		action = "draft_timeline"
	}
	return map[string]any{
		"outline_id":        "timeline-100",
		"matter_id":         id,
		"action":            action,
		"timeline_events":   4,
		"flagged":           1,
		"status":            "draft_only",
		"review_required":   true,
		"legal_advice":      0,
		"admissibility":     0,
	}, nil
}

type fixtureModel struct{ matter string }

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
				Name:      "read_documents",
				Arguments: map[string]any{"matter_id": m.matter},
			}},
		}}, nil
	case 1:
		return model.Response{Message: model.Message{
			Role: model.RoleAssistant,
			ToolCalls: []model.ToolCall{{
				ID:   "outline-1",
				Name: "draft_outline",
				Arguments: map[string]any{
					"matter_id": m.matter,
					"action":    "draft_timeline",
				},
			}},
		}}, nil
	default:
		var documents any
		var outline any
		_ = json.Unmarshal([]byte(toolMessages[0].Content), &documents)
		_ = json.Unmarshal([]byte(toolMessages[1].Content), &outline)
		report := map[string]any{
			"documents":    documents,
			"outline":      outline,
			"policy":       "timeline and outline draft only; legal advice remains application-owned",
			"legal_advice": 0,
			"admissibility": 0,
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

func runScenario(ctx context.Context, matter string, simulateFailure bool) outcome {
	source := &fixtureDocumentSource{simulateFailure: simulateFailure}
	draftCalls := 0

	tools := tool.NewRegistry()
	tools.Register(readDocumentsTool{source: source})
	tools.Register(draftOutlineTool{calls: &draftCalls})

	ag, err := agent.New(agent.Options{
		Model:            &fixtureModel{matter: matter},
		SystemPrompt:     "You build a cited evidence timeline for one fixed matter. Read and draft only.",
		Tools:            tools,
		MaxSteps:         5,
		AllowedTools:     []string{"read_documents", "draft_outline"},
		RequirePolicy:    true,
		RequireToolScope: true,
		Policy: policy.FuncHook(func(_ context.Context, action policy.Action) (policy.Decision, error) {
			if action.Kind == "model.generate" {
				return policy.Decision{Allowed: true, Reason: "deterministic timeline"}, nil
			}
			if action.Kind != "tool.invoke" {
				return policy.Decision{Allowed: false, Reason: "unsupported action"}, nil
			}
			inScope, _ := action.Arguments["matter_id"].(string)
			allowed := inScope == matterID
			switch action.ToolName {
			case "read_documents":
				return policy.Decision{Allowed: allowed, Reason: "only matter-100 is in scope"}, nil
			case "draft_outline":
				act, _ := action.Arguments["action"].(string)
				return policy.Decision{Allowed: allowed && act == "draft_timeline", Reason: "only a review-only timeline draft is allowed"}, nil
			}
			return policy.Decision{Allowed: false, Reason: "unknown tool"}, nil
		}),
	})
	if err != nil {
		return outcome{err: err, reads: source.reads, drafts: draftCalls}
	}

	result, runErr := ag.Run(ctx, agent.Session{
		ID:          "go-litigation-timeline",
		TenantID:    "local",
		WorkspaceID: "default",
	}, "Build the fixed evidence timeline and draft a review-only outline.")
	got := outcome{reads: source.reads, drafts: draftCalls}
	if runErr != nil {
		got.err = runErr
		return got
	}
	got.output = result.Output
	return got
}

func runTests(ctx context.Context, stdout io.Writer) error {
	success := runScenario(ctx, matterID, false)
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
	documents, _ := report["documents"].(map[string]any)
	outline, _ := report["outline"].(map[string]any)
	contradictions, _ := documents["contradictions"].([]any)
	if len(contradictions) != 1 || outline["status"] != "draft_only" ||
		outline["timeline_events"] != float64(4) || outline["flagged"] != float64(1) ||
		outline["legal_advice"] != float64(0) || report["legal_advice"] != float64(0) {
		return fmt.Errorf("success verification failed: documents=%v outline=%v", documents, outline)
	}
	fmt.Fprintln(stdout, "success: matter-100 documents=3 events=4 contradictions=1 status=draft_only advice=0 reads=1")

	denied := runScenario(ctx, "matter-200", false)
	if denied.err == nil || denied.reads != 0 || denied.drafts != 0 {
		return fmt.Errorf("deny verification failed: reads=%d drafts=%d err=%v", denied.reads, denied.drafts, denied.err)
	}
	fmt.Fprintln(stdout, "deny: policy denied reads=0")

	failure := runScenario(ctx, matterID, true)
	if !errors.Is(failure.err, errDocUnavailable) || failure.reads != 1 || failure.drafts != 0 {
		return fmt.Errorf("failure verification failed: reads=%d err=%v", failure.reads, failure.err)
	}
	fmt.Fprintln(stdout, "failure: DOCUMENT_INDEX_UNAVAILABLE reads=1")
	return nil
}

func main() {
	testMode := flag.Bool("test", false, "run the deterministic tutorial checks")
	matter := flag.String("matter", matterID, "litigation matter id")
	simulateFailure := flag.Bool("simulate-failure", false, "make the document index fail")
	flag.Parse()

	ctx := context.Background()
	if *testMode {
		if err := runTests(ctx, os.Stdout); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		return
	}

	got := runScenario(ctx, *matter, *simulateFailure)
	if got.err != nil {
		fmt.Fprintf(os.Stderr, "error: %v reads=%d\n", got.err, got.reads)
		os.Exit(1)
	}
	fmt.Fprintln(os.Stdout, got.output)
	fmt.Fprintf(os.Stdout, "reads=%d\n", got.reads)
}
