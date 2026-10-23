package main

import (
	"context"
	"testing"
	"time"

	"github.com/axisvela/praxo-core/v2/pkg/agent"
	"github.com/axisvela/praxo-core/v2/pkg/checkpoint"
	"github.com/axisvela/praxo-core/v2/pkg/model"
)

func TestMemoryStore(t *testing.T) {
	ctx := context.Background()
	store := newMemoryStore()
	t1 := time.Date(2026, 10, 23, 1, 0, 0, 0, time.UTC)
	t2 := t1.Add(time.Minute)
	t3 := t2.Add(time.Minute)

	if err := store.Save(ctx, &checkpoint.Checkpoint{
		ID: "cp-1", SessionID: "session-1", RunID: "run-1", TenantID: "acme", CreatedAt: t1,
	}); err != nil {
		t.Fatal(err)
	}
	if err := store.Save(ctx, &checkpoint.Checkpoint{
		ID: "cp-2", SessionID: "session-1", RunID: "run-2", TenantID: "acme", CreatedAt: t2,
	}); err != nil {
		t.Fatal(err)
	}
	if err := store.Save(ctx, &checkpoint.Checkpoint{
		ID: "cp-3", SessionID: "session-1", RunID: "run-1", TenantID: "acme", CreatedAt: t3,
	}); err != nil {
		t.Fatal(err)
	}

	loaded, err := store.Load(ctx, "session-1")
	if err != nil {
		t.Fatal(err)
	}
	if loaded == nil || loaded.ID != "cp-3" {
		t.Fatalf("loaded = %#v", loaded)
	}
	scoped, err := store.LoadScoped(ctx, "other", "session-1")
	if err != nil {
		t.Fatal(err)
	}
	if scoped != nil {
		t.Fatalf("scoped = %#v", scoped)
	}
	run, err := store.LoadRun(ctx, "run-1")
	if err != nil {
		t.Fatal(err)
	}
	if run == nil || run.ID != "cp-3" {
		t.Fatalf("run = %#v", run)
	}
	list, err := store.List(ctx, "session-1")
	if err != nil {
		t.Fatal(err)
	}
	if len(list) != 2 || list[0].ID != "cp-3" || list[1].ID != "cp-2" {
		t.Fatalf("list = %#v", list)
	}
	if err := store.Delete(ctx, "cp-3"); err != nil {
		t.Fatal(err)
	}
	run, err = store.LoadRun(ctx, "run-1")
	if err != nil {
		t.Fatal(err)
	}
	if run != nil {
		t.Fatalf("run after delete = %#v", run)
	}
}

func TestResumeFromCheckpoint(t *testing.T) {
	ctx := context.Background()
	store := newMemoryStore()
	prior := []model.Message{
		{Role: model.RoleUser, Content: "My order is 42."},
		{Role: model.RoleAssistant, Content: "I will remember that."},
	}
	if err := store.Save(ctx, &checkpoint.Checkpoint{
		ID: "cp-1", SessionID: "session-1", RunID: "run-1", Status: "completed",
		Messages: toCheckpointMessages(prior), CreatedAt: time.Now().UTC(),
	}); err != nil {
		t.Fatal(err)
	}
	loaded, err := store.Load(ctx, "session-1")
	if err != nil {
		t.Fatal(err)
	}
	session := agent.Session{ID: "session-1", Messages: toModelMessages(loaded.Messages)}
	scripted := &captureModel{reply: "Your order is 42."}
	instance, err := agent.New(agent.Options{Model: scripted, MaxSteps: 2})
	if err != nil {
		t.Fatal(err)
	}
	result, err := instance.Run(ctx, session, "What is my order number?")
	if err != nil {
		t.Fatal(err)
	}
	if result.Output != "Your order is 42." {
		t.Fatalf("output = %q", result.Output)
	}
	if len(scripted.seen) < 3 || scripted.seen[0].Content != "My order is 42." {
		t.Fatalf("model messages = %#v", scripted.seen)
	}
}
