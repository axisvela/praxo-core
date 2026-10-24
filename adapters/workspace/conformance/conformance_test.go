package conformance_test

import (
	"context"
	"testing"

	"github.com/axisvela/praxo-core/adapters/workspace/conformance"
	"github.com/axisvela/praxo-core/adapters/workspace/fake"
)

func TestCheckFakeProvider(t *testing.T) {
	provider := fake.NewProvider()
	err := conformance.CheckProvider(context.Background(), provider, conformance.Case{
		Command:            []string{"echo", "ok"},
		WantStdoutContains: "echo ok",
		Path:               "nested/file.txt",
		Content:            []byte("conformance"),
	})
	if err != nil {
		t.Fatal(err)
	}
}
