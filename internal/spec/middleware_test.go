package spec

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"reflect"

	agentmiddleware "github.com/axisvela/praxo-core/v2/pkg/agent/middleware"
	agenttypes "github.com/axisvela/praxo-core/v2/pkg/agent/types"
	"github.com/axisvela/praxo-core/v2/pkg/model"
)

type modelFunc func(context.Context, model.Request) (model.Response, error)

func (f modelFunc) Generate(ctx context.Context, req model.Request) (model.Response, error) {
	return f(ctx, req)
}

type fixedSelector struct {
	names []string
}

func (s fixedSelector) Select(_ context.Context, _ string, _ []model.ToolSpec) ([]string, error) {
	return s.names, nil
}

func runMiddleware(v vectorCase) error {
	var in struct {
		Operation       string         `json:"operation"`
		Text            string         `json:"text"`
		Value           any            `json:"value"`
		Schema          map[string]any `json:"schema"`
		Output          string         `json:"output"`
		MaxRepairs      int            `json:"maxRepairs"`
		RepairOutput    string         `json:"repairOutput"`
		ModelLimit      int            `json:"modelLimit"`
		ToolLimit       int            `json:"toolLimit"`
		Calls           []string       `json:"calls"`
		Selected        []string       `json:"selected"`
		Tools           []string       `json:"tools"`
		Requested       string         `json:"requested"`
		FallbackContent string         `json:"fallbackContent"`
	}
	var exp struct {
		Text       string   `json:"text"`
		Value      any      `json:"value"`
		OK         bool     `json:"ok"`
		Output     string   `json:"output"`
		ErrorCode  string   `json:"errorCode"`
		Outcomes   []string `json:"outcomes"`
		Advertised []string `json:"advertised"`
		Reject     string   `json:"reject"`
	}
	if err := json.Unmarshal(v.Input, &in); err != nil {
		return err
	}
	if err := json.Unmarshal(v.Expect, &exp); err != nil {
		return err
	}
	ctx := context.Background()

	switch in.Operation {
	case "pii":
		redactor := agentmiddleware.NewPIIRedactor(agentmiddleware.DefaultPIIRules()...)
		if got := redactor.Redact(in.Text); got != exp.Text {
			return fmt.Errorf("text: got %q want %q", got, exp.Text)
		}
		return nil
	case "pii-value":
		redactor := agentmiddleware.NewPIIRedactor(agentmiddleware.DefaultPIIRules()...)
		mw := agentmiddleware.PIIMiddleware(redactor)
		result := &agenttypes.ToolResult{Value: in.Value}
		if err := mw.AfterTool(ctx, &agenttypes.ToolCall{}, result); err != nil {
			return err
		}
		if !reflect.DeepEqual(result.Value, exp.Value) {
			return fmt.Errorf("value: got %#v want %#v", result.Value, exp.Value)
		}
		return nil
	case "structured":
		so := agentmiddleware.StructuredOutput{
			Schema:     in.Schema,
			MaxRepairs: in.MaxRepairs,
		}
		if in.RepairOutput != "" {
			so.Repair = func(context.Context, string, error) (string, error) {
				return in.RepairOutput, nil
			}
		}
		result := &agenttypes.Result{Output: in.Output}
		err := so.Middleware().AfterRun(ctx, result, nil)
		if err != nil {
			if exp.OK {
				return fmt.Errorf("expected valid output: %w", err)
			}
			if code := middlewareCode(err); code != exp.ErrorCode {
				return fmt.Errorf("errorCode: got %q want %q", code, exp.ErrorCode)
			}
			return nil
		}
		if !exp.OK {
			return errors.New("expected a structured output error")
		}
		if result.Output != exp.Output {
			return fmt.Errorf("output: got %q want %q", result.Output, exp.Output)
		}
		return nil
	case "call-limit":
		mw := agentmiddleware.CallLimitMiddleware(in.ModelLimit, in.ToolLimit)
		if err := mw.BeforeRun(ctx, &agenttypes.RunState{RunID: "r1"}); err != nil {
			return err
		}
		got := make([]string, 0, len(in.Calls))
		for _, kind := range in.Calls {
			var err error
			switch kind {
			case "model":
				err = mw.BeforeModel(ctx, &agenttypes.ModelCall{RunID: "r1"})
			case "tool":
				err = mw.BeforeTool(ctx, &agenttypes.ToolCall{RunID: "r1"})
			default:
				return fmt.Errorf("unknown call kind %q", kind)
			}
			got = append(got, middlewareCode(err))
		}
		if !reflect.DeepEqual(got, exp.Outcomes) {
			return fmt.Errorf("outcomes: got %v want %v", got, exp.Outcomes)
		}
		return nil
	case "tool-selection":
		mw := agentmiddleware.ToolSelectionMiddleware(fixedSelector{names: in.Selected})
		specs := make([]model.ToolSpec, len(in.Tools))
		for i, name := range in.Tools {
			specs[i] = model.ToolSpec{Name: name}
		}
		call := &agenttypes.ModelCall{
			RunID:   "r1",
			Request: &model.Request{Tools: specs},
		}
		if err := mw.BeforeModel(ctx, call); err != nil {
			return err
		}
		advertised := make([]string, len(call.Request.Tools))
		for i, spec := range call.Request.Tools {
			advertised[i] = spec.Name
		}
		if !reflect.DeepEqual(advertised, exp.Advertised) {
			return fmt.Errorf("advertised: got %v want %v", advertised, exp.Advertised)
		}
		err := mw.BeforeTool(ctx, &agenttypes.ToolCall{
			RunID: "r1",
			Call:  &model.ToolCall{Name: in.Requested},
		})
		if code := middlewareCode(err); code != exp.Reject {
			return fmt.Errorf("reject: got %q want %q", code, exp.Reject)
		}
		return nil
	case "fallback":
		fallback := modelFunc(func(context.Context, model.Request) (model.Response, error) {
			return model.Response{
				Message: model.Message{
					Role:    model.RoleAssistant,
					Content: in.FallbackContent,
				},
			}, nil
		})
		next := func(context.Context, model.Request) (model.Response, error) {
			return model.Response{}, errors.New("primary failed")
		}
		resp, err := agentmiddleware.FallbackModel(fallback)(next)(ctx, model.Request{})
		if err != nil {
			return err
		}
		if resp.Message.Content != exp.Output {
			return fmt.Errorf("output: got %q want %q", resp.Message.Content, exp.Output)
		}
		return nil
	default:
		return fmt.Errorf("unknown middleware operation %q", in.Operation)
	}
}

func middlewareCode(err error) string {
	switch {
	case err == nil:
		return "ok"
	case errors.Is(err, agentmiddleware.ErrModelCallLimit):
		return "AGENT_MODEL_CALL_LIMIT"
	case errors.Is(err, agentmiddleware.ErrToolCallLimit):
		return "AGENT_TOOL_CALL_LIMIT"
	case errors.Is(err, agentmiddleware.ErrToolNotSelected):
		return "AGENT_TOOL_NOT_SELECTED"
	case errors.Is(err, agentmiddleware.ErrStructuredOutput):
		return "AGENT_STRUCTURED_OUTPUT"
	default:
		return "ERROR"
	}
}
