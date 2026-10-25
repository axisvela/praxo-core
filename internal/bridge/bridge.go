package bridge

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"strconv"

	"github.com/axisvela/praxo-core/v2/adapters/openaicompat"
	"github.com/axisvela/praxo-core/v2/pkg/agent"
	"github.com/axisvela/praxo-core/v2/pkg/event"
	"github.com/axisvela/praxo-core/v2/pkg/plugin"
	"github.com/axisvela/praxo-core/v2/pkg/tool/jsonschema"
	"github.com/axisvela/praxo-core/v2/pkg/toolcall"
)

const (
	SDKVersion  = "0.1.0"
	SpecVersion = "0.2.0"
)

type UsageError struct {
	Message string
}

func (e *UsageError) Error() string { return e.Message }

type ContractError struct {
	Code    string
	Message string
}

func (e *ContractError) Error() string { return e.Message }

func Run(args []string, input []byte) (any, error) {
	return RunWithEmitter(args, input, nil)
}

func RunWithEmitter(args []string, input []byte, emit func(any)) (any, error) {
	if len(args) == 0 {
		return nil, &UsageError{Message: usage()}
	}
	switch args[0] {
	case "version":
		return version()
	case "toolcall":
		return toolcallCommand(args[1:], input)
	case "jsonschema":
		return jsonschemaCommand(args[1:], input)
	case "plugin":
		return pluginCommand(args[1:], input)
	case "tool":
		return toolCommand(args[1:], input)
	case "run":
		return runCommand(args[1:], input, emit)
	case "event":
		return eventCommand(args[1:], input, emit)
	default:
		return nil, &UsageError{Message: usage()}
	}
}

func toolCommand(args []string, input []byte) (any, error) {
	if len(args) != 1 || args[0] != "list" {
		return nil, &UsageError{Message: "tool requires list"}
	}
	if len(input) > 0 {
		var request struct {
			Tools []any `json:"tools"`
		}
		if err := decode(input, &request); err != nil {
			return nil, err
		}
	}
	return map[string]any{"tools": []any{}}, nil
}

type runInput struct {
	Prompt    string `json:"prompt"`
	SessionID string `json:"sessionId"`
	MaxSteps  int    `json:"maxSteps"`
}

func runCommand(args []string, input []byte, emit func(any)) (any, error) {
	if len(args) != 0 {
		return nil, &UsageError{Message: "run takes no subcommand"}
	}
	var request runInput
	if err := decode(input, &request); err != nil {
		return nil, err
	}
	if request.Prompt == "" {
		return nil, &UsageError{Message: "run requires prompt"}
	}
	sessionID := request.SessionID
	if sessionID == "" {
		sessionID = "bridge"
	}
	model, err := bridgeModel()
	if err != nil {
		return nil, err
	}
	maxSteps := request.MaxSteps
	if maxSteps == 0 {
		maxSteps = envInt("PRAXO_MAX_STEPS", 8)
	}
	ag, err := agent.New(agent.Options{
		Model:    model,
		MaxSteps: maxSteps,
	})
	if err != nil {
		return nil, &ContractError{Code: "BRIDGE_CONFIG", Message: err.Error()}
	}
	result, err := ag.Run(context.Background(), agent.Session{ID: sessionID}, request.Prompt)
	if err != nil {
		return nil, &ContractError{Code: "BRIDGE_RUN", Message: err.Error()}
	}
	return result, nil
}

func eventCommand(args []string, input []byte, emit func(any)) (any, error) {
	if len(args) != 1 || args[0] != "stream" {
		return nil, &UsageError{Message: "event requires stream"}
	}
	var request runInput
	if err := decode(input, &request); err != nil {
		return nil, err
	}
	if request.Prompt == "" {
		return nil, &UsageError{Message: "event stream requires prompt"}
	}
	sessionID := request.SessionID
	if sessionID == "" {
		sessionID = "bridge"
	}
	model, err := bridgeModel()
	if err != nil {
		return nil, err
	}
	maxSteps := request.MaxSteps
	if maxSteps == 0 {
		maxSteps = envInt("PRAXO_MAX_STEPS", 8)
	}
	var events []any
	sink := &recordingSink{emit: emit, events: &events}
	ag, err := agent.New(agent.Options{
		Model:    model,
		Events:   sink,
		MaxSteps: maxSteps,
	})
	if err != nil {
		return nil, &ContractError{Code: "BRIDGE_CONFIG", Message: err.Error()}
	}
	result, runErr := ag.Run(context.Background(), agent.Session{ID: sessionID}, request.Prompt)
	if emit == nil {
		out := map[string]any{"events": events}
		if runErr != nil {
			out["error"] = map[string]any{
				"code":    "BRIDGE_RUN",
				"message": runErr.Error(),
			}
			return out, nil
		}
		out["result"] = result
		return out, nil
	}
	if runErr != nil {
		return nil, &ContractError{Code: "BRIDGE_RUN", Message: runErr.Error()}
	}
	emit(map[string]any{"type": "result", "result": result})
	return nil, nil
}

