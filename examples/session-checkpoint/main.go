package main

import (
	"context"
	"fmt"
	"os"

	"github.com/axisvela/praxo-core/v2/pkg/agent"
	"github.com/axisvela/praxo-core/v2/pkg/checkpoint"
	"github.com/axisvela/praxo-core/v2/pkg/model"
)

type turnModel struct{}

func (turnModel) Generate(_ context.Context, req model.Request) (model.Response, error) {
	return model.Response{Message: model.Message{
		Role:    model.RoleAssistant,
		Content: fmt.Sprintf("turn %d", len(req.Messages)),
	}}, nil
}

type memoryStore map[string]*checkpoint.Checkpoint

func (s memoryStore) save(cp *checkpoint.Checkpoint) {
	s[cp.SessionID] = cp
}

func (s memoryStore) load(sessionID string) *checkpoint.Checkpoint {
	return s[sessionID]
}

func toCheckpoint(messages []model.Message) []checkpoint.Message {
	out := make([]checkpoint.Message, 0, len(messages))
	for _, message := range messages {
		out = append(out, checkpoint.Message{Role: message.Role, Content: message.Content})
	}
	return out
}

func toModel(messages []checkpoint.Message) []model.Message {
	out := make([]model.Message, 0, len(messages))
	for _, message := range messages {
		out = append(out, model.Message{Role: message.Role, Content: message.Content})
	}
	return out
}

func main() {
	ctx := context.Background()
	store := memoryStore{}
	session := agent.Session{
		ID: "session-1",
		Messages: []model.Message{
			{Role: model.RoleUser, Content: "first"},
			{Role: model.RoleAssistant, Content: "ack"},
		},
	}
	store.save(&checkpoint.Checkpoint{
		ID: "cp-1", SessionID: session.ID, RunID: "run-1", Status: "completed",
		Messages: toCheckpoint(session.Messages),
	})

	ag, err := agent.New(agent.Options{Model: turnModel{}, MaxSteps: 2})
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}

	loaded := store.load(session.ID)
	if loaded == nil {
		fmt.Fprintln(os.Stderr, "checkpoint not found")
		os.Exit(1)
	}
	resumed := session
	resumed.Messages = toModel(loaded.Messages)
	result, err := ag.Run(ctx, resumed, "second")
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	if result.Output != "turn 3" {
		fmt.Fprintf(os.Stderr, "unexpected second turn: %q\n", result.Output)
		os.Exit(1)
	}

	resumed.Messages = append(resumed.Messages,
		model.Message{Role: model.RoleUser, Content: "second"},
		model.Message{Role: model.RoleAssistant, Content: result.Output},
	)
	store.save(&checkpoint.Checkpoint{
		ID: "cp-2", SessionID: resumed.ID, RunID: "run-2", Status: "completed",
		Messages: toCheckpoint(resumed.Messages),
	})

	loaded = store.load(session.ID)
	if loaded == nil {
		fmt.Fprintln(os.Stderr, "checkpoint not found")
		os.Exit(1)
	}
	resumed.Messages = toModel(loaded.Messages)
	result, err = ag.Run(ctx, resumed, "third")
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	if result.Output != "turn 5" {
		fmt.Fprintf(os.Stderr, "unexpected third turn: %q\n", result.Output)
		os.Exit(1)
	}

	fmt.Printf("restored messages: %d\n", len(loaded.Messages))
	fmt.Printf("output: %s\n", result.Output)
}
