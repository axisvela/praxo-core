package memory

import (
	"context"
	"sync"
	"testing"
	"time"
)

func TestMemoryStoreAndAssembler(t *testing.T) {
	ctx := context.Background()
	store := NewMemoryStore()
	_ = store.Put(ctx, "s1", Record{ID: "m1", Frame: FrameDecision, Content: "use durable scheduler"})
	_ = store.Put(ctx, "s1", Record{ID: "m2", Frame: FrameConstraint, Content: "no provider credentials"})
	_ = store.Put(ctx, "s2", Record{ID: "m3", Frame: FrameEvent, Content: "other session"})

	assembler := ContextAssembler{Store: store, Limit: 5}
	records, err := assembler.Assemble(ctx, "s1", "scheduler")
	if err != nil {
		t.Fatal(err)
	}
	if len(records) != 1 || records[0].ID != "m1" {
		t.Fatalf("records = %+v", records)
	}

	all, _ := assembler.Assemble(ctx, "s1", "")
	if len(all) != 2 {
		t.Fatalf("all = %+v", all)
	}
}

func TestMemoryStoreGeneratedIDsAreUnique(t *testing.T) {
	ctx := context.Background()
	store := NewMemoryStore()
	const count = 100
	var wg sync.WaitGroup
	for i := 0; i < count; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			_ = store.Put(ctx, "s1", Record{Frame: FrameEvent, Content: "event"})
		}()
	}
	wg.Wait()
	records, err := store.Search(ctx, "s1", "", 0)
	if err != nil {
		t.Fatal(err)
	}
	if len(records) != count {
		t.Fatalf("records = %d, want %d", len(records), count)
	}
	seen := make(map[string]struct{}, count)
	for _, record := range records {
		if record.ID == "" {
			t.Fatal("empty generated ID")
		}
		if _, ok := seen[record.ID]; ok {
			t.Fatalf("duplicate ID %q", record.ID)
		}
		seen[record.ID] = struct{}{}
	}
}

func TestMemoryStoreSearchLimitAndCase(t *testing.T) {
	ctx := context.Background()
	store := NewMemoryStore()
	base := time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)
	_ = store.Put(ctx, "s1", Record{ID: "old", Frame: FrameDecision, Content: "Use Durable Scheduler", CreatedAt: base})
	_ = store.Put(ctx, "s1", Record{ID: "new", Frame: FrameDecision, Content: "durable scheduler v2", CreatedAt: base.Add(time.Hour)})
	records, err := store.Search(ctx, "s1", "durable SCHEDULER", 1)
	if err != nil {
		t.Fatal(err)
	}
	if len(records) != 1 || records[0].ID != "new" {
		t.Fatalf("records = %+v", records)
	}
}

func TestMemoryStoreZeroValue(t *testing.T) {
	var store MemoryStore
	if err := store.Put(context.Background(), "s1", Record{ID: "m1", Content: "ok"}); err != nil {
		t.Fatal(err)
	}
	records, err := store.Search(context.Background(), "s1", "ok", 1)
	if err != nil || len(records) != 1 {
		t.Fatalf("records=%+v err=%v", records, err)
	}
}
