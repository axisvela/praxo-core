package consumer_test

import (
	"testing"

	"github.com/axisvela/praxo-core/v2/pkg/formatter"
)

func TestPublishedFormatterBoundaries(t *testing.T) {
	if out, err := formatter.Format("file.unknown"); err != nil || out != "" {
		t.Fatalf("Format = %q, %v", out, err)
	}
	if out, err := (&formatter.Formatter{}).Run("file.go"); err == nil || out != "" {
		t.Fatalf("empty Run = %q, %v", out, err)
	}
	listed := formatter.List()
	listed[0].Name = "changed"
	if len(listed[0].Extensions) > 0 {
		listed[0].Extensions[0] = ".changed"
	}
	fresh := formatter.List()
	if fresh[0].Name == "changed" {
		t.Fatal("formatter registry was mutable through List")
	}
	if len(fresh[0].Extensions) > 0 && fresh[0].Extensions[0] == ".changed" {
		t.Fatal("formatter extensions were mutable through List")
	}
}
