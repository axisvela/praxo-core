// Package output is deprecated: use pkg/toolcall.
package output

import tc "github.com/axisvela/praxo-core/pkg/toolcall"

// ToolCall is a parsed tool invocation.
type ToolCall = tc.ToolCall

// ParseToolCall parses the supported tool-call formats.
func ParseToolCall(content string) *ToolCall { return tc.ParseToolCall(content) }

// StripToolCallMarkup removes recognized tool-call blocks from assistant text.
func StripToolCallMarkup(content string) string { return tc.StripToolCallMarkup(content) }

// ParseInputJSON parses a JSON object, tolerating unescaped Windows paths.
func ParseInputJSON(raw string) (map[string]any, bool) { return tc.ParseInputJSON(raw) }
