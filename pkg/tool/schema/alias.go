// Package jsonschema is the deprecated path: use pkg/tool/jsonschema.
package jsonschema

import js "github.com/axisvela/praxo-core/pkg/tool/jsonschema"

// Schema is a minimal JSON Schema validator.
type Schema = js.Schema

// ValidationError describes a schema validation failure.
type ValidationError = js.ValidationError

// FromJSON parses a JSON Schema from raw JSON.
func FromJSON(data []byte) (*Schema, error) { return js.FromJSON(data) }

// SchemaForTool generates a JSON Schema from a Go struct type.
func SchemaForTool(v any) (*Schema, error) { return js.SchemaForTool(v) }
