package middleware

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"

	"github.com/axisvela/praxo-core/pkg/agent/types"
	"github.com/axisvela/praxo-core/pkg/model"
	"github.com/axisvela/praxo-core/pkg/tool/jsonschema"
)

// StructuredOutputStrategy selects how the schema is bound to the model.
type StructuredOutputStrategy string

const (
	// StructuredOutputAuto lets the framework choose provider or tool binding.
	StructuredOutputAuto StructuredOutputStrategy = "auto"
	// StructuredOutputProvider uses the provider's response-format field.
	StructuredOutputProvider StructuredOutputStrategy = "provider"
	// StructuredOutputTool exposes the schema as a tool. Callers register
	// ToolSpec() as a tool; the middleware validates the final output.
	StructuredOutputTool StructuredOutputStrategy = "tool"
)

// ErrStructuredOutput is returned when the final output does not match the
// configured schema and repairs are exhausted.
var ErrStructuredOutput = errors.New("agent: structured output validation failed")

// StructuredOutput binds a JSON schema to a run. The middleware validates the
// final output, optionally repairs it with a model, and rewrites Result.Output.
type StructuredOutput struct {
	Name       string
	Schema     map[string]any
	Strategy   StructuredOutputStrategy
	MaxRepairs int
	// Validate overrides schema validation when set.
	Validate func(string) error
	// Repair returns a corrected output for a validation error.
	Repair func(ctx context.Context, output string, validationErr error) (string, error)
}

// ResponseFormat returns the provider-side response format for provider and
// auto strategies. Tool strategy returns nil.
func (s StructuredOutput) ResponseFormat() *model.ResponseFormat {
	if s.Strategy == StructuredOutputTool || len(s.Schema) == 0 {
		return nil
	}
	return &model.ResponseFormat{Name: s.OutputName(), Schema: s.Schema}
}

// ToolSpec returns the tool binding for tool strategy.
func (s StructuredOutput) ToolSpec() model.ToolSpec {
	return model.ToolSpec{
		Name:        s.OutputName(),
		Description: "Return the final answer as structured JSON matching the response schema.",
		Parameters:  s.Schema,
		Risk:        "low",
	}
}

// Middleware returns the validation/repair middleware for this binding.
func (s StructuredOutput) Middleware() types.Middleware {
	return types.Middleware{
		Name: "structured-output",
		BeforeModel: func(_ context.Context, call *types.ModelCall) error {
			if call.Request == nil {
				return nil
			}
			if call.Request.ResponseFormat == nil {
				call.Request.ResponseFormat = s.ResponseFormat()
			}
			if s.Strategy == StructuredOutputTool {
				for _, spec := range call.Request.Tools {
					if spec.Name == s.OutputName() {
						call.Request.ToolChoice = model.ToolChoiceRequired
						break
					}
				}
			}
			return nil
		},
		AfterRun: func(ctx context.Context, result *types.Result, runErr error) error {
			if runErr != nil || result == nil {
				return nil
			}
			return s.apply(ctx, result)
		},
	}
}

func (s StructuredOutput) apply(ctx context.Context, result *types.Result) error {
	output := result.Output
	var lastErr error
	for attempt := 0; attempt <= s.MaxRepairs; attempt++ {
		lastErr = s.validate(output)
		if lastErr == nil {
			result.Output = output
			return nil
		}
		if attempt == s.MaxRepairs || s.Repair == nil {
			break
		}
		repaired, err := s.Repair(ctx, output, lastErr)
		if err != nil {
			return err
		}
		if strings.TrimSpace(repaired) == "" {
			return fmt.Errorf("%w: repair returned empty output", ErrStructuredOutput)
		}
		output = repaired
	}
	return fmt.Errorf("%w: %v", ErrStructuredOutput, lastErr)
}

// ValidateArguments checks structured tool arguments against the schema.
func (s StructuredOutput) ValidateArguments(arguments map[string]any) error {
	if s.Validate != nil {
		encoded, err := json.Marshal(arguments)
		if err != nil {
			return err
		}
		return s.Validate(string(encoded))
	}
	schema, err := schemaFromMap(s.Schema)
	if err != nil {
		return err
	}
	if validationErrors := schema.Validate(arguments); len(validationErrors) > 0 {
		return fmt.Errorf("schema: %+v", validationErrors)
	}
	return nil
}

func (s StructuredOutput) validate(output string) error {
	if s.Validate != nil {
		return s.Validate(output)
	}
	raw, err := extractJSON(output)
	if err != nil {
		return err
	}
	var data any
	decoder := json.NewDecoder(bytes.NewReader(raw))
	decoder.UseNumber()
	if err := decoder.Decode(&data); err != nil {
		return fmt.Errorf("decode output: %w", err)
	}
	schema, err := schemaFromMap(s.Schema)
	if err != nil {
		return err
	}
	if validationErrors := schema.Validate(data); len(validationErrors) > 0 {
		return fmt.Errorf("schema: %+v", validationErrors)
	}
	return nil
}

// OutputName returns the configured or default binding name.
func (s StructuredOutput) OutputName() string {
	if strings.TrimSpace(s.Name) == "" {
		return "structured_output"
	}
	return s.Name
}

func schemaFromMap(raw map[string]any) (*jsonschema.Schema, error) {
	if len(raw) == 0 {
		return &jsonschema.Schema{}, nil
	}
	encoded, err := json.Marshal(raw)
	if err != nil {
		return nil, err
	}
	var schema jsonschema.Schema
	if err := json.Unmarshal(encoded, &schema); err != nil {
		return nil, err
	}
	return &schema, nil
}

func extractJSON(output string) ([]byte, error) {
	text := strings.TrimSpace(output)
	if text == "" {
		return nil, errors.New("empty output")
	}
	if strings.HasPrefix(text, "```") {
		if newline := strings.IndexByte(text, '\n'); newline >= 0 {
			text = text[newline+1:]
		}
		text = strings.TrimSpace(strings.TrimSuffix(strings.TrimSpace(text), "```"))
	}
	start := strings.IndexAny(text, "{[")
	if start < 0 {
		return nil, errors.New("output does not contain JSON")
	}
	text = text[start:]
	var raw json.RawMessage
	if err := json.Unmarshal([]byte(text), &raw); err != nil {
		return nil, fmt.Errorf("decode JSON: %w", err)
	}
	return raw, nil
}
