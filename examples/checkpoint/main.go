package main

import (
	"context"
	"errors"
	"fmt"
	"log"
	"sort"
	"sync"
	"time"

	"github.com/axisvela/praxo-core/v2/pkg/agent"
	"github.com/axisvela/praxo-core/v2/pkg/checkpoint"
	"github.com/axisvela/praxo-core/v2/pkg/model"
)

func main() {
	ctx := context.Background()
	store := newMemoryStore()

	session := agent.Session{
		ID:          "demo",
		TenantID:    "acme",
		WorkspaceID: "default",
		Messages: []model.Message{
			{Role: model.RoleUser, Content: "My order is 42."},
			{Role: model.RoleAssistant, Content: "I will remember that."},
		},
	}

	if err := store.Save(ctx, &checkpoint.Checkpoint{
		ID:          "cp-1",
		SessionID:   session.ID,
		RunID:       "run-1",
		Version:     1,
		Status:      "completed",
		TenantID:    session.TenantID,
		WorkspaceID: session.WorkspaceID,
		Messages:    toCheckpointMessages(session.Messages),
		CreatedAt:   time.Now().UTC(),
	}); err != nil {
		log.Fatal(err)
	}

	loaded, err := store.Load(ctx, session.ID)
	if err != nil {
		log.Fatal(err)
	}
	if loaded == nil {
		log.Fatal("checkpoint not found")
	}
	resumed := session
	resumed.Messages = toModelMessages(loaded.Messages)

	scripted := &captureModel{reply: "Your order is 42."}
	ag, err := agent.New(agent.Options{Model: scripted, MaxSteps: 2})
	if err != nil {
		log.Fatal(err)
	}
	result, err := ag.Run(ctx, resumed, "What is my order number?")
	if err != nil {
		log.Fatal(err)
	}
	fmt.Println("restored messages:", len(resumed.Messages))
	fmt.Println("output:", result.Output)
}

type captureModel struct {
	reply string
	seen  []model.Message
	calls int
}

func (m *captureModel) Generate(_ context.Context, req model.Request) (model.Response, error) {
	m.seen = append([]model.Message(nil), req.Messages...)
	m.calls++
	return model.Response{Message: model.Message{Role: model.RoleAssistant, Content: m.reply}}, nil
}

type memoryStore struct {
	mu          sync.Mutex
	checkpoints []checkpoint.Checkpoint
}

func newMemoryStore() *memoryStore { return &memoryStore{} }

func (s *memoryStore) Save(_ context.Context, cp *checkpoint.Checkpoint) error {
	if cp == nil {
		return errors.New("checkpoint is required")
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	if cp.CreatedAt.IsZero() {
		cp.CreatedAt = time.Now().UTC()
	}
	for i := range s.checkpoints {
		if s.checkpoints[i].SessionID == cp.SessionID && s.checkpoints[i].RunID == cp.RunID {
			s.checkpoints[i] = *cp
			return nil
		}
	}
	s.checkpoints = append(s.checkpoints, *cp)
	return nil
}

func (s *memoryStore) Load(_ context.Context, sessionID string) (*checkpoint.Checkpoint, error) {
	return s.latest(func(cp checkpoint.Checkpoint) bool { return cp.SessionID == sessionID })
}

func (s *memoryStore) LoadScoped(_ context.Context, tenantID, sessionID string) (*checkpoint.Checkpoint, error) {
	return s.latest(func(cp checkpoint.Checkpoint) bool {
		return cp.SessionID == sessionID && (tenantID == "" || cp.TenantID == tenantID)
	})
}

func (s *memoryStore) LoadRun(_ context.Context, runID string) (*checkpoint.Checkpoint, error) {
	return s.latest(func(cp checkpoint.Checkpoint) bool { return cp.RunID == runID })
}

func (s *memoryStore) LoadRunScoped(_ context.Context, tenantID, runID string) (*checkpoint.Checkpoint, error) {
	return s.latest(func(cp checkpoint.Checkpoint) bool {
		return cp.RunID == runID && (tenantID == "" || cp.TenantID == tenantID)
	})
}

func (s *memoryStore) List(_ context.Context, sessionID string) ([]checkpoint.Checkpoint, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	out := make([]checkpoint.Checkpoint, 0)
	for _, cp := range s.checkpoints {
		if cp.SessionID == sessionID {
			out = append(out, cp)
		}
	}
	sort.Slice(out, func(i, j int) bool { return out[i].CreatedAt.After(out[j].CreatedAt) })
	return out, nil
}

func (s *memoryStore) Delete(_ context.Context, checkpointID string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	for i := range s.checkpoints {
		if s.checkpoints[i].ID == checkpointID {
			s.checkpoints = append(s.checkpoints[:i], s.checkpoints[i+1:]...)
			return nil
		}
	}
	return nil
}

func (s *memoryStore) latest(match func(checkpoint.Checkpoint) bool) (*checkpoint.Checkpoint, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	var found *checkpoint.Checkpoint
	for i := range s.checkpoints {
		cp := s.checkpoints[i]
		if !match(cp) {
			continue
		}
		if found == nil || cp.CreatedAt.After(found.CreatedAt) {
			copy := cp
			found = &copy
		}
	}
	return found, nil
}

func toCheckpointMessages(messages []model.Message) []checkpoint.Message {
	out := make([]checkpoint.Message, 0, len(messages))
	for _, message := range messages {
		out = append(out, checkpoint.Message{
			Role:          message.Role,
			Content:       message.Content,
			ContentBlocks: message.ContentBlocks,
		})
	}
	return out
}

func toModelMessages(messages []checkpoint.Message) []model.Message {
	out := make([]model.Message, 0, len(messages))
	for _, message := range messages {
		out = append(out, model.Message{
			Role:    message.Role,
			Content: message.Content,
		})
	}
	return out
}
