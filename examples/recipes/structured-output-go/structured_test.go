package structured_output_recipe

import (
	"context"
	"encoding/json"
	"fmt"
	"testing"

	"github.com/axisvela/praxo-core/v2/pkg/model"
	"github.com/axisvela/praxo-core/v2/pkg/tool"
	"github.com/axisvela/praxo-core/v2/pkg/tool/jsonschema"
)

const decisionSchema = `{
  "type": "object",
  "required": ["status"],
  "properties": {
    "status": {"type": "string", "enum": ["ok", "denied"]},
    "reason": {"type": "string", "maxLength": 120}
  }
}`

const chargeSchema = `{
  "type": "object",
  "required": ["amount"],
  "properties": {
    "amount": {"type": "integer", "minimum": 1}
  }
}`

func decode(t *testing.T, raw string) any {
	t.Helper()
	var value any
	if err := json.Unmarshal([]byte(raw), &value); err != nil {
		t.Fatal(err)
	}
	return value
}

func TestValidStructuredOutput(t *testing.T) {
	schema, err := jsonschema.FromJSON([]byte(decisionSchema))
	if err != nil {
		t.Fatal(err)
	}
	if errors := schema.Validate(decode(t, `{"status":"ok","reason":"approved"}`)); len(errors) != 0 {
		t.Fatalf("validation errors = %+v", errors)
	}
}

func TestInvalidStructuredOutput(t *testing.T) {
	schema, err := jsonschema.FromJSON([]byte(decisionSchema))
	if err != nil {
		t.Fatal(err)
	}
	if errors := schema.Validate(decode(t, `{"status":"maybe"}`)); len(errors) == 0 {
		t.Fatal("invalid enum value was accepted")
	}
	errors := schema.Validate(decode(t, `{}`))
	if len(errors) == 0 {
		t.Fatal("missing required field was accepted")
	}
	found := false
	for _, item := range errors {
		if item.Path == "$.status" {
			found = true
		}
	}
	if !found {
		t.Fatalf("errors = %+v, want $.status", errors)
	}
}

type chargeTool struct {
	calls int
}

func (t *chargeTool) Name() string        { return "charge" }
func (t *chargeTool) Description() string { return "Charge an integer amount." }

func (t *chargeTool) Spec() model.ToolSpec {
	var parameters map[string]any
	_ = json.Unmarshal([]byte(chargeSchema), &parameters)
	return model.ToolSpec{Name: t.Name(), Description: t.Description(), Parameters: parameters}
}

func (t *chargeTool) Invoke(context.Context, map[string]any) (any, error) {
	t.calls++
	return "charged", nil
}

type validatedTool struct {
	next   tool.Tool
	schema *jsonschema.Schema
}

func (t validatedTool) Name() string        { return t.next.Name() }
func (t validatedTool) Description() string { return t.next.Description() }

func (t validatedTool) Spec() model.ToolSpec {
	return t.next.(tool.SpecProvider).Spec()
}

func (t validatedTool) Invoke(ctx context.Context, args map[string]any) (any, error) {
	if errors := t.schema.Validate(args); len(errors) != 0 {
		return nil, fmt.Errorf("invalid tool arguments: %+v", errors)
	}
	return t.next.Invoke(ctx, args)
}

func TestToolArgumentsAreRejectedBeforeEffect(t *testing.T) {
	schema, err := jsonschema.FromJSON([]byte(chargeSchema))
	if err != nil {
		t.Fatal(err)
	}
	inner := &chargeTool{}
	wrapped := validatedTool{next: inner, schema: schema}

	if _, err := wrapped.Invoke(context.Background(), map[string]any{"amount": "not-an-int"}); err == nil {
		t.Fatal("invalid arguments were accepted")
	}
	if inner.calls != 0 {
		t.Fatalf("invalid arguments reached the tool: calls=%d", inner.calls)
	}
	if _, err := wrapped.Invoke(context.Background(), map[string]any{"amount": float64(10)}); err != nil {
		t.Fatal(err)
	}
	if inner.calls != 1 {
		t.Fatalf("valid arguments calls=%d, want 1", inner.calls)
	}
}

func TestResponseFormatCarriesTheSchema(t *testing.T) {
	var schemaMap map[string]any
	if err := json.Unmarshal([]byte(decisionSchema), &schemaMap); err != nil {
		t.Fatal(err)
	}
	request := model.Request{ResponseFormat: &model.ResponseFormat{Name: "decision", Schema: schemaMap}}
	if request.ResponseFormat == nil || request.ResponseFormat.Name != "decision" || request.ResponseFormat.Schema == nil {
		t.Fatalf("response format = %#v", request.ResponseFormat)
	}
}
