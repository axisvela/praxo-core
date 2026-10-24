// Package jsonschema provides a deliberately small JSON Schema subset for tool
// inputs and outputs. It is not a complete JSON Schema implementation.
//
// Supported keywords: type (object, array, string, number, integer, boolean),
// properties, required, items, enum, minLength, maxLength, minimum, maximum,
// pattern (Go/RE2 regular expression), and description.
//
// Unsupported keywords are ignored, including $ref, allOf, anyOf, oneOf, not,
// additionalProperties, format, default, and examples. A minimum or maximum of
// zero is treated as unset. Callers that need those keywords must validate with
// a full JSON Schema library before trusting the result. Object schemas allow
// additional properties, matching the JSON Schema default.
package jsonschema

import (
	"encoding/json"
	"fmt"
	"math"
	"reflect"
	"regexp"
	"strings"
	"unicode/utf8"
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
		if s.Type != "" {
			*errors = append(*errors, ValidationError{Path: path, Message: fmt.Sprintf("expected %s, got null", s.Type)})
		}
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
		length := utf8.RuneCountInString(str)
		if s.MinLength > 0 && length < s.MinLength {
			*errors = append(*errors, ValidationError{Path: path, Message: fmt.Sprintf("min length %d, got %d", s.MinLength, length)})
		}
		if s.MaxLength > 0 && length > s.MaxLength {
			*errors = append(*errors, ValidationError{Path: path, Message: fmt.Sprintf("max length %d, got %d", s.MaxLength, length)})
		}
		if s.Pattern != "" {
			matched, err := regexp.MatchString(s.Pattern, str)
			if err != nil {
				*errors = append(*errors, ValidationError{Path: path, Message: fmt.Sprintf("invalid pattern '%s': %v", s.Pattern, err)})
			} else if !matched {
				*errors = append(*errors, ValidationError{Path: path, Message: fmt.Sprintf("pattern '%s' not matched", s.Pattern)})
			}
		}
		if len(s.Enum) > 0 {
			found := false
			for _, e := range s.Enum {
				if reflect.DeepEqual(e, data) {
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
			var err error
			num, err = v.Float64()
			if err != nil {
				*errors = append(*errors, ValidationError{Path: path, Message: fmt.Sprintf("expected number, got %q", v)})
				return
			}
		default:
			*errors = append(*errors, ValidationError{Path: path, Message: fmt.Sprintf("expected number, got %T", data)})
			return
		}
		if s.Type == "integer" && math.Trunc(num) != num {
			*errors = append(*errors, ValidationError{Path: path, Message: fmt.Sprintf("expected integer, got %v", num)})
			return
		}
		if len(s.Enum) > 0 {
			found := false
			for _, e := range s.Enum {
				if reflect.DeepEqual(e, data) {
					found = true
					break
				}
			}
			if !found {
				*errors = append(*errors, ValidationError{Path: path, Message: fmt.Sprintf("value not in enum: %v", s.Enum)})
			}
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
			return
		}
		if len(s.Enum) > 0 {
			found := false
			for _, e := range s.Enum {
				if reflect.DeepEqual(e, data) {
					found = true
					break
				}
			}
			if !found {
				*errors = append(*errors, ValidationError{Path: path, Message: fmt.Sprintf("value not in enum: %v", s.Enum)})
			}
		}
	}
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
