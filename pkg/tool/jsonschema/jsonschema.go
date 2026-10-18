// Package jsonschema provides JSON Schema validation for tool inputs and outputs.
// Reference: OpenCode's tool/json-schema.ts
package jsonschema

import (
	"encoding/json"
	"fmt"
	"reflect"
	"strings"
)

// Schema is a minimal JSON Schema validator.
type Schema struct {
	Type        string            `json:"type,omitempty"`
	Properties  map[string]Schema `json:"properties,omitempty"`
	Required    []string          `json:"required,omitempty"`
	Items       *Schema           `json:"items,omitempty"`
	Enum        []any             `json:"enum,omitempty"`
	MinLength   int               `json:"minLength,omitempty"`
	MaxLength   int               `json:"maxLength,omitempty"`
	Minimum     float64           `json:"minimum,omitempty"`
	Maximum     float64           `json:"maximum,omitempty"`
	Pattern     string            `json:"pattern,omitempty"`
	Description string            `json:"description,omitempty"`
}

// ValidationError describes a schema validation failure.
type ValidationError struct {
	Path    string `json:"path"`
	Message string `json:"message"`
}

// Validate checks if data conforms to the schema.
func (s *Schema) Validate(data any) []ValidationError {
	var errors []ValidationError
	s.validate(data, "$", &errors)
	return errors
}

func (s *Schema) validate(data any, path string, errors *[]ValidationError) {
	if data == nil {
		return
	}

	switch s.Type {
	case "object":
		m, ok := data.(map[string]any)
		if !ok {
			*errors = append(*errors, ValidationError{Path: path, Message: "expected object"})
			return
		}
		// Check required fields
		for _, req := range s.Required {
			if _, ok := m[req]; !ok {
				*errors = append(*errors, ValidationError{Path: path + "." + req, Message: "required field missing"})
			}
		}
		// Validate properties
		for key, propSchema := range s.Properties {
			if val, ok := m[key]; ok {
				propSchema.validate(val, path+"."+key, errors)
			}
		}
	case "array":
		arr, ok := data.([]any)
		if !ok {
			*errors = append(*errors, ValidationError{Path: path, Message: "expected array"})
			return
		}
		if s.Items != nil {
			for i, item := range arr {
				s.Items.validate(item, fmt.Sprintf("%s[%d]", path, i), errors)
			}
		}
	case "string":
		str, ok := data.(string)
		if !ok {
			*errors = append(*errors, ValidationError{Path: path, Message: "expected string"})
			return
		}
		if s.MinLength > 0 && len(str) < s.MinLength {
			*errors = append(*errors, ValidationError{Path: path, Message: fmt.Sprintf("min length %d, got %d", s.MinLength, len(str))})
		}
		if s.MaxLength > 0 && len(str) > s.MaxLength {
			*errors = append(*errors, ValidationError{Path: path, Message: fmt.Sprintf("max length %d, got %d", s.MaxLength, len(str))})
		}
		if s.Pattern != "" {
			if !matchPattern(s.Pattern, str) {
				*errors = append(*errors, ValidationError{Path: path, Message: fmt.Sprintf("pattern '%s' not matched", s.Pattern)})
			}
		}
		if len(s.Enum) > 0 {
			found := false
			for _, e := range s.Enum {
				if fmt.Sprint(e) == str {
					found = true
					break
				}
			}
			if !found {
				*errors = append(*errors, ValidationError{Path: path, Message: fmt.Sprintf("value not in enum: %v", s.Enum)})
			}
		}
	case "number", "integer":
		var num float64
		switch v := data.(type) {
		case float64:
			num = v
		case json.Number:
			num, _ = v.Float64()
		default:
			*errors = append(*errors, ValidationError{Path: path, Message: fmt.Sprintf("expected number, got %T", data)})
			return
		}
		if s.Minimum != 0 && num < s.Minimum {
			*errors = append(*errors, ValidationError{Path: path, Message: fmt.Sprintf("value %v below minimum %v", num, s.Minimum)})
		}
		if s.Maximum != 0 && num > s.Maximum {
			*errors = append(*errors, ValidationError{Path: path, Message: fmt.Sprintf("value %v above maximum %v", num, s.Maximum)})
		}
	case "boolean":
		if _, ok := data.(bool); !ok {
			*errors = append(*errors, ValidationError{Path: path, Message: fmt.Sprintf("expected boolean, got %T", data)})
		}
	}
}

func matchPattern(pattern, s string) bool {
	// Simple glob-like pattern matching
	return matchGlob(pattern, s)
}

func matchGlob(pattern, str string) bool {
	px, sx := 0, 0
	nextP, nextS := 0, 0
	for px < len(pattern) || sx < len(str) {
		if px < len(pattern) {
			c := pattern[px]
			switch c {
			case '*':
				nextP = px
				nextS = sx + 1
				px++
				continue
			case str[sx]:
				px++
				sx++
				continue
			}
		}
		if nextS > 0 && nextS <= len(str) {
			px = nextP
			sx = nextS
			continue
		}
		return false
	}
	return true
}

// FromJSON parses a JSON Schema from raw JSON.
func FromJSON(data []byte) (*Schema, error) {
	var s Schema
	if err := json.Unmarshal(data, &s); err != nil {
		return nil, err
	}
	return &s, nil
}

// SchemaForTool generates a JSON Schema from a Go struct type.
func SchemaForTool(v any) (*Schema, error) {
	t := reflect.TypeOf(v)
	if t.Kind() == reflect.Ptr {
		t = t.Elem()
	}
	if t.Kind() != reflect.Struct {
		return nil, fmt.Errorf("expected struct, got %s", t.Kind())
	}
	s := &Schema{Type: "object", Properties: make(map[string]Schema)}
	for i := 0; i < t.NumField(); i++ {
		f := t.Field(i)
		prop := Schema{}
		jsonTag := f.Tag.Get("json")
		if jsonTag == "" || jsonTag == "-" {
			continue
		}
		name := strings.Split(jsonTag, ",")[0]
		switch f.Type.Kind() {
		case reflect.String:
			prop.Type = "string"
		case reflect.Int, reflect.Int64, reflect.Float64:
			prop.Type = "number"
		case reflect.Bool:
			prop.Type = "boolean"
		case reflect.Slice:
			prop.Type = "array"
			if f.Type.Elem().Kind() == reflect.String {
				prop.Items = &Schema{Type: "string"}
			}
		default:
			prop.Type = "string"
		}
		if desc := f.Tag.Get("desc"); desc != "" {
			prop.Description = desc
		}
		s.Properties[name] = prop
	}
	return s, nil
}
