package output

import (
	"strings"
	"testing"
)

func TestParseDSMLSingularAndStrip(t *testing.T) {
	content := `<｜｜DSML｜｜tool_call name="fs.list">{"path":"."}</｜｜DSML｜｜tool_call>`
	call := ParseToolCall(content)
	if call == nil || call.Name != "fs.list" || call.Input["path"] != "." {
		t.Fatalf("call = %+v", call)
	}
	if call.CallID == "" {
		t.Fatal("missing call id")
	}
	stripped := StripToolCallMarkup(content)
	if strings.Contains(stripped, "DSML") || strings.Contains(stripped, "tool_call") {
		t.Fatalf("stripped = %q", stripped)
	}
}

func TestParseXMLAndPlain(t *testing.T) {
	xml := `<tool_call name="doc.parse"> {"path": ".docs\\a.docx"} </tool_call>`
	call := ParseToolCall(xml)
	if call == nil || call.Name != "doc.parse" {
		t.Fatalf("xml call = %+v", call)
	}

	plain := "skill.research {\"query\":\"2026 trends\",\"sources\":[\"news\"]}"
	call = ParseToolCall(plain)
	if call == nil || call.Name != "skill.research" || call.Input["query"] != "2026 trends" {
		t.Fatalf("plain call = %+v", call)
	}
}

func TestParseInvokeTagTodo(t *testing.T) {
	invoke := `<tool_call_invoke><tool_name>doc.parse</tool_name><parameters actual="{\"path\":\"a.docx\"}"></parameters></tool_call_invoke>`
	if call := ParseToolCall(invoke); call == nil || call.Name != "doc.parse" || call.Input["path"] != "a.docx" {
		t.Fatalf("invoke call = %+v", call)
	}

	tag := `<fs.list>{"path":"."}</fs.list>`
	if call := ParseToolCall(tag); call == nil || call.Name != "fs.list" {
		t.Fatalf("tag call = %+v", call)
	}

	todo := `<todo_create>{"title":"write tests"}</todo_create>`
	if call := ParseToolCall(todo); call == nil || call.Name != "todo.create" || call.Input["title"] != "write tests" {
		t.Fatalf("todo call = %+v", call)
	}
}

func TestParseSkillInstall(t *testing.T) {
	content := `<skill.install url="https://example.com/skill.zip"></skill.install>`
	call := ParseToolCall(content)
	if call == nil || call.Name != "skill.install" || call.Input["url"] != "https://example.com/skill.zip" {
		t.Fatalf("call = %+v", call)
	}
}

func TestNoToolCall(t *testing.T) {
	if call := ParseToolCall("just a normal answer"); call != nil {
		t.Fatalf("unexpected call = %+v", call)
	}
}
