package memory

import (
	"context"
	"testing"
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
