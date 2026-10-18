package agent

import (
	"context"
	"testing"

	"github.com/axisvela/praxo-core/v2/pkg/model"
)

type captureModel struct {
	messages []model.Message
}

func (m *captureModel) Generate(_ context.Context, req model.Request) (model.Response, error) {
	m.messages = append([]model.Message(nil), req.Messages...)
	return model.Response{Message: model.Message{Content: "done"}}, nil
}

func TestRunResumesFromSessionMessages(t *testing.T) {
	capture := &captureModel{}
	ag := &Agent{Model: capture, MaxSteps: 2}
	session := Session{ID: "s", Messages: []model.Message{
		{Role: model.RoleUser, Content: "previous question"},
		{Role: model.RoleAssistant, Content: "previous answer"},
	}}
	if _, err := ag.Run(context.Background(), session, "next question"); err != nil {
		t.Fatal(err)
	}
	if len(capture.messages) != 3 {
		t.Fatalf("messages = %+v", capture.messages)
	}
	if capture.messages[0].Content != "previous question" || capture.messages[2].Content != "next question" {
		t.Fatalf("resume order = %+v", capture.messages)
	}
}