type recordingSink struct {
	emit   func(any)
	events *[]any
}

func (s *recordingSink) Emit(_ context.Context, item event.Event) error {
	*s.events = append(*s.events, item)
	if s.emit != nil {
		s.emit(item)
	}
	return nil
}

func bridgeModel() (openaicompat.Adapter, error) {
	baseURL := os.Getenv("PRAXO_BASE_URL")
	if baseURL == "" {
		return openaicompat.Adapter{}, &ContractError{
			Code:    "BRIDGE_CONFIG",
			Message: "PRAXO_BASE_URL is required",
		}
	}
	return openaicompat.Adapter{
		BaseURL: baseURL,
		APIKey:  os.Getenv("PRAXO_API_KEY"),
		Model:   os.Getenv("PRAXO_MODEL"),
	}, nil
}

func envInt(name string, fallback int) int {
	value, err := strconv.Atoi(os.Getenv(name))
	if err != nil || value <= 0 {
		return fallback
	}
	return value
}

func version() (any, error) {
	return map[string]any{
		"sdkVersion":  SDKVersion,
		"specVersion": SpecVersion,
	}, nil
}

func toolcallCommand(args []string, input []byte) (any, error) {
	if len(args) != 1 {
		return nil, &UsageError{Message: "toolcall requires parse or strip"}
	}
	var request struct {
		Content string `json:"content"`
	}
	if err := decode(input, &request); err != nil {
		return nil, err
	}
	switch args[0] {
	case "parse":
		call := toolcall.ParseToolCall(request.Content)
		if call == nil {
			return map[string]any{"call": nil}, nil
		}
		return map[string]any{
			"call": map[string]any{
				"name":  call.Name,
				"input": call.Input,
			},
		}, nil
	case "strip":
		return map[string]any{
			"text": toolcall.StripToolCallMarkup(request.Content),
		}, nil
	default:
		return nil, &UsageError{Message: "toolcall requires parse or strip"}
	}
}

func jsonschemaCommand(args []string, input []byte) (any, error) {
	if len(args) != 1 || args[0] != "validate" {
		return nil, &UsageError{Message: "jsonschema requires validate"}
	}
	var request struct {
		Schema jsonschema.Schema `json:"schema"`
		Data   any               `json:"data"`
	}
	if err := decode(input, &request); err != nil {
		return nil, err
	}
	validationErrors := request.Schema.Validate(request.Data)
	paths := make([]string, 0, len(validationErrors))
	for _, err := range validationErrors {
		paths = append(paths, err.Path)
	}
	return map[string]any{
		"valid":      len(validationErrors) == 0,
		"errorPaths": paths,
	}, nil
}

func pluginCommand(args []string, input []byte) (any, error) {
	if len(args) != 1 || args[0] != "validate" {
		return nil, &UsageError{Message: "plugin requires validate"}
	}
	var request struct {
		Raw      string         `json:"raw"`
		Manifest map[string]any `json:"manifest"`
	}
	if err := decode(input, &request); err != nil {
		return nil, err
	}
	raw := []byte(request.Raw)
	if len(raw) == 0 {
		var err error
		raw, err = json.Marshal(request.Manifest)
		if err != nil {
			return nil, &ContractError{
				Code:    "BRIDGE_JSON",
				Message: err.Error(),
			}
		}
	}
	manifest, err := plugin.ParseManifest(raw)
	if err != nil {
		return map[string]any{
			"valid": false,
			"error": map[string]any{
				"code":    "PLUGIN_INVALID_MANIFEST",
				"message": err.Error(),
			},
		}, nil
	}
	return map[string]any{
		"valid": true,
		"id":    manifest.ID,
		"kind":  string(manifest.Kind),
	}, nil
}

func decode(input []byte, value any) error {
	if err := json.Unmarshal(input, value); err != nil {
		return &ContractError{
			Code:    "BRIDGE_JSON",
			Message: fmt.Sprintf("invalid JSON input: %v", err),
		}
	}
	return nil
}

func ExitCode(err error) int {
	if err == nil {
		return 0
	}
	var usage *UsageError
	if errors.As(err, &usage) {
		return 2
	}
	return 1
}

func usage() string {
	return "usage: praxo-bridge version|toolcall parse|strip|jsonschema validate|plugin validate|tool list|run|event stream"
}
