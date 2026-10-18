package middleware

import (
	"context"
	"strings"
	"testing"

	"github.com/axisvela/praxo-core/pkg/agent/types"
	"github.com/axisvela/praxo-core/pkg/model"
)

func TestPIIRedactorDefaultRules(t *testing.T) {
	r := NewPIIRedactor(DefaultPIIRules()...)
	got := r.Redact("mail a@b.com ssn 123-45-6789 card 4111 1111 1111 1111")
	for _, want := range []string{"[REDACTED:email]", "[REDACTED:ssn]", "[REDACTED:credit_card]"} {
		if !strings.Contains(got, want) {
			t.Fatalf("redacted = %q, missing %s", got, want)
		}
	}
	if strings.Contains(got, "a@b.com") || strings.Contains(got, "123-45-6789") {
		t.Fatalf("secret leaked: %q", got)
	}
}

func TestPIIMiddlewareRedactsModelRequest(t *testing.T) {
	mw := PIIMiddleware(NewPIIRedactor(DefaultPIIRules()...))
	req := &model.Request{Messages: []model.Message{{Role: model.RoleUser, Content: "email a@b.com"}}}
	if err := mw.BeforeModel(context.Background(), &types.ModelCall{RunID: "r", Request: req}); err != nil {
		t.Fatal(err)
	}
	if strings.Contains(req.Messages[0].Content, "a@b.com") {
		t.Fatalf("request leaked: %q", req.Messages[0].Content)
	}
}

func TestPIIMiddlewareRedactsToolResult(t *testing.T) {
	mw := PIIMiddleware(NewPIIRedactor(DefaultPIIRules()...))
	result := &types.ToolResult{Value: map[string]any{
		"email":  "a@b.com",
		"nested": []any{"ssn 123-45-6789"},
	}}
	if err := mw.AfterTool(context.Background(), &types.ToolCall{}, result); err != nil {
		t.Fatal(err)
	}
	m := result.Value.(map[string]any)
	if strings.Contains(m["email"].(string), "a@b.com") {
		t.Fatalf("tool result leaked: %+v", m)
	}
	nested := m["nested"].([]any)
	if strings.Contains(nested[0].(string), "123-45-6789") {
		t.Fatalf("nested tool result leaked: %+v", m)
	}
}
