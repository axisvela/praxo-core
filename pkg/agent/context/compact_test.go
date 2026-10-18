package agentcontext

import (
	"strings"
	"testing"

	"github.com/axisvela/praxo-core/pkg/model"
)

func TestCompactUnderBudgetUnchanged(t *testing.T) {
	msgs := []model.Message{{Role: model.RoleUser, Content: "short"}}
	out, ok := ContextBudget{MaxTokens: 1000}.Compact(msgs)
	if !ok {
		t.Fatal("unexpected budget failure")
	}
	if len(out) != 1 || out[0].Content != "short" {
		t.Fatalf("out = %+v", out)
	}
}

func TestCompactDropsOldMessages(t *testing.T) {
	msgs := []model.Message{
		{Role: model.RoleSystem, Content: strings.Repeat("s", 400)},
	}
	for i := 0; i < 10; i++ {
		msgs = append(msgs, model.Message{Role: model.RoleUser, Content: strings.Repeat("u", 400)})
	}
	out, ok := ContextBudget{MaxTokens: 250, KeepRecent: 2}.Compact(msgs)
	if !ok {
		t.Fatal("unexpected budget failure")
	}
	if len(out) >= len(msgs) {
		t.Fatalf("compaction kept %d messages, want fewer than %d", len(out), len(msgs))
	}
	found := false
	for _, m := range out {
		if m.Role == model.RoleSystem && strings.HasPrefix(m.Content, compactMarkerPrefix) {
			found = true
		}
	}
	if !found {
		t.Fatal("compaction marker missing")
	}
	if out[len(out)-1].Content != strings.Repeat("u", 400) {
		t.Fatal("last message was not preserved")
	}
}

func TestCompactPreservesToolPair(t *testing.T) {
	msgs := []model.Message{
		{Role: model.RoleAssistant, ToolCalls: []model.ToolCall{{ID: "t1", Name: "echo"}}},
		{Role: model.RoleTool, ToolID: "t1", Content: strings.Repeat("r", 400)},
	}
	out, ok := ContextBudget{MaxTokens: 120, KeepRecent: 1}.Compact(msgs)
	if !ok {
		t.Fatal("unexpected budget failure")
	}
	if len(out) != 2 {
		t.Fatalf("compaction split a tool pair: %+v", out)
	}
	if out[0].Role != model.RoleAssistant || out[1].Role != model.RoleTool {
		t.Fatalf("tool pair order changed: %+v", out)
	}
}

func TestCompactKeepsFirstSystemAndDropsOthers(t *testing.T) {
	msgs := []model.Message{
		{Role: model.RoleSystem, Content: strings.Repeat("a", 400)},
		{Role: model.RoleSystem, Content: strings.Repeat("b", 400)},
		{Role: model.RoleUser, Content: "hi"},
	}
	out, ok := ContextBudget{MaxTokens: 150, KeepRecent: 2}.Compact(msgs)
	if !ok {
		t.Fatal("unexpected budget failure")
	}
	system := 0
	for _, m := range out {
		if m.Role == model.RoleSystem && !strings.HasPrefix(m.Content, compactMarkerPrefix) {
			system++
		}
	}
	if system != 1 {
		t.Fatalf("system messages = %d, want 1: %+v", system, out)
	}
}

func TestCompactFailsWhenSystemCannotFit(t *testing.T) {
	msgs := []model.Message{{Role: model.RoleSystem, Content: strings.Repeat("x", 1000)}}
	if _, ok := (ContextBudget{MaxTokens: 3}).Compact(msgs); ok {
		t.Fatal("compaction reported success for an impossible budget")
	}
}
