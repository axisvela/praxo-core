package main

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/axisvela/praxo-core/v2/pkg/checkpoint"
)

func TestCommittedEffectIsNotReplayedAfterRestart(t *testing.T) {
	ctx := context.Background()
	store := newMemoryStore()
	ledger := newEffectLedger()
	executions := 0

	apply := func() (string, error) {
		executions++
		return "order-42-refunded", nil
	}
	value, applied, err := ledger.Apply("tool-call-1", apply)
	if err != nil || !applied || value != "order-42-refunded" {
		t.Fatalf("first apply = %q, %v, %v", value, applied, err)
	}
	if err := store.Save(ctx, &checkpoint.Checkpoint{
		ID: "cp-1", SessionID: "session-1", RunID: "run-1", Status: "completed",
		EffectCursor: &checkpoint.EffectCursor{
			RunID: "run-1", LastEffectID: "tool-call-1", LastCreatedAt: time.Now().UnixNano(),
		},
		CreatedAt: time.Now().UTC(),
	}); err != nil {
		t.Fatal(err)
	}

	loaded, err := store.Load(ctx, "session-1")
	if err != nil {
		t.Fatal(err)
	}
	if loaded == nil || loaded.EffectCursor == nil || loaded.EffectCursor.LastEffectID != "tool-call-1" {
		t.Fatalf("cursor = %#v", loaded)
	}

	value, applied, err = ledger.Apply("tool-call-1", apply)
	if err != nil {
		t.Fatal(err)
	}
	if applied {
		t.Fatal("replayed a committed effect")
	}
	if value != "order-42-refunded" || executions != 1 || ledger.Count() != 1 {
		t.Fatalf("value=%q executions=%d count=%d", value, executions, ledger.Count())
	}
}

func TestEffectFailureIsNotRecorded(t *testing.T) {
	ledger := newEffectLedger()
	boom := errors.New("commit failed")
	if _, applied, err := ledger.Apply("tool-call-2", func() (string, error) {
		return "", boom
	}); !errors.Is(err, boom) || applied {
		t.Fatalf("applied=%v err=%v", applied, err)
	}
	if ledger.Count() != 0 {
		t.Fatalf("failed effect was recorded")
	}
	if _, applied, err := ledger.Apply("tool-call-2", func() (string, error) {
		return "recovered", nil
	}); err != nil || !applied {
		t.Fatalf("retry applied=%v err=%v", applied, err)
	}
}

func TestEffectKeyIsRequired(t *testing.T) {
	if _, _, err := newEffectLedger().Apply("", func() (string, error) { return "", nil }); !errors.Is(err, errEffectKeyRequired) {
		t.Fatalf("err = %v", err)
	}
}
