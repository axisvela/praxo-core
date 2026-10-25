package bridge

import (
	"encoding/json"
	"errors"
	"fmt"

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
	default:
		return nil, &UsageError{Message: usage()}
	}
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
	return "usage: praxo-bridge version|toolcall parse|strip|jsonschema validate|plugin validate"
}
