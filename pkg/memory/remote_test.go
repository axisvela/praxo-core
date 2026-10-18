package memory

import (
	"context"
	"testing"
)

type fakeBackend struct {
	record Record
}

func (f *fakeBackend) Commit(_ context.Context, _ string, record Record) error {
	f.record = record
	return nil
}
func (f *fakeBackend) Search(_ context.Context, _, _ string, _ int) ([]Record, error) {
	return []Record{f.record}, nil
}

func TestRemoteStore(t *testing.T) {
	backend := &fakeBackend{}
	store := RemoteStore{Backend: backend}
	in := Record{ID: "m1", Frame: FrameDecision, Content: "decision"}
	if err := store.Put(context.Background(), "s1", in); err != nil {
		t.Fatal(err)
	}
	out, err := store.Search(context.Background(), "s1", "", 1)
	if err != nil || len(out) != 1 || out[0].ID != "m1" {
		t.Fatalf("out=%+v err=%v", out, err)
	}
}
