package checkpoint_store_recipe

import (
	"context"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/axisvela/praxo-core/v2/pkg/checkpoint"
)

func newStore(t *testing.T) *FileStore {
	t.Helper()
	store, err := OpenFileStore(t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { store.Close() })
	return store
}

func checkpointAt(id, session, run string, at time.Time) *checkpoint.Checkpoint {
	return &checkpoint.Checkpoint{
		ID:        id,
		SessionID: session,
		RunID:     run,
		Status:    "completed",
		Messages: []checkpoint.Message{
			{Role: "user", Content: "question"},
			{Role: "assistant", Content: "answer"},
		},
		EffectCursor: &checkpoint.EffectCursor{RunID: run, LastEffectID: "effect-" + run},
		CreatedAt:    at,
	}
}

func TestSaveLoadLatestAndList(t *testing.T) {
	store := newStore(t)
	ctx := context.Background()
	base := time.Date(2026, 11, 7, 12, 0, 0, 0, time.UTC)
	first := checkpointAt("cp-1", "session", "run-1", base)
	second := checkpointAt("cp-2", "session", "run-2", base.Add(time.Minute))
	if err := store.Save(ctx, first); err != nil {
		t.Fatal(err)
	}
	if err := store.Save(ctx, second); err != nil {
		t.Fatal(err)
	}

	latest, err := store.Load(ctx, "session")
	if err != nil {
		t.Fatal(err)
	}
	if latest == nil || latest.ID != "cp-2" {
		t.Fatalf("latest = %#v", latest)
	}
	run, err := store.LoadRun(ctx, "run-1")
	if err != nil {
		t.Fatal(err)
	}
	if run == nil || run.ID != "cp-1" || run.EffectCursor == nil || run.EffectCursor.LastEffectID != "effect-run-1" {
		t.Fatalf("run = %#v", run)
	}
	items, err := store.List(ctx, "session")
	if err != nil {
		t.Fatal(err)
	}
	if len(items) != 2 || items[0].ID != "cp-2" || items[1].ID != "cp-1" {
		t.Fatalf("list = %#v", items)
	}
}

func TestSaveReplacesSameRun(t *testing.T) {
	store := newStore(t)
	ctx := context.Background()
	base := time.Date(2026, 11, 7, 12, 0, 0, 0, time.UTC)
	if err := store.Save(ctx, checkpointAt("cp-old", "session", "run", base)); err != nil {
		t.Fatal(err)
	}
	if err := store.Save(ctx, checkpointAt("cp-new", "session", "run", base.Add(time.Minute))); err != nil {
		t.Fatal(err)
	}
	run, err := store.LoadRun(ctx, "run")
	if err != nil {
		t.Fatal(err)
	}
	if run == nil || run.ID != "cp-new" {
		t.Fatalf("run = %#v", run)
	}
	items, err := store.List(ctx, "session")
	if err != nil {
		t.Fatal(err)
	}
	if len(items) != 1 {
		t.Fatalf("list length = %d, want 1", len(items))
	}
}

func TestSurvivesReopen(t *testing.T) {
	directory := t.TempDir()
	store, err := OpenFileStore(directory)
	if err != nil {
		t.Fatal(err)
	}
	base := time.Date(2026, 11, 7, 12, 0, 0, 0, time.UTC)
	if err := store.Save(context.Background(), checkpointAt("cp-1", "session", "run", base)); err != nil {
		t.Fatal(err)
	}
	if err := store.Close(); err != nil {
		t.Fatal(err)
	}

	reopened, err := OpenFileStore(directory)
	if err != nil {
		t.Fatal(err)
	}
	defer reopened.Close()
	loaded, err := reopened.Load(context.Background(), "session")
	if err != nil {
		t.Fatal(err)
	}
	if loaded == nil || loaded.ID != "cp-1" || len(loaded.Messages) != 2 {
		t.Fatalf("loaded = %#v", loaded)
	}
}

func TestIgnoresPartialTempFile(t *testing.T) {
	store := newStore(t)
	ctx := context.Background()
	base := time.Date(2026, 11, 7, 12, 0, 0, 0, time.UTC)
	if err := store.Save(ctx, checkpointAt("cp-1", "session", "run", base)); err != nil {
		t.Fatal(err)
	}
	partial := filepath.Join(store.root.Name(), sessionDir("session"), "partial.tmp")
	if err := os.WriteFile(partial, []byte("{not-json"), 0o600); err != nil {
		t.Fatal(err)
	}
	loaded, err := store.Load(ctx, "session")
	if err != nil {
		t.Fatal(err)
	}
	if loaded == nil || loaded.ID != "cp-1" {
		t.Fatalf("loaded = %#v", loaded)
	}
}

func TestTenantScope(t *testing.T) {
	store := newStore(t)
	ctx := context.Background()
	base := time.Date(2026, 11, 7, 12, 0, 0, 0, time.UTC)
	first := checkpointAt("cp-a", "session", "run-a", base)
	first.TenantID = "tenant-a"
	second := checkpointAt("cp-b", "session", "run-b", base.Add(time.Minute))
	second.TenantID = "tenant-b"
	if err := store.Save(ctx, first); err != nil {
		t.Fatal(err)
	}
	if err := store.Save(ctx, second); err != nil {
		t.Fatal(err)
	}

	scoped, err := store.LoadScoped(ctx, "tenant-a", "session")
	if err != nil {
		t.Fatal(err)
	}
	if scoped == nil || scoped.ID != "cp-a" {
		t.Fatalf("scoped = %#v", scoped)
	}
	all, err := store.LoadScoped(ctx, "", "session")
	if err != nil {
		t.Fatal(err)
	}
	if all == nil || all.ID != "cp-b" {
		t.Fatalf("unscoped = %#v", all)
	}
	run, err := store.LoadRunScoped(ctx, "tenant-b", "run-b")
	if err != nil {
		t.Fatal(err)
	}
	if run == nil || run.ID != "cp-b" {
		t.Fatalf("run scoped = %#v", run)
	}
}

func TestDelete(t *testing.T) {
	store := newStore(t)
	ctx := context.Background()
	base := time.Date(2026, 11, 7, 12, 0, 0, 0, time.UTC)
	if err := store.Save(ctx, checkpointAt("cp-1", "session", "run", base)); err != nil {
		t.Fatal(err)
	}
	if err := store.Delete(ctx, "cp-1"); err != nil {
		t.Fatal(err)
	}
	loaded, err := store.Load(ctx, "session")
	if err != nil {
		t.Fatal(err)
	}
	if loaded != nil {
		t.Fatalf("deleted checkpoint loaded: %#v", loaded)
	}
}
