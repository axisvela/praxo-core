package middleware

import (
	"context"
	"strings"
	"testing"

	"github.com/axisvela/praxo-core/pkg/model"
)

func TestModelToolSelectorSelectsNames(t *testing.T) {
	selector := ModelToolSelector{
		Model: &stubModel{response: model.Response{Message: model.Message{Content: `{"tools":["echo","other"]}`}}},
	}
	names, err := selector.Select(context.Background(), "use echo", []model.ToolSpec{
		{Name: "echo", Description: "echo a value"},
		{Name: "other", Description: "other tool"},
	})
	if err != nil {
		t.Fatal(err)
	}
	if len(names) != 2 || names[0] != "echo" || names[1] != "other" {
		t.Fatalf("names = %+v", names)
	}
}

func TestModelToolSelectorIgnoresUnknownAndLimits(t *testing.T) {
	selector := ModelToolSelector{
		Model:    &stubModel{response: model.Response{Message: model.Message{Content: `{"tools":["echo","unknown","other"]}`}}},
		MaxTools: 1,
	}
	names, err := selector.Select(context.Background(), "q", []model.ToolSpec{{Name: "echo"}, {Name: "other"}})
	if err != nil {
		t.Fatal(err)
	}
	if len(names) != 1 || names[0] != "echo" {
		t.Fatalf("names = %+v", names)
	}
}

func TestModelToolSelectorMalformedResponse(t *testing.T) {
	selector := ModelToolSelector{Model: &stubModel{response: model.Response{Message: model.Message{Content: "not json"}}}}
	if _, err := selector.Select(context.Background(), "q", []model.ToolSpec{{Name: "echo"}}); err == nil {
		t.Fatal("expected error")
	}
}

type promptCaptureModel struct {
	prompt string
}

func (p *promptCaptureModel) Generate(_ context.Context, req model.Request) (model.Response, error) {
	if len(req.Messages) > 0 {
		p.prompt = req.Messages[len(req.Messages)-1].Content
	}
	return model.Response{Message: model.Message{Content: `{"tools":[]}`}}, nil
}

func TestModelToolSelectorIncludesQueryAndTools(t *testing.T) {
	capture := &promptCaptureModel{}
	selector := ModelToolSelector{Model: capture}
	if _, err := selector.Select(context.Background(), "find files", []model.ToolSpec{{Name: "fs.list", Description: "list files"}}); err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(capture.prompt, "find files") || !strings.Contains(capture.prompt, "fs.list") {
		t.Fatalf("prompt = %q", capture.prompt)
	}
}
