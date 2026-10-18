package jsonschema

import "testing"

func TestSchemaValidation(t *testing.T) {
	s := &Schema{
		Type:     "object",
		Required: []string{"path"},
		Properties: map[string]Schema{
			"path":  {Type: "string", MinLength: 1},
			"depth": {Type: "number", Minimum: 1},
		},
	}
	if errs := s.Validate(map[string]any{"path": "a", "depth": float64(2)}); len(errs) != 0 {
		t.Fatalf("unexpected errors: %+v", errs)
	}
	if errs := s.Validate(map[string]any{"depth": float64(0)}); len(errs) == 0 {
		t.Fatal("expected validation errors")
	}
}

func TestFromJSON(t *testing.T) {
	s, err := FromJSON([]byte(`{"type":"string","minLength":2}`))
	if err != nil {
		t.Fatal(err)
	}
	if errs := s.Validate("a"); len(errs) != 1 {
		t.Fatalf("errors = %+v", errs)
	}
}
