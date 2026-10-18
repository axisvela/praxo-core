package prompt

import "testing"

func TestTemplateFormat(t *testing.T) {
	tpl := New("greeting", "Hello {{name}}, you are working on {{ repo }}.")
	if len(tpl.Variables) != 2 {
		t.Fatalf("variables = %+v", tpl.Variables)
	}
	out, err := tpl.Format(map[string]string{"name": "Axis", "repo": "coordivela"})
	if err != nil || out != "Hello Axis, you are working on coordivela." {
		t.Fatalf("out = %q, err = %v", out, err)
	}
}

func TestTemplateMissingVariable(t *testing.T) {
	tpl := New("greeting", "Hello {{name}}")
	if _, err := tpl.Format(nil); err == nil {
		t.Fatal("expected missing variable error")
	}
}

func TestChatTemplate(t *testing.T) {
	tpl := ChatTemplate{
		ID:     "chat",
		System: New("system", "You coordinate {{product}}."),
		Human:  New("human", "Next: {{task}}"),
	}
	system, human, err := tpl.Format(map[string]string{"product": "COORDIVELA", "task": "review"})
	if err != nil || system != "You coordinate COORDIVELA." || human != "Next: review" {
		t.Fatalf("system=%q human=%q err=%v", system, human, err)
	}
}
