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

func TestNilFailsTypedSchema(t *testing.T) {
	if errs := (&Schema{Type: "string"}).Validate(nil); len(errs) != 1 {
		t.Fatalf("errors = %+v", errs)
	}
	if errs := (&Schema{}).Validate(nil); len(errs) != 0 {
		t.Fatalf("untyped schema errors = %+v", errs)
	}
}

func TestIntegerRejectsFractions(t *testing.T) {
	s := &Schema{Type: "integer"}
	if errs := s.Validate(float64(2)); len(errs) != 0 {
		t.Fatalf("integer 2 errors = %+v", errs)
	}
	if errs := s.Validate(float64(2.5)); len(errs) != 1 {
		t.Fatalf("fraction errors = %+v", errs)
	}
}

func TestEnumUsesTypedEquality(t *testing.T) {
	number := &Schema{Type: "number", Enum: []any{float64(1), float64(2)}}
	if errs := number.Validate(float64(2)); len(errs) != 0 {
		t.Fatalf("legal number errors = %+v", errs)
	}
	if errs := number.Validate(float64(3)); len(errs) != 1 {
		t.Fatalf("illegal number errors = %+v", errs)
	}
	boolean := &Schema{Type: "boolean", Enum: []any{true}}
	if errs := boolean.Validate(true); len(errs) != 0 {
		t.Fatalf("legal boolean errors = %+v", errs)
	}
	if errs := boolean.Validate(false); len(errs) != 1 {
		t.Fatalf("illegal boolean errors = %+v", errs)
	}
}

func TestPatternUsesRegularExpressions(t *testing.T) {
	s := &Schema{Type: "string", Pattern: `^a+$`}
	if errs := s.Validate("aaa"); len(errs) != 0 {
		t.Fatalf("matching errors = %+v", errs)
	}
	if errs := s.Validate("baaa"); len(errs) != 1 {
		t.Fatalf("non-matching errors = %+v", errs)
	}
	invalid := &Schema{Type: "string", Pattern: `(`}
	if errs := invalid.Validate("a"); len(errs) != 1 {
		t.Fatalf("invalid pattern errors = %+v", errs)
	}
}

func TestLengthCountsRunes(t *testing.T) {
	s := &Schema{Type: "string", MinLength: 2, MaxLength: 2}
	if errs := s.Validate("你好"); len(errs) != 0 {
		t.Fatalf("two rune errors = %+v", errs)
	}
	if errs := s.Validate("你"); len(errs) != 1 {
		t.Fatalf("one rune errors = %+v", errs)
	}
}
