package toolcall

import "testing"

func FuzzParseToolCall(f *testing.F) {
	f.Add(`<tool_call name="fs.list">{"path":"."}</tool_call>`)
	f.Add(`skill.research {"query":"x"}`)
	f.Add(`<todo_create>{"title":"x"}</todo_create>`)
	f.Add(`not a tool call`)
	f.Fuzz(func(t *testing.T, content string) {
		_ = ParseToolCall(content)
		_ = StripToolCallMarkup(content)
		_, _ = ParseInputJSON(content)
	})
}
