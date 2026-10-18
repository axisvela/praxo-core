package middleware

import (
	"context"
	"encoding/json"
	"regexp"

	"github.com/axisvela/praxo-core/pkg/agent/types"
	"github.com/axisvela/praxo-core/pkg/model"
)

// PIIRule is one named redaction rule.
type PIIRule struct {
	Name        string
	Pattern     *regexp.Regexp
	Replacement string
}

// NewPIIRule compiles a rule. An invalid pattern panics, matching
// regexp.MustCompile semantics.
func NewPIIRule(name, pattern, replacement string) PIIRule {
	return PIIRule{Name: name, Pattern: regexp.MustCompile(pattern), Replacement: replacement}
}

// DefaultPIIRules covers the common high-risk identifiers. Products should
// extend or replace them for their jurisdiction and data classes.
func DefaultPIIRules() []PIIRule {
	return []PIIRule{
		NewPIIRule("email", `[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}`, "[REDACTED:email]"),
		NewPIIRule("ssn", `\b\d{3}-\d{2}-\d{4}\b`, "[REDACTED:ssn]"),
		NewPIIRule("credit_card", `\b(?:\d{4}[ -]?){3}\d{4}\b`, "[REDACTED:credit_card]"),
		NewPIIRule("phone", `\b(?:\+?1[-. ]?)?\(?\d{3}\)?[-. ]?\d{3}[-. ]?\d{4}\b`, "[REDACTED:phone]"),
	}
}

// PIIRedactor applies ordered redaction rules.
type PIIRedactor struct {
	Rules []PIIRule
}

// NewPIIRedactor returns a redactor with the supplied rules.
func NewPIIRedactor(rules ...PIIRule) PIIRedactor {
	return PIIRedactor{Rules: append([]PIIRule(nil), rules...)}
}

// Redact applies every rule to text.
func (r PIIRedactor) Redact(text string) string {
	for _, rule := range r.Rules {
		if rule.Pattern == nil {
			continue
		}
		replacement := rule.Replacement
		if replacement == "" {
			replacement = "[REDACTED]"
		}
		text = rule.Pattern.ReplaceAllString(text, replacement)
	}
	return text
}

// PIIMiddleware redacts model-bound messages and tool results. It does not
// retain the original values.
func PIIMiddleware(redactor PIIRedactor) types.Middleware {
	return types.Middleware{
		Name: "pii",
		BeforeModel: func(_ context.Context, call *types.ModelCall) error {
			if call.Request == nil {
				return nil
			}
			messages := make([]model.Message, len(call.Request.Messages))
			for i, message := range call.Request.Messages {
				message.Content = redactor.Redact(message.Content)
				if len(message.ContentBlocks) > 0 {
					blocks := make([]model.ContentBlock, len(message.ContentBlocks))
					copy(blocks, message.ContentBlocks)
					for j := range blocks {
						blocks[j].Text = redactor.Redact(blocks[j].Text)
					}
					message.ContentBlocks = blocks
				}
				messages[i] = message
			}
			call.Request.Messages = messages
			return nil
		},
		AfterTool: func(_ context.Context, _ *types.ToolCall, result *types.ToolResult) error {
			result.Value = redactValue(redactor, result.Value)
			return nil
		},
	}
}

func redactValue(redactor PIIRedactor, value any) any {
	switch v := value.(type) {
	case string:
		return redactor.Redact(v)
	case []byte:
		return redactor.Redact(string(v))
	case json.RawMessage:
		return redactor.Redact(string(v))
	case map[string]any:
		out := make(map[string]any, len(v))
		for key, item := range v {
			out[key] = redactValue(redactor, item)
		}
		return out
	case []any:
		out := make([]any, len(v))
		for i, item := range v {
			out[i] = redactValue(redactor, item)
		}
		return out
	default:
		return value
	}
}
