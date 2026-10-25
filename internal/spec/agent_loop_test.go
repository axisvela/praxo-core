package spec

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"reflect"

	"github.com/axisvela/praxo-core/v2/pkg/agent"
	"github.com/axisvela/praxo-core/v2/pkg/model"
	"github.com/axisvela/praxo-core/v2/pkg/tool"
)

type scriptedModel struct {
	steps []agentScriptStep
	next  int
}

type agentScriptStep struct {
	Content      string           `json:"content"`
	ToolCalls    []model.ToolCall `json:"toolCalls"`
	InputTokens  int64            `json:"inputTokens"`
	OutputTokens int64            `json:"outputTokens"`
}

func (m *scriptedModel) Generate(_ context.Context, _ model.Request) (model.Response, error) {
	if m.next >= len(m.steps) {
		return model.Response{}, errors.New("spec: script exhausted")
	}
	s := m.steps[m.next]
	m.next++
	return model.Response{
		Message: model.Message{Role: model.RoleAssistant, Content: s.Content, ToolCalls: s.ToolCalls},
		Usage:   model.Usage{InputTokens: s.InputTokens, OutputTokens: s.OutputTokens},
	}, nil
}

type specTool struct {
	name  string
	desc  string
	calls *int
}

func (t *specTool) Name() string        { return t.name }
func (t *specTool) Description() string { return t.desc }

func (t *specTool) Invoke(_ context.Context, args map[string]any) (any, error) {
	*t.calls = *t.calls + 1
	return args, nil
}

func runAgentLoop(v vectorCase) error {
	type toolDef struct {
		Name        string `json:"name"`
		Description string `json:"description"`
	}
	var in struct {
		Prompt    string            `json:"prompt"`
		Script    []agentScriptStep `json:"script"`
		Tools     []toolDef         `json:"tools"`
		MaxSteps  int               `json:"maxSteps"`
		MaxTokens int64             `json:"maxTokens"`
	}
	var exp struct {
		Output          string   `json:"output"`
		Steps           int      `json:"steps"`
		Events          []string `json:"events"`
		ToolInvocations int      `json:"toolInvocations"`
		Error           bool     `json:"error"`
		ErrorCode       string   `json:"errorCode"`
	}
	if err := json.Unmarshal(v.Input, &in); err != nil {
		return err
	}
	if err := json.Unmarshal(v.Expect, &exp); err != nil {
		return err
	}

	calls := 0
	registry := tool.NewRegistry()
	for _, def := range in.Tools {
		registry.Register(&specTool{name: def.Name, desc: def.Description, calls: &calls})
	}
	sink := &recordingSink{}
	ag, err := agent.New(agent.Options{
		Model:     &scriptedModel{steps: in.Script},
		Tools:     registry,
		Events:    sink,
		MaxSteps:  in.MaxSteps,
		MaxTokens: in.MaxTokens,
	})
	if err != nil {
		return err
	}
	result, err := ag.Run(context.Background(), agent.Session{ID: "s1"}, in.Prompt)

	if exp.Error {
		if err == nil {
			return errors.New("expected an error")
		}
		if exp.ErrorCode != "" {
			switch exp.ErrorCode {
			case "AGENT_MAX_STEPS":
				if !errors.Is(err, agent.ErrMaxSteps) {
					return fmt.Errorf("error: got %v, want ErrMaxSteps", err)
				}
			case "AGENT_MAX_TOKENS":
				if !errors.Is(err, agent.ErrMaxTokens) {
					return fmt.Errorf("error: got %v, want ErrMaxTokens", err)
				}
			default:
				return fmt.Errorf("unknown error code %q", exp.ErrorCode)
			}
		}
	} else if err != nil {
		return err
	}

	if exp.Output != "" || result != nil {
		gotOutput := ""
		gotSteps := 0
		if result != nil {
			gotOutput = result.Output
			gotSteps = result.Steps
		}
		if gotOutput != exp.Output {
			return fmt.Errorf("output: got %q want %q", gotOutput, exp.Output)
		}
		if gotSteps != exp.Steps {
			return fmt.Errorf("steps: got %d want %d", gotSteps, exp.Steps)
		}
	}
	if calls != exp.ToolInvocations {
		return fmt.Errorf("tool invocations: got %d want %d", calls, exp.ToolInvocations)
	}
	gotEvents := sink.types
	if len(gotEvents) == 0 {
		gotEvents = nil
	}
	if !reflect.DeepEqual(gotEvents, exp.Events) {
		return fmt.Errorf("events: got %v want %v", gotEvents, exp.Events)
	}
	return nil
}
