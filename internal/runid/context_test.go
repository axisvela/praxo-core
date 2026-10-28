package runid

import (
	"context"
	"testing"
)

func TestRunIDContextIsolation(t *testing.T) {
	parent := context.Background()
	a := With(parent, "a")
	b := With(parent, "b")
	if From(parent) != "" || From(a) != "a" || From(b) != "b" || From(With(a, "c")) != "c" || From(a) != "a" {
		t.Fatal("run IDs were not isolated")
	}
}
