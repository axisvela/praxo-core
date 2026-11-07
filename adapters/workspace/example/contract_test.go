package example

import (
	"context"
	"errors"
	"testing"

	"github.com/axisvela/praxo-core/adapters/workspace/conformance"
	"github.com/axisvela/praxo-core/adapters/workspace/contract"
	"github.com/axisvela/praxo-core/adapters/workspace/fake"
)

func TestConformanceAndOptionalCapabilities(t *testing.T) {
	ctx := context.Background()
	provider := fake.NewProvider()
	if err := conformance.CheckProvider(ctx, provider, conformance.Case{
		Command:            []string{"echo", "ok"},
		WantStdoutContains: "echo ok",
		Path:               "nested/file.txt",
		Content:            []byte("conformance"),
	}); err != nil {
		t.Fatal(err)
	}

	session, err := provider.Create(ctx, contract.Spec{Image: "fake", WorkDir: "/workspace"})
	if err != nil {
		t.Fatal(err)
	}
	attached, err := provider.Attach(ctx, session.ID())
	if err != nil {
		t.Fatal(err)
	}
	if attached.ID() != session.ID() {
		t.Fatalf("attached id = %q, want %q", attached.ID(), session.ID())
	}

	pauser, ok := session.(contract.Pauser)
	if !ok {
		t.Fatal("fake session should expose the optional Pauser capability")
	}
	if err := pauser.Pause(ctx); err != nil {
		t.Fatal(err)
	}
	if err := pauser.Resume(ctx); err != nil {
		t.Fatal(err)
	}
	if _, ok := session.(contract.Snapshotter); ok {
		t.Fatal("fake session unexpectedly exposes Snapshotter")
	}

	if err := session.Upload(ctx, "a.txt", []byte("data")); err != nil {
		t.Fatal(err)
	}
	data, err := session.Download(ctx, "a.txt")
	if err != nil {
		t.Fatal(err)
	}
	if string(data) != "data" {
		t.Fatalf("download = %q", data)
	}

	if err := session.Close(ctx); err != nil {
		t.Fatal(err)
	}
	if _, err := session.Read(ctx, "a.txt"); !errors.Is(err, contract.ErrClosed) {
		t.Fatalf("read after close = %v, want ErrClosed", err)
	}
	if _, err := provider.Attach(ctx, session.ID()); !errors.Is(err, contract.ErrNotFound) {
		t.Fatalf("attach after close = %v, want ErrNotFound", err)
	}
	if _, err := provider.Attach(ctx, "missing"); !errors.Is(err, contract.ErrNotFound) {
		t.Fatalf("attach missing = %v, want ErrNotFound", err)
	}
}
