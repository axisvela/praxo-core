package consumer_test

import (
	"testing"

	"github.com/axisvela/praxo-core/v2/pkg/tool/jsonschema"
)

func TestPublishedJSONSchemaSubset(t *testing.T) {
	if errs := (&jsonschema.Schema{Type: "string"}).Validate(nil); len(errs) != 1 {
		t.Fatalf("typed null errors = %+v", errs)
	}
	if errs := (&jsonschema.Schema{Type: "integer"}).Validate(1.5); len(errs) != 1 {
		t.Fatalf("fraction errors = %+v", errs)
	}
	if errs := (&jsonschema.Schema{Type: "string", Pattern: `^a+$`}).Validate("baa"); len(errs) != 1 {
		t.Fatalf("regex pattern errors = %+v", errs)
	}
	if errs := (&jsonschema.Schema{Type: "string", MinLength: 2}).Validate("你"); len(errs) != 1 {
		t.Fatalf("rune length errors = %+v", errs)
	}
	if errs := (&jsonschema.Schema{Type: "boolean", Enum: []any{true}}).Validate(false); len(errs) != 1 {
		t.Fatalf("boolean enum errors = %+v", errs)
	}
}
